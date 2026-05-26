# Tailscale

```bash
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

sudo dnf5 install -y tailscale
sudo systemctl enable --now tailscaled
```

Authenticate inside the VM, or pass an auth key for one sync invocation. Do not
store long-lived auth keys in DVM config.
