---
title: "Rootless Docker"
description: "Run Docker rootless inside the guest (recommended)."
---

Recommended for AI/dev VMs. Containers run as `DVM_USER` with no root-owned
Docker socket and no `docker` group. Container root maps to unprivileged guest
ids via the subordinate ranges DVM creates by default.

`dvm-base` already ships the rootless-docker user service, masks rootful Docker
and binfmt, and installs the rootless dependencies (`slirp4netns`,
`fuse-overlayfs`). You install the engine in your Containerfile and bring it up
per VM.

Install the engine in your base image:

```dockerfile
RUN dnf5 install -y moby-engine moby-engine-rootless-extras docker-compose \
 && dnf5 clean all
```

Then bring it up per VM. Needs `DVM_SUBUID_COUNT`/`DVM_SUBGID_COUNT` > 0 (the
default); if the user already existed, run `dvm sync` once more so DVM adds the
ranges.

```bash
uid="$(id -u "$DVM_USER")"
group="$(id -gn "$DVM_USER")"

# Linger lets the user's systemd run without an interactive login.
sudo loginctl enable-linger "$DVM_USER"
sudo systemctl start "user@$uid.service"
sudo install -d -o "$DVM_USER" -g "$group" -m 700 "/run/user/$uid"

sudo -u "$DVM_USER" -H env XDG_RUNTIME_DIR="/run/user/$uid" bash -lc '
  set -Eeuo pipefail
  export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
  if ! systemctl --user cat docker.service >/dev/null 2>&1; then
    dockerd-rootless-setuptool.sh install
  fi
  systemctl --user enable --now docker.service
  docker context use rootless >/dev/null 2>&1 || true
'
```

Verify and run, as `DVM_USER`, without `sudo`:

```bash
docker info --format '{{.SecurityOptions}}'
docker compose version
docker run --rm hello-world
```

The socket lives at `/run/user/<uid>/docker.sock`. Rootless containers can still
read and modify project files and credentials owned by `DVM_USER`. Treat them as
project-local execution, not a boundary against code you run in the VM.
