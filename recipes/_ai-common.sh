#!/usr/bin/env bash
# shellcheck shell=bash

dvm_ai_die() {
	dvm_recipe_die "ai.sh: $*"
}

dvm_ai_needs_tool() {
	local wanted
	wanted="$1"
	case " $tools " in
	*" $wanted "*) return 0 ;;
	*) return 1 ;;
	esac
}

dvm_ai_validate() {
	local tool
	for tool in $tools; do
		case "$tool" in
		claude | codex | opencode | mistral) ;;
		*) dvm_ai_die "unknown DVM_AI_TOOLS entry: $tool" ;;
		esac
	done
	case "$claude_channel" in
	stable | latest) ;;
	*) dvm_ai_die "DVM_CLAUDE_CHANNEL must be stable or latest" ;;
	esac
	case "$ai_yolo" in
	0 | 1) ;;
	*) dvm_ai_die "DVM_AI_YOLO must be 0 or 1" ;;
	esac
}

dvm_ai_ensure_agent_user() {
	local agent_group
	sudo dnf5 install -y acl shadow-utils sudo
	if ! id -u "$agent_user" >/dev/null 2>&1; then
		sudo useradd --system --create-home --home-dir "/home/$agent_user" --shell /bin/bash "$agent_user"
	fi
	agent_home="$(getent passwd "$agent_user" | awk -F: '{ print $6 }')"
	[ -n "$agent_home" ] || dvm_ai_die "could not resolve home for $agent_user"
	agent_group="$(id -gn "$agent_user")"
	sudo install -d -m 700 -o "$agent_user" -g "$agent_group" "$agent_home"
	sudo mkdir -p "$code_dir"
	sudo setfacl -m "u:$agent_user:--x" "$DVM_GUEST_HOME" 2>/dev/null || true
	sudo setfacl -m "u:$agent_user:rwx" "$code_dir"
	sudo setfacl -d -m "u:$agent_user:rwx" "$code_dir" 2>/dev/null || true
	sudo setfacl -R -m "u:$agent_user:rwx" "$code_dir" 2>/dev/null || true
}

dvm_ai_ensure_npm() {
	sudo dnf5 install -y npm
	sudo -H -u "$agent_user" bash -lc 'mkdir -p "$HOME/.local"; npm config set prefix "$HOME/.local"'
}

dvm_ai_install_npm_tool() {
	local package
	package="$1"
	sudo -H -u "$agent_user" bash -lc "npm install -g $(dvm_recipe_quote "$package")"
}

dvm_ai_install_runner() {
	sudo install -d -m 0755 /etc/dvm/ai /usr/local/libexec
	sudo tee /usr/local/libexec/dvm-ai-runner >/dev/null <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail

config="${1:?usage: dvm-ai-runner <config> [args...]}"
shift

# shellcheck source=/dev/null
source "$config"
: "${DVM_AI_AGENT_USER:?}"
: "${DVM_AI_CODE_DIR:?}"
: "${DVM_AI_TARGET:?}"

workdir="${PWD:-$DVM_AI_CODE_DIR}"
case "$workdir" in
"$DVM_AI_CODE_DIR" | "$DVM_AI_CODE_DIR"/*) ;;
*) workdir="$DVM_AI_CODE_DIR" ;;
esac

if [ "$(id -un)" = "$DVM_AI_AGENT_USER" ]; then
	cd "$workdir"
	exec env "${DVM_AI_EXTRA_ENV[@]}" "$DVM_AI_TARGET" "${DVM_AI_DEFAULT_ARGS[@]}" "$@"
fi

exec sudo -H -u "$DVM_AI_AGENT_USER" \
	env DVM_AI_WORKDIR="$workdir" TERM="${TERM:-xterm-256color}" COLORTERM="${COLORTERM:-}" "${DVM_AI_EXTRA_ENV[@]}" \
	bash -lc 'cd "$DVM_AI_WORKDIR"; target="$1"; shift; exec "$target" "$@"' dvm-ai "$DVM_AI_TARGET" "${DVM_AI_DEFAULT_ARGS[@]}" "$@"
RUNNER
	sudo chmod 0755 /usr/local/libexec/dvm-ai-runner
}

dvm_ai_install_wrapper() {
	local command_name config target tmp wrapper
	command_name="$1"
	target="$2"
	config="/etc/dvm/ai/$command_name.conf"
	wrapper="/usr/local/bin/$command_name"
	tmp="$(mktemp)"
	{
		printf 'DVM_AI_AGENT_USER=%q\n' "$agent_user"
		printf 'DVM_AI_CODE_DIR=%q\n' "$code_dir"
		printf 'DVM_AI_TARGET=%q\n' "$target"
		printf 'DVM_AI_DEFAULT_ARGS=('
		dvm_recipe_array_literal "${dvm_ai_wrapper_args[@]}"
		printf ' )\n'
		printf 'DVM_AI_EXTRA_ENV=('
		dvm_recipe_array_literal "${dvm_ai_wrapper_env[@]}"
		printf ' )\n'
	} >"$tmp"
	sudo install -m 0644 -o root -g root "$tmp" "$config"
	rm -f "$tmp"
	sudo tee "$wrapper" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec /usr/local/libexec/dvm-ai-runner $(dvm_recipe_quote "$config") "\$@"
EOF
	sudo chmod 0755 "$wrapper"
}
