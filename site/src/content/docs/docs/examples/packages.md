---
title: "Packages"
description: "Install Fedora and Copr packages in the base image Containerfile."
---

Fedora packages come from the configured Fedora repos. Put them in your base
image so every VM has them. Install in one `RUN`, skip weak deps for a smaller
image, and clean the metadata in the same layer.

```dockerfile
RUN dnf5 install -y --setopt=install_weak_deps=False \
        ca-certificates curl unzip tar gzip jq \
        git git-delta openssh-clients ncurses-term \
        helix chezmoi bat fzf just bubblewrap \
        python3 python3-pip python3-virtualenv pipx \
        nodejs npm \
    && dnf5 clean all
```

For a quick baseline:

```dockerfile
RUN dnf5 install -y git ripgrep fd-find tmux helix git-delta && dnf5 clean all
```

`dvm-base` already installs `zsh` and the rootless-container dependencies, so you
do not need to repeat those.

## Copr

The DNF5 Copr plugin may be missing on minimal images. Quote the package name
because of the parentheses.

```dockerfile
RUN dnf5 copr --help >/dev/null 2>&1 || dnf5 install -y 'dnf5-command(copr)' \
 && dnf5 copr enable -y dejan/lazygit \
 && dnf5 copr enable -y atim/starship \
 && dnf5 install -y lazygit starship \
 && dnf5 clean all
```

## Upgrade

To build on top of the latest packages, upgrade before installing:

```dockerfile
RUN dnf5 upgrade -y --refresh && dnf5 clean all
```
