#!/usr/bin/env bash
set -euo pipefail

agent_user="${DVM_AGENT_USER:-dvm-agent}"
agent_home=""
sudo dnf5 install -y bubblewrap acl shadow-utils sudo
if ! id -u "$agent_user" >/dev/null 2>&1; then
	sudo useradd --system --create-home --home-dir "/home/$agent_user" --shell /bin/bash "$agent_user"
fi
agent_home="$(getent passwd "$agent_user" | awk -F: '{ print $6 }')"
[ -n "$agent_home" ] || {
	printf 'agent.sh: could not resolve home for %s\n' "$agent_user" >&2
	exit 1
}
agent_group="$(id -gn "$agent_user")"
sudo install -d -m 700 -o "$agent_user" -g "$agent_group" "$agent_home"
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
