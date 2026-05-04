#!/usr/bin/env bash
set -euo pipefail

: "${DVM_AI_AGENT_USER:=dvm-agent}"
command -v dvm_agent_write_wrapper >/dev/null 2>&1 || {
	printf 'dvm: recipe mistral requires use agent-user before use mistral\n' >&2
	exit 1
}

sudo dnf5 install -y python3 uv
sudo -H -u "$DVM_AI_AGENT_USER" bash -lc 'uv tool install mistral-vibe && uv tool upgrade mistral-vibe && ln -sfn "$HOME/.local/bin/vibe" "$HOME/.local/bin/mistral"'
dvm_agent_write_wrapper vibe "/home/$DVM_AI_AGENT_USER/.local/bin/vibe"
dvm_agent_write_wrapper mistral "/home/$DVM_AI_AGENT_USER/.local/bin/mistral"
