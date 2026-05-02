#!/usr/bin/env bash
# shellcheck shell=bash

dvm_ai_install_mistral() {
	sudo dnf5 install -y uv
	sudo -H -u "$agent_user" bash -lc 'uv tool install --force mistral-vibe'
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

dvm_ai_install_mistral_tool() {
	dvm_ai_install_mistral
	dvm_ai_wrapper_args=()
	dvm_ai_wrapper_env=()
	if [ "$ai_yolo" = "1" ]; then
		dvm_ai_configure_mistral_yolo
		dvm_ai_wrapper_args=(--agent dvm-yolo)
	fi
	dvm_ai_install_wrapper vibe "$agent_home/.local/bin/vibe"
	dvm_ai_install_wrapper mistral "$agent_home/.local/bin/vibe"
}
