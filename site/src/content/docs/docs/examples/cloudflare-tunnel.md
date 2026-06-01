---
title: "Cloudflare Tunnel"
description: "Expose a service from the VM with a Cloudflare Tunnel."
---

Install `cloudflared` from Cloudflare's current repo instructions or a
[verified binary download](/docs/examples/binaries/).

Store tunnel credentials inside the VM. Do not put tokens in DVM config.

## One static hostname across many VMs

Goal: keep a single public hostname (say `dev.example.com`, already on a
CORS allowlist) and point it at whichever VM you are working in. Run
`cloudflared` *inside each VM* against that VM's own `localhost`. Because you run
it in the foreground, only one connector is ever live, so the hostname always
resolves to exactly one VM. To switch, stop it and start it in another VM.

Do not run `cloudflared` in a dedicated VM to reach the others: Lima VMs use
user-mode networking and cannot reach each other, and `DVM_PORTS` forwards bind
to the host's `127.0.0.1` only. A separate VM has no path to the app VMs.

### One-time: create a locally-managed tunnel

Use a credentials file, not a `--token` tunnel; a token keeps ingress in the
dashboard and blocks the per-run `--url` override below. Run this once in any
VM that has `cloudflared`:

```bash
cloudflared tunnel login                                   # browser auth -> cert.pem
cloudflared tunnel create dev                              # writes <uuid>.json
cloudflared tunnel route dns dev dev.example.com
```

Note the tunnel UUID. `cert.pem` is only needed for management (create, route,
delete), not for running, so app VMs never need it.

Write a minimal `config.yml` (no ingress rules; `--url` supplies the service):

```yaml
# config.yml
tunnel: <uuid>
credentials-file: /home/<DVM_USER>/.cloudflared/<uuid>.json
```

### Per-VM setup script

Installs `cloudflared` and adds a `cf` helper. No secrets here.

```bash
# install cloudflared per Cloudflare's repo or examples/binaries.md, then:
sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  install -d -m 700 ~/.cloudflared
  grep -q "^cf()" ~/.bashrc 2>/dev/null || cat >>~/.bashrc <<'"'"'EOF'"'"'
cf() { cloudflared tunnel --url "http://localhost:${1:-3000}" run; }
EOF
'
```

### Distribute the credentials

Copy the credentials file and `config.yml` into each VM after `dvm sync`. Keep
them out of setup scripts and DVM config:

```bash
dvm cp ./<uuid>.json   app1:/home/<DVM_USER>/.cloudflared/<uuid>.json
dvm cp ./config.yml    app1:/home/<DVM_USER>/.cloudflared/config.yml
```

### Switch the hostname between VMs

```bash
dvm sh app1
cf 3000        # dev.example.com -> app1's :3000  (foreground; Ctrl-C to stop)
# Ctrl-C, exit
dvm sh app2
cf 3000        # now -> app2
```

`cf <port>` targets the service inside that same VM, so no `DVM_PORTS` forward
is required for the tunnel. The foreground run keeps you to one active connector;
if you ever background it, make sure only one VM runs it at a time, or Cloudflare
will load-balance the hostname across connectors.
