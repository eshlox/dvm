---
title: "Packages"
description: "Install Fedora and Copr packages in a setup script."
---

Fedora packages come from the configured Fedora repos. Fine for baseline tools.

```bash
sudo dnf5 install -y git ripgrep fd-find tmux helix git-delta
```

Install in one transaction and skip weak deps for faster, smaller installs:

```bash
sudo dnf5 install -y --setopt=install_weak_deps=False \
  ca-certificates curl unzip tar gzip jq \
  git git-delta openssh-clients ncurses-term \
  helix chezmoi bat fzf just bubblewrap \
  python3 python3-pip python3-virtualenv pipx \
  nodejs npm \
  zsh util-linux-user shadow-utils
```

## Copr

The DNF5 Copr plugin may be missing on minimal images. Quote the package name
because of the parentheses.

```bash
dnf5 copr --help >/dev/null 2>&1 || \
  sudo dnf5 install -y 'dnf5-command(copr)'

sudo dnf5 copr enable -y dejan/lazygit
sudo dnf5 copr enable -y atim/starship
sudo dnf5 install -y lazygit starship
```

## Upgrade

Skip on fast re-runs by guarding with your own env var.

```bash
sudo dnf5 upgrade -y --refresh
```
