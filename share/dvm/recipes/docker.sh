sudo dnf5 install -y moby-engine docker-compose || sudo dnf5 install -y docker docker-compose-plugin

sudo systemctl enable --now docker || true
sudo usermod -aG docker "$DVM_USER" || true
[ "$DVM_AGENT_USER" != "$DVM_USER" ] && sudo usermod -aG docker "$DVM_AGENT_USER" 2>/dev/null || true
