# shellcheck shell=bash
# shellcheck disable=SC2034,SC2088
# Dedicated Tailscale Funnel VM. Joins the tailnet so it can publish public
# `*.ts.net` URLs for other DVM VMs on demand.
#
# Funnel is OFF by default. Toggle it per-sync:
#   ON:  DVM_TAILSCALE_FUNNEL_TARGET="http://lima-dvm-app.internal:3000" dvm sync tailscale
#   OFF: dvm sync tailscale
#
# Pin a permanent target by uncommenting the line below.

DVM_NO_BASELINE=1
DVM_TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"

# DVM_TAILSCALE_FUNNEL_TARGET="http://lima-dvm-app.internal:3000"

# Optional: override the device name shown in the Tailscale admin console.
# Defaults to $DVM_NAME.
# DVM_TAILSCALE_HOSTNAME="dvm-funnel"

use tailscale
