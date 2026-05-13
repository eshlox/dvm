# Description: Tailscale mesh + optional Funnel public ingress
# Expects DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY) in the VM config for first auth.
if ! command -v tailscale >/dev/null 2>&1; then
	sudo dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
		|| sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
	dvm_pkg tailscale
fi

sudo systemctl enable --now tailscaled

hostname="${DVM_TAILSCALE_HOSTNAME:-${DVM_VM:-}}"
[ -n "$hostname" ] || dvm_recipe_die tailscale "DVM_TAILSCALE_HOSTNAME is required"

auth_key=""
auth_key_file="$(dvm_secret DVM_TAILSCALE_AUTHKEY 2>/dev/null || true)"
if [ -n "$auth_key_file" ] && [ -r "$auth_key_file" ]; then
	auth_key="$(sudo cat "$auth_key_file")"
	sudo rm -f "$auth_key_file"
fi

current_state=""
if status_json="$(tailscale status --json 2>/dev/null)"; then
	current_state="$(printf '%s\n' "$status_json" | sed -n 's/.*"BackendState"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

case "$current_state" in
Running)
	if [ -n "$auth_key" ]; then
		printf 'tailscale: re-running tailscale up with new auth key\n' >&2
		sudo tailscale up --auth-key="$auth_key" --hostname="$hostname" --accept-dns --reset
	fi
	;;
*)
	[ -n "$auth_key" ] || dvm_recipe_die tailscale "tailscale is not authenticated; pass TAILSCALE_AUTH_KEY=tskey-... when running dvm sync"
	sudo tailscale up --auth-key="$auth_key" --hostname="$hostname" --accept-dns
	;;
esac

sudo tailscale funnel reset >/dev/null 2>&1 || true
if [ -n "${DVM_TAILSCALE_FUNNEL_TARGET:-}" ]; then
	target="$DVM_TAILSCALE_FUNNEL_TARGET"
	case "$target" in
	http://* | https://*) ;;
	*) dvm_recipe_die tailscale "DVM_TAILSCALE_FUNNEL_TARGET must be a http:// or https:// URL: $target" ;;
	esac
	case "$target" in
	*' '* | *$'\n'* | *$'\r'* | *'"'* | *'`'*) dvm_recipe_die tailscale "invalid characters in DVM_TAILSCALE_FUNNEL_TARGET: $target" ;;
	esac
	sudo tailscale funnel --bg --https=443 "$target"
	printf 'tailscale funnel: ON, target=%s\n' "$target"
else
	printf 'tailscale funnel: OFF (set DVM_TAILSCALE_FUNNEL_TARGET=URL to enable)\n'
fi

ipv4="$(tailscale ip --4 2>/dev/null | head -1 || true)"
[ -n "$ipv4" ] && printf 'tailscale ipv4: %s\n' "$ipv4"
public_url="$(tailscale serve status 2>/dev/null | sed -n 's|^\(https://[^[:space:]]*\).*|\1|p' | head -1 || true)"
[ -n "$public_url" ] && printf 'tailscale public url: %s\n' "$public_url"
