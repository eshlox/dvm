#!/usr/bin/env bash
set -euo pipefail

: "${DVM_CODE_DIR:?DVM_CODE_DIR is required}"
DVM_AI_AGENT_USER="${DVM_AI_AGENT_USER:-dvm-agent}"

dvm_guest_path() {
	case "$1" in
	"~") printf '%s\n' "$HOME" ;;
	"~/"*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
	*) printf '%s\n' "$1" ;;
	esac
}

dvm_sq() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

dvm_agent_write_wrapper() {
	local command="$1"
	local target="$2"
	local code_dir
	code_dir="$(dvm_guest_path "$DVM_CODE_DIR")"
	sudo tee "/usr/local/bin/$command" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
workdir="\${PWD:-$code_dir}"
case "\$workdir" in
	$code_dir|$code_dir/*) ;;
	*) workdir="$code_dir" ;;
esac
exec sudo -H -u $(dvm_sq "$DVM_AI_AGENT_USER") env DVM_AI_WORKDIR="\$workdir" bash -lc 'cd "\$DVM_AI_WORKDIR"; target="\$1"; shift; exec "\$target" "\$@"' dvm-agent $(dvm_sq "$target") "\$@"
EOF
	sudo chmod 0755 "/usr/local/bin/$command"
}

code_dir="$(dvm_guest_path "$DVM_CODE_DIR")"
sudo dnf5 install -y acl shadow-utils sudo

if ! id -u "$DVM_AI_AGENT_USER" >/dev/null 2>&1; then
	sudo useradd -m -s /bin/bash "$DVM_AI_AGENT_USER"
fi

agent_home="$(getent passwd "$DVM_AI_AGENT_USER" | awk -F: '{print $6}')"
mkdir -p "$code_dir"
sudo install -d -m 0700 -o "$DVM_AI_AGENT_USER" -g "$DVM_AI_AGENT_USER" "$agent_home/scratch"

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
