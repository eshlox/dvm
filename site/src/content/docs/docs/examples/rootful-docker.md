---
title: "Rootful Docker"
description: "Run rootful Docker, and the guest-root risk it carries."
---

Prefer [rootless Docker](/docs/examples/rootless-docker/). Adding a user to the `docker`
group is guest-root equivalent: that user can become root and read every project
in the VM. Use a throwaway VM for Docker-heavy or untrusted work.

```bash
sudo dnf5 install -y moby-engine docker-compose || \
  sudo dnf5 install -y docker docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$DVM_USER"
```
