# Setup examples

These are examples for user-owned setup scripts. They are not DVM runtime code.
Review and adapt them before use.

All examples assume Fedora with `dnf5`. Setup scripts run during `dvm sync` and
receive `DVM_USER` and `DVM_CODE_DIR`.

## Packages

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

sudo dnf5 install -y git ripgrep fd-find tmux helix git-delta
```

## User-local npm tools

```bash
sudo dnf5 install -y nodejs npm

sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  npm install --global --prefix "$HOME/.local/npm" --ignore-scripts \
    @openai/codex@0.132.0
  grep -Fqx "export PATH=\"\$HOME/.local/npm/bin:\$PATH\"" ~/.bashrc ||
    printf "%s\n" "export PATH=\"\$HOME/.local/npm/bin:\$PATH\"" >>~/.bashrc
'
```

If a package requires lifecycle scripts, remove `--ignore-scripts` only after
reviewing the package and accepting that install-time code will run.

## Root-owned shared npm tool

Use this only when you want one VM-wide tool version:

```bash
sudo dnf5 install -y nodejs npm
sudo install -d -m 0755 /opt/devtools/npm
sudo npm install --global --prefix /opt/devtools/npm --ignore-scripts \
  @openai/codex@0.132.0
sudo ln -sfn /opt/devtools/npm/bin/codex /usr/local/bin/codex
```

Project users can execute the tool but cannot modify the installed files unless
they have sudo.

## Verified binary download

```bash
url="https://example.invalid/tool-v1.2.3-linux-amd64"
sha256="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
tmp="$(mktemp)"

curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$tmp"
printf '%s  %s\n' "$sha256" "$tmp" | sha256sum -c -
sudo install -m 0755 "$tmp" /usr/local/bin/tool
rm -f "$tmp"
```

## VM-local SSH key

```bash
sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  install -d -m 700 ~/.ssh
  if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -N "" -C "$USER@$HOSTNAME" -f ~/.ssh/id_ed25519
  fi
  cat ~/.ssh/id_ed25519.pub
'
```

Add the public key to your Git host. Do not copy host private keys into the VM.

## VM-local GPG key

```bash
sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  if ! gpg --list-secret-keys --with-colons | grep -q "^sec:"; then
    gpg --batch --passphrase "" --quick-generate-key \
      "$USER@$HOSTNAME" ed25519 sign 1y
  fi
'
```

## Tailscale

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

Authenticate interactively inside the VM or pass an auth key deliberately for
one sync invocation. Do not store long-lived auth keys in DVM config.

## Cloudflare Tunnel

Install `cloudflared` using Cloudflare's current repository instructions or a
verified binary download. Store tunnel credentials inside the VM and avoid
putting tokens in DVM config.

## Rootless Docker

Rootless Docker needs subordinate uid/gid ranges for `DVM_USER`. Enable them in
the VM config before syncing:

```bash
DVM_SUBUID_COUNT=65536
DVM_SUBGID_COUNT=65536
```

Then install Docker's rootless packages from the setup script:

```bash
sudo dnf5 install -y moby-engine moby-engine-rootless-extras \
  docker-compose-plugin uidmap slirp4netns fuse-overlayfs

uid="$(id -u "$DVM_USER")"
group="$(id -gn "$DVM_USER")"
sudo loginctl enable-linger "$DVM_USER"
sudo systemctl start "user@$uid.service"
sudo install -d -o "$DVM_USER" -g "$group" -m 700 "/run/user/$uid"

sudo -u "$DVM_USER" -H env XDG_RUNTIME_DIR="/run/user/$uid" bash -lc '
  set -Eeuo pipefail
  if ! systemctl --user cat docker.service >/dev/null 2>&1; then
    dockerd-rootless-setuptool.sh install
  fi
  systemctl --user enable --now docker
  docker context use rootless >/dev/null 2>&1 || true
'
```

Verify from the VM:

```bash
docker info --format '{{.SecurityOptions}}'
docker compose version
```

Rootless Docker is still privileged inside the project VM from the perspective
of project files and user-owned credentials, but it does not expose the
root-owned Docker socket to the AI/user account.

## Rootful Docker

```bash
sudo dnf5 install -y moby-engine docker-compose || \
  sudo dnf5 install -y docker docker-compose-plugin
sudo systemctl enable --now docker
```

Adding a user to the Docker group is guest-root equivalent:

```bash
sudo usermod -aG docker "$DVM_USER"
```

Use a throwaway VM for untrusted Docker-heavy projects.

## Chezmoi

```bash
sudo dnf5 install -y chezmoi git

sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  if [ ! -d ~/.local/share/chezmoi ]; then
    chezmoi init https://github.com/me/dotfiles.git
  fi
  chezmoi apply
'
```

Review dotfiles before applying them in a VM with credentials.

## Single VM with one user per project

For a personal workflow, you can also use one long-lived VM and separate Linux
users per project:

```bash
sudo useradd -m -s /bin/bash project-a
sudo chmod 700 /home/project-a
sudo install -d -o project-a -g project-a -m 700 /home/project-a/project
```

Switch projects by switching users:

```bash
sudo -iu project-a
cd ~/project
```

This is easier for shared tool installs, but weaker than one VM per project.
Guest-root compromise can read every project in the VM.
