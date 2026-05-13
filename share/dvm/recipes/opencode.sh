# Description: OpenCode CLI
dvm_recipe_require_agent_user opencode

dvm_pkg nodejs npm
sudo -H -u "$DVM_AI_AGENT_USER" bash -lc 'npm config set prefix "$HOME/.local" && npm install -g opencode-ai@latest'
dvm_agent_write_wrapper opencode "/home/$DVM_AI_AGENT_USER/.local/bin/opencode"
