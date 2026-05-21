# dvm-conflicts: agent-user
dvm_pkg moby-engine docker-compose || dvm_pkg docker docker-compose-plugin

sudo systemctl enable --now docker || true
sudo usermod -aG docker "$DVM_USER" || true
if [ "${DVM_DOCKER_AGENT_ACCESS:-0}" = "1" ] && [ "$DVM_AGENT_USER" != "$DVM_USER" ]; then
    dvm_recipe_warn "$DVM_RECIPE" "adding $DVM_AGENT_USER to docker grants root-equivalent guest access"
    dvm_ensure_user "$DVM_AGENT_USER"
    sudo usermod -aG docker "$DVM_AGENT_USER" 2>/dev/null || true
elif [ "$DVM_AGENT_USER" != "$DVM_USER" ]; then
    printf 'dvm recipe docker: not adding %s to docker group; set DVM_DOCKER_AGENT_ACCESS=1 to opt in\n' "$DVM_AGENT_USER"
fi
