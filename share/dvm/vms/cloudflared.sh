# Dedicated Cloudflare Tunnel VM.

DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/cloudflared"
DVM_CLOUDFLARED_TOKEN="${CLOUDFLARED_TOKEN:-}"

use cloudflared
