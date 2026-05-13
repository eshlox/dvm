# Description: Claude Code CLI
dvm_recipe_require_agent_user claude
dvm_claude_bypass="$(dvm_recipe_bool claude DVM_CLAUDE_BYPASS "${DVM_CLAUDE_BYPASS:-1}")"

dvm_pkg dnf5-plugins curl jq
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

sudo -H -u "$DVM_AI_AGENT_USER" env "DVM_CLAUDE_BYPASS=$dvm_claude_bypass" bash -lc '
set -euo pipefail
settings="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$settings")"
tmp="$(mktemp)"
if [ "$DVM_CLAUDE_BYPASS" = "1" ]; then
	if [ -s "$settings" ]; then
		jq '"'"'(.permissions //= {}) | .permissions.defaultMode = "bypassPermissions" | .permissions.skipDangerousModePermissionPrompt = true'"'"' "$settings" >"$tmp"
	else
		jq -n '"'"'{permissions: {defaultMode: "bypassPermissions", skipDangerousModePermissionPrompt: true}}'"'"' >"$tmp"
	fi
	mv "$tmp" "$settings"
	chmod 600 "$settings"
elif [ -s "$settings" ]; then
	jq '"'"'if .permissions? then .permissions |= del(.defaultMode, .skipDangerousModePermissionPrompt) else . end'"'"' "$settings" >"$tmp"
	mv "$tmp" "$settings"
	chmod 600 "$settings"
else
	rm -f "$tmp"
fi
'

dvm_agent_write_wrapper claude /usr/bin/claude
