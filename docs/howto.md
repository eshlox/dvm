# How to

## New VM

```bash
dvm new app
```

Edit `~/.config/dvm/vms/app/config.sh`:

```bash
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
```

Edit `~/.config/dvm/vms/app/setup.sh`:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

sudo dnf5 install -y git ripgrep fd-find tmux
```

Run:

```bash
DVM_DRY_RUN=1 dvm sync app
dvm sync app
dvm sh app
```

## Private repo

Create a VM-local key in the setup script or manually after first sync:

```bash
sudo -u "$DVM_USER" -H bash -lc '
  install -d -m 700 ~/.ssh
  test -f ~/.ssh/id_ed25519 ||
    ssh-keygen -t ed25519 -N "" -C "${DVM_NAME}-dvm-git-deploy" -f ~/.ssh/id_ed25519
  cat ~/.ssh/id_ed25519.pub
'
```

Add the public key to GitHub/GitLab, then clone inside the VM:

```bash
dvm sh app
git clone git@github.com:me/app.git ~/code/app
cd ~/code/app
```

DVM does not copy host private keys into guests.

## AI tools

Install AI tools deliberately in your setup script. Pin versions when the tool
manager supports it.

```bash
sudo dnf5 install -y nodejs npm
sudo -u "$DVM_USER" -H bash -lc '
  npm install --global --prefix "$HOME/.local/npm" --ignore-scripts \
    @openai/codex@0.132.0
  grep -Fqx "export PATH=\"\$HOME/.local/npm/bin:\$PATH\"" ~/.bashrc ||
    printf "%s\n" "export PATH=\"\$HOME/.local/npm/bin:\$PATH\"" >>~/.bashrc
'
```

See [examples.md](examples.md) for more secure setup patterns.

## Services

Local ports:

```bash
DVM_PORTS=(3000:3000)
```

For Tailscale, Cloudflare Tunnel, Docker, or other services, write the commands
in your setup script and review the trust boundary. Docker group access is
root-equivalent inside the guest.

## Debug

```bash
DVM_DRY_RUN=1 dvm sync app
dvm ssh app -- sudo journalctl -f
```
