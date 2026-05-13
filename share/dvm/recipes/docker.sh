# Description: Docker Engine and Docker Compose plugin
if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
	sudo dnf5 config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
fi

sudo dnf5 install -y \
	docker-ce docker-ce-cli containerd.io \
	docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker.service

if ! id -nG "$DVM_USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
	sudo usermod -aG docker "$DVM_USER"
fi
