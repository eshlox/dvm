sudo tee /etc/yum.repos.d/tailscale.repo >/dev/null <<'EOF'
[tailscale-stable]
name=Tailscale stable
baseurl=https://pkgs.tailscale.com/stable/fedora/$basearch
enabled=1
type=rpm
repo_gpgcheck=1
gpgcheck=1
gpgkey=https://pkgs.tailscale.com/stable/fedora/repo.gpg
EOF
dvm_pkg tailscale

sudo systemctl enable --now tailscaled || true
if sudo tailscale status >/dev/null 2>&1; then
    printf 'dvm recipe tailscale: already authenticated\n'
elif dvm_has_secret DVM_TAILSCALE_AUTHKEY; then
    sudo tailscale up --auth-key="file:$(dvm_secret DVM_TAILSCALE_AUTHKEY)" \
        --hostname "${DVM_TAILSCALE_HOSTNAME:-$DVM_NAME}"
else
    printf 'dvm recipe tailscale: no auth key staged; skipping tailscale up\n'
fi
