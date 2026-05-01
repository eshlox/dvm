#!/usr/bin/env bash
set -euo pipefail

agent_user="${DVM_AGENT_USER:-dvm-agent}"
sudo dnf5 install -y bubblewrap acl shadow-utils sudo
if ! id -u "$agent_user" >/dev/null 2>&1; then
	sudo useradd --create-home --shell /bin/bash "$agent_user"
fi
sudo mkdir -p "$DVM_CODE_DIR"
sudo setfacl -m "u:$agent_user:--x" "$DVM_GUEST_HOME" 2>/dev/null || true
sudo setfacl -m "u:$agent_user:rwx" "$DVM_CODE_DIR"
sudo setfacl -d -m "u:$agent_user:rwx" "$DVM_CODE_DIR" 2>/dev/null || true
sudo setfacl -R -m "u:$agent_user:rwx" "$DVM_CODE_DIR" 2>/dev/null || true
cat <<HELP
Agent user is ready.

For AI CLIs, prefer the built-in ai.sh recipe. It installs wrappers such as
claude, codex, opencode, and vibe so each tool runs as $agent_user.

Keep AI tool credentials in the agent user's home, not in your normal VM user.
HELP
