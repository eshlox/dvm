#!/usr/bin/env bash
# Description: Tailscale mesh + optional Funnel public ingress
set -euo pipefail

tailscale_die() {
	printf 'dvm recipe: error: tailscale: %s\n' "$*" >&2
	exit 1
}

if ! command -v tailscale >/dev/null 2>&1; then
	sudo dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
	sudo dnf5 install -y tailscale
fi

sudo systemctl enable --now tailscaled

hostname="${DVM_TAILSCALE_HOSTNAME:-${DVM_NAME:-}}"
[ -n "$hostname" ] || tailscale_die "DVM_TAILSCALE_HOSTNAME is required when DVM_NAME is unset"

auth_key=""
auth_key_file="${DVM_TAILSCALE_AUTH_KEY_FILE:-}"
if [ -n "$auth_key_file" ] && [ -f "$auth_key_file" ]; then
	auth_key="$(cat "$auth_key_file")"
	rm -f "$auth_key_file"
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
	[ -n "$auth_key" ] || tailscale_die "tailscale is not authenticated; pass TAILSCALE_AUTH_KEY=tskey-... when running dvm sync"
	sudo tailscale up --auth-key="$auth_key" --hostname="$hostname" --accept-dns
	;;
esac

sudo tailscale funnel reset >/dev/null 2>&1 || true
if [ -n "${DVM_TAILSCALE_FUNNEL_TARGET:-}" ]; then
	target="$DVM_TAILSCALE_FUNNEL_TARGET"
	case "$target" in
	http://* | https://*) ;;
	*) tailscale_die "DVM_TAILSCALE_FUNNEL_TARGET must be a http:// or https:// URL: $target" ;;
	esac
	case "$target" in
	*' '* | *$'\n'* | *$'\r'* | *'"'* | *'`'*) tailscale_die "invalid characters in DVM_TAILSCALE_FUNNEL_TARGET: $target" ;;
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
