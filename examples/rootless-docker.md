# Rootless Docker

Recommended for AI/dev VMs. Containers run as `DVM_USER` with no root-owned
Docker socket and no `docker` group. Container root maps to unprivileged guest
ids via the subordinate ranges DVM creates by default.

Needs `DVM_SUBUID_COUNT`/`DVM_SUBGID_COUNT` > 0 (the default). If the user
already existed, run `dvm sync` once more so DVM adds the ranges.

```bash
sudo dnf5 install -y moby-engine moby-engine-rootless-extras \
  docker-compose shadow-utils slirp4netns fuse-overlayfs

# Avoid rootful Docker; the socket can silently reactivate the daemon.
sudo systemctl disable --now docker.service docker.socket 2>/dev/null || true
sudo rm -f /var/run/docker.sock 2>/dev/null || true

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
