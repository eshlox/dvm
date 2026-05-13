# Services

Long-running services usually deserve their own VM. Other VMs reach them
via Lima's internal DNS (`lima-dvm-<name>.internal`).

## llama

`share/dvm/recipes/llama.sh` installs llama.cpp and writes
`dvm-llama.service`. Single-model env-var config:

```bash
# ~/.config/dvm/vms/llama.sh
DVM_CPUS=8
DVM_MEMORY=16GiB
DVM_DISK=120GiB
DVM_PORTS=(8080:8080)
DVM_RECIPES=(llama)

# Optional: download + verify one model
DVM_LLAMA_MODEL_URL="https://example.invalid/model.gguf"
DVM_LLAMA_MODEL_SHA256="0000...64hex"

# Optional bind + port
DVM_LLAMA_HOST=127.0.0.1
DVM_LLAMA_PORT=8080
```

Then:

```bash
dvm sync llama
# or, no URL: drop a .gguf at /home/$DVM_USER/models/current.gguf and sync
curl http://127.0.0.1:8080            # from the host
curl http://lima-dvm-llama.internal:8080   # from another VM
dvm log llama -f
```

## cloudflared

`share/dvm/recipes/cloudflared.sh` installs cloudflared and writes
`dvm-cloudflared.service`. The token is staged via `DVM_SECRETS`:

```bash
# ~/.config/dvm/vms/cloud.sh
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=10GiB
DVM_RECIPES=(cloudflared)
DVM_SECRETS=(DVM_CLOUDFLARED_TOKEN)
```

At sync time:

```bash
DVM_CLOUDFLARED_TOKEN="..." dvm sync cloud
dvm log cloud -f
```

The value is piped through stdin to `install -m 600 -o $DVM_USER`. It
never appears in argv, host process env, or a host temp file.

macOS Keychain helper:

```bash
security add-generic-password -a "$USER" -s dvm-cloudflared -w "$TOKEN"
DVM_CLOUDFLARED_TOKEN="$(security find-generic-password \
    -a "$USER" -s dvm-cloudflared -w)" dvm sync cloud
```

Rotate the token in Cloudflare and re-sync if the VM is compromised. DVM
has no secret store.

## tailscale

Two patterns; pick either or both.

### Pattern 1 — private dev access (per app VM)

Reach `http://app:5173` from your tailnet without juggling host ports.

```bash
# host
brew install --cask tailscale && open -a Tailscale.app   # macOS
# log into the same tailnet

# ~/.config/dvm/vms/app.sh
DVM_RECIPES=(tailscale)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY)
# optional: DVM_TAILSCALE_HOSTNAME="app"   (defaults to $DVM_VM)
```

```bash
DVM_TAILSCALE_AUTHKEY="tskey-..." dvm sync app
```

`http://app:5173` resolves via MagicDNS. Drop a clean HTTPS URL with
`sudo tailscale serve --bg --https=443 http://localhost:5173` inside the
VM if you want `https://app.<tailnet>.ts.net`.

### Pattern 2 — public Funnel URL (dedicated VM)

Publish one HTTP backend (running in any DVM VM) at a public
`*.ts.net` URL on demand.

```bash
# ~/.config/dvm/vms/ts.sh
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_RECIPES=(tailscale)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY)
```

Prereq: the tunnel device must have `funnel` in your tailnet ACL
`nodeAttrs` (use a tag like `tag:dvm`).

```bash
# join the tailnet
DVM_TAILSCALE_AUTHKEY="tskey-..." dvm sync ts

# turn Funnel ON, pointing at any reachable backend
DVM_TAILSCALE_FUNNEL_TARGET="http://lima-dvm-app.internal:3000" \
  DVM_TAILSCALE_AUTHKEY="tskey-..." dvm sync ts

# turn Funnel OFF (recipe resets on every sync)
DVM_TAILSCALE_AUTHKEY="tskey-..." dvm sync ts
```

Limits: one Funnel target per node, listens on 443/8443/10000, no custom
domain (use `cloudflared` for that).

### Auth key sourcing

Generate a reusable key in the admin console. Three options, in
order of decreasing exposure:

1. **Per-sync env** — `DVM_TAILSCALE_AUTHKEY="tskey-..." dvm sync ...`.
   Lives only in the calling shell.
2. **macOS Keychain** — store once, read at sync time:
   ```bash
   security add-generic-password -a "$USER" -s dvm-tailscale -w "tskey-..."
   DVM_TAILSCALE_AUTHKEY="$(security find-generic-password \
       -a "$USER" -s dvm-tailscale -w)" dvm sync app
   ```
3. **Shell rc** — `export DVM_TAILSCALE_AUTHKEY="..."` in `~/.zshrc`.
   Plaintext on disk; acceptable for personal tailnets on encrypted
   laptops.

To remove a VM from your tailnet: `dvm sh <vm>; sudo tailscale logout`,
then `dvm rm <vm> --yes`, then delete the device in the admin console.

## Logs

```bash
dvm log llama
dvm log cloud -f
dvm log ts tailscaled.service -f
```

Everything after the VM name is forwarded to `journalctl`.
