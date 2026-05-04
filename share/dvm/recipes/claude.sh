#!/usr/bin/env bash
set -euo pipefail

: "${DVM_AI_AGENT_USER:=dvm-agent}"
command -v dvm_agent_write_wrapper >/dev/null 2>&1 || {
	printf 'dvm: recipe claude requires use agent-user before use claude\n' >&2
	exit 1
}

sudo dnf5 install -y dnf5-plugins curl jq
# Verified 2026-05-03 from Anthropic's Claude Code package-manager instructions:
# https://code.claude.com/docs/en/setup
sudo tee /etc/yum.repos.d/claude-code.repo >/dev/null <<'CLAUDE_CODE_REPO'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/latest
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
CLAUDE_CODE_REPO

if rpm -q claude-code >/dev/null 2>&1; then
	sudo dnf5 --refresh upgrade -y claude-code
else
	sudo dnf5 --refresh install -y claude-code
fi

sudo -H -u "$DVM_AI_AGENT_USER" bash -lc '
set -euo pipefail
settings="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$settings")"
tmp="$(mktemp)"
if [ -s "$settings" ]; then
	jq '"'"'(.permissions //= {}) | .permissions.defaultMode = "bypassPermissions" | .permissions.skipDangerousModePermissionPrompt = true'"'"' "$settings" >"$tmp"
else
	jq -n '"'"'{permissions: {defaultMode: "bypassPermissions", skipDangerousModePermissionPrompt: true}}'"'"' >"$tmp"
fi
mv "$tmp" "$settings"
chmod 600 "$settings"
'

dvm_agent_write_wrapper claude /usr/bin/claude
