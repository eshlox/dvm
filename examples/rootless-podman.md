# Rootless Podman

Podman is rootless and daemonless when run as `DVM_USER`. It uses the
subordinate uid/gid ranges DVM creates by default.

```bash
sudo dnf5 install -y podman podman-compose shadow-utils slirp4netns fuse-overlayfs
```

Run as `DVM_USER`, without `sudo`:

```bash
podman run --rm alpine echo ok
podman compose version
```
