#!/usr/bin/env bash
set -euo pipefail

: "${DVM_CODE_DIR:?DVM_CODE_DIR is required}"
DVM_AI_AGENT_USER="${DVM_AI_AGENT_USER:-dvm-agent}"

dvm_guest_path() {
	case "$1" in
	\~) printf '%s\n' "$HOME" ;;
	\~/*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
	*) printf '%s\n' "$1" ;;
	esac
}

dvm_sq() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

dvm_agent_write_wrapper() {
	local command="$1"
	local target="$2"
	local agent_home code_dir
	code_dir="$(dvm_guest_path "$DVM_CODE_DIR")"
	agent_home="$(getent passwd "$DVM_AI_AGENT_USER" | awk -F: '{print $6}')"
	sudo tee "/usr/local/bin/$command" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
code_dir=$(dvm_sq "$code_dir")
agent_home=$(dvm_sq "$agent_home")
workdir="\${PWD:-$code_dir}"
case "\$workdir" in
	$code_dir|$code_dir/*) ;;
	*) workdir="$code_dir" ;;
esac
exec /usr/local/libexec/dvm-ai-bwrap $(dvm_sq "$DVM_AI_AGENT_USER") "\$code_dir" "\$agent_home" $(dvm_sq "$target") "\$workdir" -- "\$@"
EOF
	sudo chmod 0755 "/usr/local/bin/$command"
}

code_dir="$(dvm_guest_path "$DVM_CODE_DIR")"
sudo dnf5 install -y acl bubblewrap shadow-utils sudo

if ! id -u "$DVM_AI_AGENT_USER" >/dev/null 2>&1; then
	sudo useradd --system --create-home --user-group --shell /bin/bash "$DVM_AI_AGENT_USER"
fi

agent_home="$(getent passwd "$DVM_AI_AGENT_USER" | awk -F: '{print $6}')"
mkdir -p "$code_dir"
sudo install -d -m 0700 -o "$DVM_AI_AGENT_USER" -g "$DVM_AI_AGENT_USER" "$agent_home/scratch"
sudo install -d -m 0755 /usr/local/libexec
sudo tee /usr/local/libexec/dvm-ai-bwrap >/dev/null <<'DVM_AI_BWRAP'
#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'dvm-ai-bwrap: %s\n' "$*" >&2
	exit 1
}

[ "$#" -ge 5 ] || die "usage: dvm-ai-bwrap <agent-user> <code-dir> <agent-home> <target> <workdir> -- <args...>"

agent_user="$1"
code_dir="$2"
agent_home="$3"
target="$4"
workdir="$5"
shift 5
[ "${1:-}" != "--" ] || shift

case "$agent_user" in
'' | *[!A-Za-z0-9._-]*) die "invalid agent user: $agent_user" ;;
esac
case "$code_dir" in
/*) ;;
*) die "code dir must be absolute: $code_dir" ;;
esac
case "$agent_home" in
/*) ;;
*) die "agent home must be absolute: $agent_home" ;;
esac
case "$target" in
/*) ;;
*) die "target must be absolute: $target" ;;
esac

[ -d "$code_dir" ] || die "missing code dir: $code_dir"
[ -d "$agent_home" ] || die "missing agent home: $agent_home"
[ -x /usr/bin/bwrap ] || die "missing /usr/bin/bwrap"

case "$workdir" in
	"$code_dir" | "$code_dir"/*) ;;
	*) workdir="$code_dir" ;;
esac

rel="${workdir#"$code_dir"}"
rel="${rel#/}"
sandbox_workdir="/workspace"
[ -z "$rel" ] || sandbox_workdir="/workspace/$rel"

term="${TERM:-xterm-256color}"
lang="${LANG:-C.UTF-8}"
path="/home/$agent_user/.local/bin:/usr/local/bin:/usr/bin:/bin"

exec sudo -H -u "$agent_user" env -i \
	DVM_AI_AGENT_HOME="$agent_home" \
	DVM_AI_CODE_DIR="$code_dir" \
	DVM_AI_LANG="$lang" \
	DVM_AI_PATH="$path" \
	DVM_AI_TARGET="$target" \
	DVM_AI_TERM="$term" \
	DVM_AI_USER="$agent_user" \
	DVM_AI_WORKDIR="$sandbox_workdir" \
	/bin/bash -c '
set -euo pipefail
exec /usr/bin/bwrap \
	--die-with-parent \
	--unshare-pid \
	--unshare-ipc \
	--unshare-uts \
	--unshare-cgroup-try \
	--ro-bind /usr /usr \
	--symlink usr/bin /bin \
	--symlink usr/sbin /sbin \
	--symlink usr/lib /lib \
	--symlink usr/lib64 /lib64 \
	--ro-bind /etc /etc \
	--ro-bind-try /opt /opt \
	--proc /proc \
	--dev /dev \
	--tmpfs /tmp \
	--dir /run \
	--dir /run/systemd \
	--ro-bind-try /run/systemd/resolve /run/systemd/resolve \
	--dir /run/NetworkManager \
	--ro-bind-try /run/NetworkManager /run/NetworkManager \
	--dir /var \
	--symlink ../tmp /var/tmp \
	--dir /home \
	--dir /workspace \
	--bind "$DVM_AI_AGENT_HOME" "$DVM_AI_AGENT_HOME" \
	--bind "$DVM_AI_CODE_DIR" /workspace \
	--setenv HOME "$DVM_AI_AGENT_HOME" \
	--setenv USER "$DVM_AI_USER" \
	--setenv LOGNAME "$DVM_AI_USER" \
	--setenv SHELL /bin/bash \
	--setenv LANG "$DVM_AI_LANG" \
	--setenv TERM "$DVM_AI_TERM" \
	--setenv PATH "$DVM_AI_PATH" \
	--setenv DVM_CODE_DIR /workspace \
	--setenv DVM_AI_WORKDIR "$DVM_AI_WORKDIR" \
	--chdir "$DVM_AI_WORKDIR" \
	-- "$DVM_AI_TARGET" "$@"
' dvm-ai-bwrap "$@"
DVM_AI_BWRAP
sudo chmod 0755 /usr/local/libexec/dvm-ai-bwrap

if command -v git >/dev/null 2>&1; then
	sudo -H -u "$DVM_AI_AGENT_USER" git config --global --add safe.directory /workspace || true
	sudo -H -u "$DVM_AI_AGENT_USER" git config --global --add safe.directory "$code_dir" || true
fi

sudo setfacl -m "u:$DVM_AI_AGENT_USER:--x" "$HOME" || true
if [ -d "$(dirname "$code_dir")" ]; then
	sudo setfacl -m "u:$DVM_AI_AGENT_USER:--x" "$(dirname "$code_dir")" || true
fi
sudo setfacl -R -m "u:$DVM_AI_AGENT_USER:rwx" "$code_dir" || true
sudo setfacl -d -m "u:$DVM_AI_AGENT_USER:rwx" "$code_dir" || true

for path in \
	"$HOME/.ssh" \
	"$HOME/.gnupg" \
	"$HOME/.npmrc" \
	"$HOME/.gitconfig" \
	"$HOME/.bash_history" \
	"$HOME/.zsh_history" \
	"$HOME/.config/git" \
	"$HOME/.config/gh" \
	"$HOME/.config/op"; do
	if [ -e "$path" ]; then
		sudo setfacl -R -m "u:$DVM_AI_AGENT_USER:---" "$path" || true
	fi
done
