# Description: Codex CLI
dvm_recipe_require_agent_user codex
dvm_codex_yolo="$(dvm_recipe_bool codex DVM_CODEX_YOLO "${DVM_CODEX_YOLO:-1}")"

dvm_pkg nodejs npm
sudo -H -u "$DVM_AI_AGENT_USER" bash -lc 'npm config set prefix "$HOME/.local" && npm install -g @openai/codex@latest'

sudo tee /usr/local/libexec/dvm-codex >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [ "$dvm_codex_yolo" = "1" ]; then
	exec /home/$DVM_AI_AGENT_USER/.local/bin/codex --dangerously-bypass-approvals-and-sandbox "\$@"
fi
exec /home/$DVM_AI_AGENT_USER/.local/bin/codex "\$@"
EOF
sudo chmod 0755 /usr/local/libexec/dvm-codex
dvm_agent_write_wrapper codex /usr/local/libexec/dvm-codex
