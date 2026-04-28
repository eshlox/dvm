#!/usr/bin/env bash
# shellcheck shell=bash

dvm_agent_usage() {
	cat <<'HELP'
usage:
  dvm agent setup <name>
  dvm agent install <name> claude|codex|opencode|mistral|all
  dvm agent <name> -- <command...>
  dvm agent <name>
HELP
}

dvm_agent_validate_config() {
	case "$DVM_AGENT_USER" in
	'' | *[!a-z_0-9-]* | -*)
		dvm_die "invalid DVM_AGENT_USER: $DVM_AGENT_USER"
		;;
	esac
	case "$DVM_AGENT_HOME" in
	/*) ;;
	*) dvm_die "DVM_AGENT_HOME must be an absolute path: $DVM_AGENT_HOME" ;;
	esac
	case "$DVM_AGENT_CLAUDE_CHANNEL" in
	stable | latest) ;;
	*) dvm_die "DVM_AGENT_CLAUDE_CHANNEL must be stable or latest" ;;
	esac
}

dvm_agent_setup_remote() {
	cat <<'REMOTE'
set -euo pipefail
agent_user="$1"
agent_home="$2"
code_dir="$3"
guest_home="$4"
packages="$5"

if [ -n "$packages" ]; then
	for package in $packages; do
		case "$package" in
		-* | *[!A-Za-z0-9._+:@-]*)
			echo "invalid package token: $package" >&2
			exit 1
			;;
		esac
	done
	command -v dnf5 >/dev/null 2>&1 || {
		echo "dnf5 is required in the guest image" >&2
		exit 1
	}
	# shellcheck disable=SC2086
	sudo dnf5 install -y $packages
fi

if ! id -u "$agent_user" >/dev/null 2>&1; then
	sudo useradd -m -d "$agent_home" -s /bin/bash "$agent_user"
fi

sudo mkdir -p "$agent_home" "$code_dir"
sudo chown "$agent_user:$agent_user" "$agent_home"
sudo chmod 0700 "$agent_home"

if [ -d "$guest_home" ] && [ "$guest_home" != "$agent_home" ]; then
	sudo setfacl -m "u:$agent_user:--x" "$guest_home"
fi
sudo setfacl -m "u:$agent_user:rwx" "$code_dir"
sudo setfacl -R -m "u:$agent_user:rwX" "$code_dir"
sudo find "$code_dir" -type d -exec setfacl -d -m "u:$agent_user:rwx" {} +

add_safe_directory() {
	safe_dir="$1"
	if ! sudo -H -u "$agent_user" env HOME="$agent_home" \
		git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$safe_dir"; then
		sudo -H -u "$agent_user" env HOME="$agent_home" \
			git config --global --add safe.directory "$safe_dir" || true
	fi
}

if command -v git >/dev/null 2>&1; then
	add_safe_directory "$code_dir"
	add_safe_directory "$code_dir/*"
fi

printf 'agent user: %s\n' "$agent_user"
printf 'agent home: %s\n' "$agent_home"
printf 'code dir: %s\n' "$code_dir"
REMOTE
}

dvm_agent_run_remote() {
	cat <<'REMOTE'
set -euo pipefail
agent_user="$1"
agent_home="$2"
code_dir="$3"
guest_home="$4"
workdir="$5"
shift 5

if [ "$#" -eq 0 ]; then
	set -- bash -l
fi

command -v bwrap >/dev/null 2>&1 || {
	echo "bubblewrap is required; run: dvm agent setup <name>" >&2
	exit 1
}
id -u "$agent_user" >/dev/null 2>&1 || {
	echo "agent user is missing; run: dvm agent setup <name>" >&2
	exit 1
}
[ -d "$code_dir" ] || {
	echo "code directory not found: $code_dir" >&2
	exit 1
}
[ -d "$agent_home" ] || {
	echo "agent home not found: $agent_home" >&2
	exit 1
}

bwrap_args=(
	--die-with-parent
	--unshare-pid
	--unshare-ipc
	--unshare-uts
	--unshare-cgroup
	--proc /proc
	--dev /dev
	--ro-bind / /
	--tmpfs /tmp
	--dir /tmp/dvm-agent-code
	--bind "$code_dir" /tmp/dvm-agent-code
	--tmpfs /var/tmp
	--bind "$agent_home" "$agent_home"
	--setenv HOME "$agent_home"
	--setenv USER "$agent_user"
	--setenv LOGNAME "$agent_user"
	--setenv DVM_AGENT "1"
	--setenv DVM_CODE_DIR "$code_dir"
)

if [ "$guest_home" != "$agent_home" ] && [ -d "$guest_home" ]; then
	bwrap_args+=(--tmpfs "$guest_home")
fi
case "$code_dir" in
"$guest_home"/*)
	bwrap_args+=(--dir "$guest_home" --dir "$code_dir")
	;;
esac

bwrap_args+=(--bind /tmp/dvm-agent-code "$code_dir")
if [ -d "$workdir" ]; then
	bwrap_args+=(--chdir "$workdir")
else
	bwrap_args+=(--chdir "$code_dir")
fi

sudo -H -u "$agent_user" env \
	HOME="$agent_home" \
	USER="$agent_user" \
	LOGNAME="$agent_user" \
	PATH="$agent_home/.local/bin:$PATH" \
	bwrap "${bwrap_args[@]}" -- "$@"
REMOTE
}

dvm_agent_install_remote() {
	cat <<'REMOTE'
set -euo pipefail
agent_user="$1"
agent_home="$2"
channel="$3"
tool="$4"

install_packages() {
	local packages pkg
	packages="$1"
	command -v dnf5 >/dev/null 2>&1 || {
		echo "dnf5 is required in the guest image" >&2
		exit 1
	}
	for pkg in $packages; do
		case "$pkg" in
		-* | *[!A-Za-z0-9._+:@-]*)
			echo "invalid package token: $pkg" >&2
			exit 1
			;;
		esac
	done
	# shellcheck disable=SC2086
	sudo dnf5 install -y $packages
}

install_claude() {
	local repo_tmp
	repo_tmp="$(mktemp)"
	trap 'rm -f "$repo_tmp"' EXIT
	cat >"$repo_tmp" <<REPO
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/$channel
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
REPO
	sudo mkdir -p /etc/yum.repos.d
	sudo mv "$repo_tmp" /etc/yum.repos.d/claude-code.repo
	sudo chmod 0644 /etc/yum.repos.d/claude-code.repo
	install_packages "claude-code"
}

install_node_tool() {
	local npm_package
	npm_package="$1"
	install_packages "nodejs npm"
	sudo -H -u "$agent_user" env \
		HOME="$agent_home" \
		USER="$agent_user" \
		LOGNAME="$agent_user" \
		PATH="$agent_home/.local/bin:$PATH" \
		bash -lc 'npm config set prefix "$HOME/.local" && mkdir -p "$HOME/.local/bin" && npm install -g "$1"' \
		dvm-agent-npm "$npm_package"
}

install_codex() {
	install_node_tool "@openai/codex"
}

install_opencode() {
	install_node_tool "opencode-ai"
}

install_mistral() {
	install_packages "uv python3"
	sudo -H -u "$agent_user" env \
		HOME="$agent_home" \
		USER="$agent_user" \
		LOGNAME="$agent_user" \
		PATH="$agent_home/.local/bin:$PATH" \
		bash -lc 'mkdir -p "$HOME/.local/bin" && uv tool install mistral-vibe'
}

case "$tool" in
claude) install_claude ;;
codex) install_codex ;;
opencode) install_opencode ;;
mistral) install_mistral ;;
all)
	install_claude
	install_codex
	install_opencode
	install_mistral
	;;
*) echo "unknown agent tool: $tool" >&2; exit 1 ;;
esac
REMOTE
}

dvm_agent_vm() {
	local name vm
	name="$1"
	dvm_validate_name "$name"
	vm="$(dvm_vm_name "$name")"
	limactl start "$vm" >/dev/null
	printf '%s\n' "$vm"
}

dvm_agent_setup() {
	local name vm remote
	[ "$#" -eq 1 ] || dvm_die "usage: dvm agent setup <name>"
	name="$1"
	dvm_load_config
	dvm_agent_validate_config
	dvm_require limactl
	vm="$(dvm_agent_vm "$name")"
	remote="$(dvm_agent_setup_remote)"

	dvm_log "setting up agent user in $vm"
	limactl shell "$vm" bash -c "$remote" dvm-agent-setup \
		"$DVM_AGENT_USER" \
		"$DVM_AGENT_HOME" \
		"$DVM_CODE_DIR" \
		"$DVM_GUEST_HOME" \
		"$DVM_AGENT_PACKAGES"
}

dvm_agent_install() {
	local name vm tool remote
	[ "$#" -eq 2 ] || dvm_die "usage: dvm agent install <name> claude|codex|opencode|mistral|all"
	name="$1"
	tool="$2"
	dvm_load_config
	dvm_agent_validate_config
	dvm_require limactl
	vm="$(dvm_agent_vm "$name")"
	remote="$(dvm_agent_install_remote)"

	dvm_log "installing agent tool in $vm: $tool"
	dvm_agent_setup "$name" >/dev/null
	limactl shell "$vm" bash -c "$remote" dvm-agent-install \
		"$DVM_AGENT_USER" \
		"$DVM_AGENT_HOME" \
		"$DVM_AGENT_CLAUDE_CHANNEL" \
		"$tool"
}

dvm_agent_run() {
	local name vm remote
	[ "$#" -ge 1 ] || dvm_die "usage: dvm agent <name> -- <command...>"
	name="$1"
	shift
	if [ "${1:-}" = "--" ]; then
		shift
	fi

	dvm_load_config
	dvm_agent_validate_config
	dvm_require limactl
	vm="$(dvm_agent_vm "$name")"
	remote="$(dvm_agent_run_remote)"

	limactl shell "$vm" bash -c "$remote" dvm-agent-run \
		"$DVM_AGENT_USER" \
		"$DVM_AGENT_HOME" \
		"$DVM_CODE_DIR" \
		"$DVM_GUEST_HOME" \
		"$DVM_CODE_DIR" \
		"$@"
}

dvm_agent_cmd() {
	local cmd
	cmd="${1:-help}"
	[ "$#" -eq 0 ] || shift
	case "$cmd" in
	setup) dvm_agent_setup "$@" ;;
	install) dvm_agent_install "$@" ;;
	help | -h | --help) dvm_agent_usage ;;
	*)
		dvm_agent_run "$cmd" "$@"
		;;
	esac
}
