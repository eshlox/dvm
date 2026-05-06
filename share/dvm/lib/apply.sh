# shellcheck shell=bash

run_guest_apply() {
	local cloudflared_token tailscale_auth_key helper recipe path var
	local -a args
	args=()
	cloudflared_token=""
	tailscale_auth_key=""
	if uses_recipe cloudflared; then
		cloudflared_token="${DVM_CLOUDFLARED_TOKEN:-${CLOUDFLARED_TOKEN:-}}"
		[ -z "$cloudflared_token" ] || validate_cloudflared_token "$cloudflared_token"
	fi
	if uses_recipe tailscale; then
		tailscale_auth_key="${DVM_TAILSCALE_AUTH_KEY:-${TAILSCALE_AUTH_KEY:-}}"
		[ -z "$tailscale_auth_key" ] || validate_tailscale_auth_key "$tailscale_auth_key"
	fi
	while IFS= read -r var; do
		case "$var" in
		DVM_ROOT | DVM_SHARE | DVM_CONFIG | DVM_FAKE_STATE | DVM_LIMA_NAME | DVM_RECIPES | DVM_NO_BASELINE | DVM_PORT_FORWARDS_YAML) continue ;;
		DVM_CLOUDFLARED_TOKEN | DVM_CLOUDFLARED_TOKEN_FILE) continue ;;
		DVM_TAILSCALE_AUTH_KEY | DVM_TAILSCALE_AUTH_KEY_FILE) continue ;;
		DVM_*) args+=("$var=${!var}") ;;
		esac
	done < <(compgen -A variable | sort)

	printf 'dvm: syncing recipes for %s:' "$DVM_NAME" >&2
	if [ "${DVM_NO_BASELINE:-0}" != "1" ]; then
		printf ' baseline' >&2
	fi
	if [ "${#DVM_RECIPES[@]}" -gt 0 ]; then
		for recipe in "${DVM_RECIPES[@]}"; do
			printf ' %s' "$recipe" >&2
		done
	fi
	printf '\n' >&2

	{
		cat <<'DVM_HOSTNAME'
# dvm hostname
if [ -n "${DVM_NAME:-}" ] && command -v hostnamectl >/dev/null 2>&1; then
	current_hostname="$(hostname 2>/dev/null || true)"
	if [ "$current_hostname" != "$DVM_NAME" ]; then
		sudo hostnamectl set-hostname "$DVM_NAME"
	fi
fi

DVM_HOSTNAME
		helper="$DVM_SHARE/recipes/_helpers.sh"
		if [ -f "$helper" ]; then
			printf '# dvm recipe helpers\n'
			cat "$helper"
		fi
		if [ "${DVM_NO_BASELINE:-0}" != "1" ]; then
			cat "$(recipe_file baseline)"
		fi
		if [ "${#DVM_RECIPES[@]}" -gt 0 ]; then
			for recipe in "${DVM_RECIPES[@]}"; do
				path="$(recipe_file "$recipe")"
				if [ "$recipe" = "cloudflared" ]; then
					emit_cloudflared_token_file "$cloudflared_token"
				fi
				if [ "$recipe" = "tailscale" ]; then
					emit_tailscale_auth_key_file "$tailscale_auth_key"
				fi
				printf '\n# dvm recipe: %s\n' "$recipe"
				cat "$path"
			done
		fi
		cat <<'DVM_PROJECT_HOOK'

# dvm project hook
dvm_code_dir="${DVM_CODE_DIR%/}"
case "$dvm_code_dir" in
	"~") dvm_code_dir="$HOME" ;;
	"~/"*) dvm_code_dir="$HOME/${dvm_code_dir#\~/}" ;;
esac
if [ -f "$dvm_code_dir/.dvm/sync.sh" ]; then
	bash "$dvm_code_dir/.dvm/sync.sh"
fi
DVM_PROJECT_HOOK
	} | limactl shell "$DVM_LIMA_NAME" env "${args[@]}" bash -s
}

emit_cloudflared_token_file() {
	local token="$1"
	[ -n "$token" ] || return 0
	cat <<'DVM_CLOUDFLARED_TOKEN_SETUP'
# dvm cloudflared token file
dvm_cloudflared_token_file="$(mktemp "${TMPDIR:-/tmp}/dvm-cloudflared-token.XXXXXX")"
chmod 600 "$dvm_cloudflared_token_file"
cat >"$dvm_cloudflared_token_file" <<'DVM_CLOUDFLARED_TOKEN'
DVM_CLOUDFLARED_TOKEN_SETUP
	printf '%s\n' "$token"
	cat <<'DVM_CLOUDFLARED_TOKEN_SETUP'
DVM_CLOUDFLARED_TOKEN
export DVM_CLOUDFLARED_TOKEN_FILE="$dvm_cloudflared_token_file"

DVM_CLOUDFLARED_TOKEN_SETUP
}

emit_tailscale_auth_key_file() {
	local key="$1"
	[ -n "$key" ] || return 0
	cat <<'DVM_TAILSCALE_AUTH_KEY_SETUP'
# dvm tailscale auth key file
dvm_tailscale_auth_key_file="$(mktemp "${TMPDIR:-/tmp}/dvm-tailscale-auth-key.XXXXXX")"
chmod 600 "$dvm_tailscale_auth_key_file"
cat >"$dvm_tailscale_auth_key_file" <<'DVM_TAILSCALE_AUTH_KEY'
DVM_TAILSCALE_AUTH_KEY_SETUP
	printf '%s\n' "$key"
	cat <<'DVM_TAILSCALE_AUTH_KEY_SETUP'
DVM_TAILSCALE_AUTH_KEY
export DVM_TAILSCALE_AUTH_KEY_FILE="$dvm_tailscale_auth_key_file"

DVM_TAILSCALE_AUTH_KEY_SETUP
}

apply_one() {
	load_vm "$1"
	ensure_vm
	run_guest_apply
}

apply_all() {
	local file name ok failed
	local -a files
	ok=0
	failed=0
	shopt -s nullglob
	files=("$DVM_CONFIG"/vms/*.sh)
	shopt -u nullglob
	[ "${#files[@]}" -gt 0 ] || die "no VM configs in $DVM_CONFIG/vms"
	for file in "${files[@]}"; do
		name="$(basename "$file" .sh)"
		if (apply_one "$name"); then
			ok=$((ok + 1))
		else
			printf 'dvm: sync failed: %s\n' "$name" >&2
			failed=$((failed + 1))
		fi
	done
	printf 'dvm sync --all: %s ok, %s failed\n' "$ok" "$failed"
	[ "$failed" -eq 0 ]
}
