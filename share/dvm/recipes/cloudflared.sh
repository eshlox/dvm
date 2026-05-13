# shellcheck shell=bash
# Description: Cloudflare Tunnel service (dedicated VM)
# Expects DVM_SECRETS=(DVM_CLOUDFLARED_TOKEN) in the VM config.
service="${DVM_CLOUDFLARED_SERVICE:-dvm-cloudflared.service}"
token_file="$(dvm_secret DVM_CLOUDFLARED_TOKEN 2>/dev/null || true)"
token=""

dvm_recipe_validate_service cloudflared "$service"
if [ -n "$token_file" ] && [ -r "$token_file" ]; then
	trap 'sudo rm -f "$token_file"' EXIT
	token="$(sudo cat "$token_file")"
fi
if [ -n "$token" ]; then
	case "$token" in
	*[!A-Za-z0-9._=-]*) dvm_recipe_die cloudflared "invalid tunnel token characters" ;;
	esac
fi

dvm_pkg dnf5-plugins curl
if [ ! -f /etc/yum.repos.d/cloudflared.repo ]; then
	sudo dnf5 config-manager addrepo --from-repofile=https://pkg.cloudflare.com/cloudflared.repo ||
		sudo curl -fsSL -o /etc/yum.repos.d/cloudflared.repo https://pkg.cloudflare.com/cloudflared.repo
fi
dvm_pkg cloudflared
sudo install -d -m 0700 /etc/cloudflared

if [ -z "$token" ]; then
	if systemctl list-unit-files "$service" --no-legend 2>/dev/null |
		awk -v svc="$service" '$1 == svc { found = 1 } END { exit !found }'; then
		printf 'cloudflared service already configured: %s\n' "$service"
	else
		cat <<HELP
cloudflared installed.

To configure the tunnel, add DVM_SECRETS=(DVM_CLOUDFLARED_TOKEN) to
~/.config/dvm/vms/${DVM_VM}.sh and run:

  DVM_CLOUDFLARED_TOKEN=... dvm sync ${DVM_VM}
HELP
	fi
	exit 0
fi

tmp="$(mktemp)"
token_pattern="$(mktemp)"
trap 'rm -f "$tmp" "$token_pattern" "${token_file:-}"' EXIT
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
service_since="$(systemctl show "$service" -p ActiveEnterTimestamp --value 2>/dev/null || true)"
if [ -n "$service_since" ] && [ "$service_since" != "n/a" ]; then
	if sudo journalctl -u "$service" --since "$service_since" --no-pager 2>/dev/null | grep -Fqf "$token_pattern"; then
		dvm_recipe_warn cloudflared "$service journal contains the tunnel token; rotate the token and inspect logs"
	fi
elif sudo journalctl -u "$service" -n 200 --no-pager 2>/dev/null | grep -Fqf "$token_pattern"; then
	dvm_recipe_warn cloudflared "$service journal contains the tunnel token; rotate the token and inspect logs"
fi
printf 'cloudflared service configured: %s\n' "$service"
