#!/usr/bin/env bash
set -euo pipefail

agent_user="${DVM_AGENT_USER:-dvm-agent}"
sudo dnf5 install -y bubblewrap acl shadow-utils npm
if ! id -u "$agent_user" >/dev/null 2>&1; then
	sudo useradd --create-home --shell /bin/bash "$agent_user"
fi
sudo setfacl -m "u:$agent_user:rwx" "$DVM_CODE_DIR"
cat <<HELP
Agent user is ready.

Run tools through the VM explicitly, for example:
  sudo -H -u $agent_user -- bash -lc 'cd "$DVM_CODE_DIR" && codex'

Keep AI tool credentials in the agent user's home, not in your normal VM user.
HELP
