#!/usr/bin/env bash
set -euo pipefail

agent_user="${DVM_AGENT_USER:-dvm-agent}"
code_dir="${DVM_CODE_DIR:?DVM_CODE_DIR is required}"
tools="${DVM_AI_TOOLS-claude codex opencode mistral}"
claude_channel="${DVM_CLAUDE_CHANNEL:-stable}"
ai_yolo="${DVM_AI_YOLO:-1}"
agent_home=""
dvm_ai_wrapper_args=()
dvm_ai_wrapper_env=()

dvm_ai_die() {
	printf 'ai.sh: %s\n' "$*" >&2
	exit 1
}

dvm_ai_quote() {
	printf '%q' "$1"
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

dvm_ai_install_claude() {
	sudo tee /etc/yum.repos.d/claude-code.repo >/dev/null <<EOF
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/$claude_channel
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF
	sudo dnf5 install -y claude-code
}

dvm_ai_ensure_npm() {
	sudo dnf5 install -y npm
	sudo -H -u "$agent_user" bash -lc 'mkdir -p "$HOME/.local"; npm config set prefix "$HOME/.local"'
}

dvm_ai_install_npm_tool() {
	local package
	package="$1"
	sudo -H -u "$agent_user" bash -lc "npm install -g $(dvm_ai_quote "$package")"
}

dvm_ai_install_mistral() {
	sudo dnf5 install -y uv
	sudo -H -u "$agent_user" bash -lc 'uv tool install --force mistral-vibe'
}

dvm_ai_array_literal() {
	local item
	for item in "$@"; do
		printf ' %q' "$item"
	done
}

dvm_ai_configure_mistral_yolo() {
	sudo -H -u "$agent_user" bash -lc 'mkdir -p "$HOME/.vibe/agents"; cat >"$HOME/.vibe/agents/dvm-yolo.toml" <<'"'"'VIBE'"'"'
[tools.bash]
permission = "always"

[tools.read_file]
permission = "always"

[tools.write_file]
permission = "always"

[tools.search_replace]
permission = "always"

[tools.grep]
permission = "always"
VIBE'
}

dvm_ai_install_wrapper() {
	local command_name target wrapper
	command_name="$1"
	target="$2"
	wrapper="/usr/local/bin/$command_name"
	sudo tee "$wrapper" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail

agent_user=$(dvm_ai_quote "$agent_user")
code_dir=$(dvm_ai_quote "$code_dir")
target=$(dvm_ai_quote "$target")
default_args=($(dvm_ai_array_literal "${dvm_ai_wrapper_args[@]}"))
extra_env=($(dvm_ai_array_literal "${dvm_ai_wrapper_env[@]}"))
workdir="\${PWD:-\$code_dir}"

case "\$workdir" in
"\$code_dir" | "\$code_dir"/*) ;;
*) workdir="\$code_dir" ;;
esac

if [ "\$(id -un)" = "\$agent_user" ]; then
	cd "\$workdir"
	exec env "\${extra_env[@]}" "\$target" "\${default_args[@]}" "\$@"
fi

exec sudo -H -u "\$agent_user" \
	env DVM_AI_WORKDIR="\$workdir" TERM="\${TERM:-xterm-256color}" COLORTERM="\${COLORTERM:-}" "\${extra_env[@]}" \
	bash -lc 'cd "\$DVM_AI_WORKDIR"; target="\$1"; shift; exec "\$target" "\$@"' dvm-ai "\$target" "\${default_args[@]}" "\$@"
EOF
	sudo chmod 0755 "$wrapper"
}

dvm_ai_validate
dvm_ai_ensure_agent_user

if dvm_ai_needs_tool claude; then
	dvm_ai_install_claude
	dvm_ai_wrapper_args=()
	dvm_ai_wrapper_env=()
	if [ "$ai_yolo" = "1" ]; then
		dvm_ai_wrapper_args=(--dangerously-skip-permissions)
	fi
	dvm_ai_install_wrapper claude /usr/bin/claude
fi

if dvm_ai_needs_tool codex || dvm_ai_needs_tool opencode; then
	dvm_ai_ensure_npm
fi

if dvm_ai_needs_tool codex; then
	dvm_ai_install_npm_tool '@openai/codex@latest'
	dvm_ai_wrapper_args=()
	dvm_ai_wrapper_env=()
	if [ "$ai_yolo" = "1" ]; then
		dvm_ai_wrapper_args=(--dangerously-bypass-approvals-and-sandbox)
	fi
	dvm_ai_install_wrapper codex "$agent_home/.local/bin/codex"
fi

if dvm_ai_needs_tool opencode; then
	dvm_ai_install_npm_tool 'opencode-ai@latest'
	dvm_ai_wrapper_args=()
	dvm_ai_wrapper_env=()
	if [ "$ai_yolo" = "1" ]; then
		dvm_ai_wrapper_env=('OPENCODE_CONFIG_CONTENT={"permission":"allow"}')
	fi
	dvm_ai_install_wrapper opencode "$agent_home/.local/bin/opencode"
fi

if dvm_ai_needs_tool mistral; then
	dvm_ai_install_mistral
	dvm_ai_wrapper_args=()
	dvm_ai_wrapper_env=()
	if [ "$ai_yolo" = "1" ]; then
		dvm_ai_configure_mistral_yolo
		dvm_ai_wrapper_args=(--agent dvm-yolo)
	fi
	dvm_ai_install_wrapper vibe "$agent_home/.local/bin/vibe"
	dvm_ai_install_wrapper mistral "$agent_home/.local/bin/vibe"
fi

cat <<EOF
AI tools are ready.

Installed tools: ${tools:-none}
Agent user: $agent_user
Code directory: $code_dir
YOLO mode: $ai_yolo

Run inside the VM:
  claude
  codex
  opencode
  vibe

Run from the host:
  dvm $DVM_NAME claude
EOF
