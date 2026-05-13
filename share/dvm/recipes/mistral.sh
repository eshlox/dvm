# Description: Mistral CLI
: "${DVM_AI_AGENT_USER:=dvm-agent}"
dvm_recipe_require_agent_user mistral

sudo dnf5 install -y python3 uv
sudo -H -u "$DVM_AI_AGENT_USER" bash -lc 'uv tool install mistral-vibe && uv tool upgrade mistral-vibe && ln -sfn "$HOME/.local/bin/vibe" "$HOME/.local/bin/mistral"'
dvm_agent_write_wrapper vibe "/home/$DVM_AI_AGENT_USER/.local/bin/vibe"
dvm_agent_write_wrapper mistral "/home/$DVM_AI_AGENT_USER/.local/bin/mistral"
