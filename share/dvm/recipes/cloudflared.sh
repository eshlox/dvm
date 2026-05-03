#!/usr/bin/env bash
set -euo pipefail

cloudflared_die() {
	printf 'dvm recipe: error: cloudflared: %s\n' "$*" >&2
	exit 1
}

cloudflared_warn() {
	printf 'dvm recipe: warning: cloudflared: %s\n' "$*" >&2
}

cloudflared_validate_service() {
	case "$1" in
	*.service) ;;
	*) cloudflared_die "service must end with .service: $1" ;;
	esac
	case "$1" in
	*/* | *..* | *[!A-Za-z0-9_.@-]*) cloudflared_die "invalid service name: $1" ;;
	esac
}

service="${DVM_CLOUDFLARED_SERVICE:-dvm-cloudflared.service}"
token="${DVM_CLOUDFLARED_TOKEN:-${CLOUDFLARED_TOKEN:-}}"

cloudflared_validate_service "$service"
if [ -n "$token" ]; then
	case "$token" in
	*[!A-Za-z0-9._=-]*) cloudflared_die "invalid tunnel token characters" ;;
	esac
fi

sudo dnf5 install -y dnf5-plugins curl
if [ ! -f /etc/yum.repos.d/cloudflared.repo ]; then
	sudo dnf5 config-manager addrepo --from-repofile=https://pkg.cloudflare.com/cloudflared.repo ||
		sudo curl -fsSL -o /etc/yum.repos.d/cloudflared.repo https://pkg.cloudflare.com/cloudflared.repo
fi
sudo dnf5 install -y cloudflared
sudo install -d -m 0700 /etc/cloudflared

if [ -z "$token" ]; then
	if systemctl list-unit-files "$service" --no-legend 2>/dev/null |
		awk -v svc="$service" '$1 == svc { found = 1 } END { exit !found }'; then
		printf 'cloudflared service already configured: %s\n' "$service"
	else
		cat <<HELP
cloudflared installed.

To configure the tunnel, pass a token at apply time:
  CLOUDFLARED_TOKEN=... dvm apply "$DVM_NAME"

For a VM config, use:
  DVM_CLOUDFLARED_TOKEN="\${CLOUDFLARED_TOKEN:-}"
HELP
	fi
	exit 0
fi

tmp="$(mktemp)"
token_pattern="$(mktemp)"
trap 'rm -f "$tmp" "$token_pattern"' EXIT
printf 'TUNNEL_TOKEN=%s\n' "$token" >"$tmp"
printf '%s\n' "$token" >"$token_pattern"
sudo install -m 0600 -o root -g root "$tmp" /etc/cloudflared/dvm.env

cloudflared_bin="$(command -v cloudflared)"
sudo tee "/etc/systemd/system/$service" >/dev/null <<DVM_CLOUDFLARED_SERVICE
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
DVM_CLOUDFLARED_SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now "$service"
if sudo journalctl -u "$service" -n 200 --no-pager 2>/dev/null | grep -Fqf "$token_pattern"; then
	cloudflared_warn "$service journal contains the tunnel token; rotate the token and inspect logs"
fi
printf 'cloudflared service configured: %s\n' "$service"
