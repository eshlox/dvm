#!/usr/bin/env bash
set -euo pipefail

service="${DVM_CLOUDFLARED_SERVICE:-dvm-cloudflared.service}"
token="${DVM_CLOUDFLARED_TOKEN:-}"

case "$service" in
*.service) ;;
*) echo "DVM_CLOUDFLARED_SERVICE must end with .service: $service" >&2; exit 1 ;;
esac
case "$service" in
*/* | *..* | *[!A-Za-z0-9_.@-]*) echo "invalid DVM_CLOUDFLARED_SERVICE: $service" >&2; exit 1 ;;
esac
if [ -n "$token" ]; then
	case "$token" in
	*[!A-Za-z0-9._=-]*) echo "invalid DVM_CLOUDFLARED_TOKEN" >&2; exit 1 ;;
	esac
fi

sudo dnf5 install -y curl
curl -fsSL https://pkg.cloudflare.com/cloudflared.repo |
	sudo tee /etc/yum.repos.d/cloudflared.repo >/dev/null
sudo dnf5 install -y cloudflared

if [ -z "$token" ]; then
	if systemctl list-unit-files "$service" --no-legend 2>/dev/null | awk -v svc="$service" '$1 == svc { found = 1 } END { exit !found }'; then
		printf 'cloudflared service already configured: %s\n' "$service"
else
	cat <<HELP
cloudflared installed.

To configure a static cloudflared service, rerun setup with:
  CLOUDFLARED_TOKEN=... dvm setup "$DVM_NAME"

The VM config should assign:
  DVM_CLOUDFLARED_TOKEN="\${CLOUDFLARED_TOKEN:-}"
HELP
	fi
	exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
printf 'TUNNEL_TOKEN=%s\n' "$token" >"$tmp"
sudo install -d -m 0755 /etc/cloudflared
sudo install -m 0600 -o root -g root "$tmp" /etc/cloudflared/dvm.env

cloudflared_bin="$(command -v cloudflared)"
sudo tee "/etc/systemd/system/$service" >/dev/null <<UNIT
[Unit]
Description=DVM cloudflared
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/etc/cloudflared/dvm.env
ExecStart=$cloudflared_bin tunnel --no-autoupdate run --token \${TUNNEL_TOKEN}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now "$service"
printf 'cloudflared service configured: %s\n' "$service"
