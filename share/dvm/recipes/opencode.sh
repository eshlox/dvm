#!/usr/bin/env bash
set -euo pipefail

: "${DVM_AI_AGENT_USER:=dvm-agent}"
command -v dvm_agent_write_wrapper >/dev/null 2>&1 || {
	printf 'dvm: recipe opencode requires use agent-user before use opencode\n' >&2
	exit 1
}

sudo dnf5 install -y nodejs npm
sudo -H -u "$DVM_AI_AGENT_USER" bash -lc 'npm config set prefix "$HOME/.local" && npm install -g opencode-ai@latest'
dvm_agent_write_wrapper opencode "/home/$DVM_AI_AGENT_USER/.local/bin/opencode"
