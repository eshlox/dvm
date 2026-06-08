---
title: "Rootless Podman"
description: "Run Podman rootless inside the guest."
---

Podman is rootless and daemonless when run as `DVM_USER`. It uses the
subordinate uid/gid ranges DVM creates by default. `dvm-base` already installs
`slirp4netns` and `fuse-overlayfs`; add Podman itself in your Containerfile:

```dockerfile
RUN dnf5 install -y podman podman-compose && dnf5 clean all
```

Run as `DVM_USER`, without `sudo`:

```bash
podman run --rm alpine echo ok
podman compose version
```
