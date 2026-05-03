# Services

Long-running services should usually get dedicated VMs. That keeps project VMs small
and lets other VMs reach services through Lima's internal names. Bundled service VM
examples set `DVM_NO_BASELINE=1`, so service applies install only the service recipe.

## Llama

Create an active config:

```bash
mkdir -p ~/.config/dvm/vms
cp share/dvm/vms/llama.sh ~/.config/dvm/vms/llama.sh
$EDITOR ~/.config/dvm/vms/llama.sh
dvm apply llama
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
dvm apply llama
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
dvm logs llama
```

## Cloudflared

Create an active config:

```bash
mkdir -p ~/.config/dvm/vms
cp share/dvm/vms/cloudflared.sh ~/.config/dvm/vms/cloudflared.sh
CLOUDFLARED_TOKEN="..." dvm apply cloudflared
```

The example config maps `CLOUDFLARED_TOKEN` to `DVM_CLOUDFLARED_TOKEN`. The recipe
writes `/etc/cloudflared/dvm.env` with mode `0600` when a token is present and starts
`dvm-cloudflared.service`.

For host convenience, use macOS Keychain yourself:

```bash
security add-generic-password -a dvm -s cloudflared -w "$TOKEN"
CLOUDFLARED_TOKEN="$(security find-generic-password -a dvm -s cloudflared -w)" \
  dvm apply cloudflared
```

DVM does not have a secret command. Rotate the token in Cloudflare if the VM is
compromised.

## Logs

DVM has a logs helper for service VMs:

```bash
dvm logs cloudflared
dvm logs cloudflared -f
dvm logs cloudflared dvm-cloudflared.service -f
dvm logs llama
```

If a VM has no known service recipe or more than one, pass the systemd unit explicitly.
