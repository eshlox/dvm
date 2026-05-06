# Services

Long-running services should usually get dedicated VMs. That keeps project VMs small
and lets other VMs reach services through Lima's internal names. Bundled service VM
examples set `DVM_NO_BASELINE=1`, so service syncs install only the service recipe.

## Llama

Create an active config:

```bash
dvm init llama llama
dvm sync llama
```

Optional model download:

```bash
DVM_LLAMA_DEFAULT_MODEL="small"
DVM_LLAMA_MODELS="small=https://example.invalid/model.gguf"
DVM_LLAMA_MODELS_SHA256="small=..."
```

`DVM_LLAMA_MODELS` is a space-separated `alias=https://...` list. The recipe downloads
the selected alias, verifies the matching checksum when provided, and symlinks it to
`~/models/current.gguf`. `DVM_LLAMA_REFRESH=1` forces a re-download.

If no model URL is configured, place a model at:

```text
~/models/current.gguf
```

inside the llama VM, then run:

```bash
dvm sync llama
```

Other VMs can call:

```bash
curl http://lima-dvm-llama.internal:8080
```

The bundled `share/dvm/vms/llama.sh` opens `DVM_PORTS="8080:8080"` and sets
`DVM_LLAMA_HOST="0.0.0.0"`, so the service is reachable from the host and from other
VMs by default:

```bash
curl http://127.0.0.1:8080
curl http://lima-dvm-llama.internal:8080
```

Logs:

```bash
dvm log llama
```

## Cloudflared

Create an active config:

```bash
dvm init cloudflared cloudflared
CLOUDFLARED_TOKEN="..." dvm sync cloudflared
```

The example config maps `CLOUDFLARED_TOKEN` to `DVM_CLOUDFLARED_TOKEN`. The recipe
writes `/etc/cloudflared/dvm.env` with mode `0600` when a token is present and starts
`dvm-cloudflared.service`. DVM stages that token through a mode `0600` guest temp file
during `sync`, so the token is not passed as a `limactl shell env` argument on the
host.

For host convenience, use macOS Keychain yourself:

```bash
security add-generic-password -a dvm -s cloudflared -w "$TOKEN"
CLOUDFLARED_TOKEN="$(security find-generic-password -a dvm -s cloudflared -w)" \
  dvm sync cloudflared
```

DVM does not have a secret command. Rotate the token in Cloudflare if the VM is
compromised.

## Tailscale

Use case this recipe is designed for: **publish a local VM service at a public
`*.ts.net` URL on demand, share it with a teammate or external user, then turn
it off when you're done**. Funnel is OFF by default; you flip it on by passing
`DVM_TAILSCALE_FUNNEL_TARGET=<url>` at sync time and OFF by syncing again
without it.

DVM ships a `tailscale` recipe and a dedicated `tailscale` VM template that
joins the tailnet and proxies one HTTP backend (running in any other DVM VM
reachable via Lima's internal DNS) to a public Funnel URL.

### One-time setup

1. **Get an auth key.** Sign in at `login.tailscale.com/admin` → **Settings →
   Keys** → **Generate auth key**. For a long-lived proxy node, use a
   **reusable** key. Recommended: tag the key (e.g. `tag:dvm`) so ACLs can
   reason about it. Copy the `tskey-...` value.

2. **Allow Funnel in your tailnet ACL.** Open **Access controls** in the admin
   console and ensure your policy grants the `funnel` node attribute to the
   tunnel device — for example:

   ```hujson
   "nodeAttrs": [
     { "target": ["tag:dvm"], "attr": ["funnel"] }
   ]
   ```

   Without this, `tailscale funnel` will report a permissions error inside the
   VM. (Tailnets that allow Funnel everywhere can use a broader target like
   `["*"]`, but tag-scoped is preferred.)

3. **Create the proxy VM.**

   ```bash
   dvm init tailscale tailscale
   TAILSCALE_AUTH_KEY="tskey-..." dvm sync tailscale
   ```

   The VM joins the tailnet. Funnel stays off — no public URL yet.

The bundled template sets `DVM_NO_BASELINE=1` and maps `TAILSCALE_AUTH_KEY` to
`DVM_TAILSCALE_AUTH_KEY`. DVM stages the key through a mode `0600` guest temp
file during `sync`, so the value is never passed as a `limactl shell env`
argument on the host.

### Day-to-day: turn Funnel on/off

When a teammate needs to see your dev app for a few hours:

```bash
# Turn ON, pointing at the app VM's local port
DVM_TAILSCALE_FUNNEL_TARGET="http://lima-dvm-app.internal:3000" \
  dvm sync tailscale

# DVM prints the public URL, e.g.:
#   tailscale funnel: ON, target=http://lima-dvm-app.internal:3000
#   tailscale public url: https://<machine>.<tailnet>.ts.net
```

Share the URL. When you're done:

```bash
# Turn OFF
dvm sync tailscale
# tailscale funnel: OFF (set DVM_TAILSCALE_FUNNEL_TARGET=URL to enable)
```

The recipe runs `tailscale funnel reset` on every sync, so leaving
`DVM_TAILSCALE_FUNNEL_TARGET` unset means OFF. No state to forget about.

### Pinning a permanent target

If a single VM should always be the funnel target (e.g. a dedicated demo VM
that's always sharing the same service), set the variable in the VM config
itself instead of passing it at the command line:

```bash
# in ~/.config/dvm/vms/tailscale.sh
DVM_TAILSCALE_FUNNEL_TARGET="http://lima-dvm-demo.internal:8080"
```

Then every `dvm sync tailscale` keeps Funnel ON pointing there. Comment the
line out (or delete it) when you want to go back to the on-demand workflow.

### Limits to know

- **One Funnel target per node.** To expose multiple services publicly at the
  same time, run multiple Tailscale VMs (`dvm init demo-a tailscale`,
  `dvm init demo-b tailscale`) and point each at a different backend.
- **Funnel listens only on ports 443, 8443, 10000.** The recipe uses 443. The
  *backend* (the URL you point at) can run on any port — Funnel terminates
  TLS and proxies to whatever you specify.
- **`tailscaled` must keep running for the tunnel to stay up.** `dvm stop
  tailscale` or shutting down the host kills the public URL until the VM
  starts again.
- **The URL is your tailnet hostname**, like
  `<machine>.<tailnet>.ts.net` — no custom domain. If you need a custom
  domain, use the `cloudflared` recipe instead.

### Auth key rotation and tear-down

To rotate the auth key, generate a new one in the admin console, run
`TAILSCALE_AUTH_KEY="tskey-new..." dvm sync tailscale`, then delete the old
key. To remove the VM from your tailnet, delete the device in the admin
console (or `dvm sh tailscale` then `sudo tailscale logout`) and then
`dvm rm tailscale --yes`.

## Logs

DVM has a log helper for service VMs:

```bash
dvm log cloudflared
dvm log cloudflared -f
dvm log cloudflared dvm-cloudflared.service -f
dvm log llama
dvm log tailscale tailscaled.service -f
```

If a VM has no known service recipe or more than one, pass the systemd unit explicitly.
All arguments after the inferred or explicit unit are passed to `journalctl`, including
filters such as `--since` and `--until`.
