#!/usr/bin/env bash
# shellcheck shell=bash

dvm_gpg_primary_fpr() {
	local key output fpr
	key="$1"
	output="$(gpg --with-colons --fingerprint --list-secret-keys "$key" 2>&1)" ||
		dvm_die "failed to inspect GPG secret key '$key': $output"
	fpr="$(printf '%s\n' "$output" | awk -F: '$1 == "fpr" { print $10; exit }')"
	[ -n "$fpr" ] || dvm_die "secret primary key not found: $key"
	printf '%s\n' "$fpr"
}

dvm_gpg_secret_subkeys() {
	local key
	key="$1"
	gpg --with-colons --with-subkey-fingerprint --list-secret-keys ${key:+"$key"} |
		awk -F: '
			$1 == "ssb" {
				want = 1
				next
			}
			$1 == "fpr" && want {
				print $10
				want = 0
				next
			}
			$1 != "fpr" {
				want = 0
			}
		'
}

dvm_gpg_subkey_index() {
	local primary subkey
	primary="$1"
	subkey="$2"
	gpg --with-colons --with-subkey-fingerprint --list-secret-keys "$primary" |
		awk -F: -v want_fpr="$subkey" '
			$1 == "ssb" {
				idx += 1
				want = idx
				next
			}
			$1 == "fpr" && want && $10 == want_fpr {
				print want
				exit
			}
			$1 == "fpr" {
				want = 0
			}
		'
}

dvm_gpg_create() {
	local name primary expire output_dir force primary_fpr status_output subkey_fpr public_file secret_file meta_file
	local -a add_key_args
	[ "$#" -ge 2 ] || dvm_die "usage: dvm gpg create <vm-name> <primary-key> [--expire 1y] [--output dir] [--force]"
	name="$1"
	primary="$2"
	shift 2
	expire="1y"
	output_dir=""
	force="0"

	while [ "$#" -gt 0 ]; do
		case "$1" in
		--expire)
			[ "$#" -gt 1 ] || dvm_die "--expire requires a value"
			expire="$2"
			shift
			;;
		--output)
			[ "$#" -gt 1 ] || dvm_die "--output requires a value"
			output_dir="$2"
			shift
			;;
		--force) force="1" ;;
		*) dvm_die "unknown gpg create option: $1" ;;
		esac
		shift
	done

	dvm_validate_name "$name"
	dvm_load_config
	dvm_require gpg
	output_dir="${output_dir:-$DVM_GPG_DIR}"
	mkdir -p "$output_dir"
	chmod 0700 "$output_dir"
	public_file="$output_dir/$name-public.asc"
	secret_file="$output_dir/$name-secret-subkey.asc"
	meta_file="$output_dir/$name.env"
	if [ "$force" != "1" ]; then
		[ ! -e "$public_file" ] || dvm_die "file exists: $public_file"
		[ ! -e "$secret_file" ] || dvm_die "file exists: $secret_file"
	fi

	primary_fpr="$(dvm_gpg_primary_fpr "$primary")"
	add_key_args=()
	if [ "${DVM_GPG_BATCH:-0}" = "1" ]; then
		add_key_args+=(--batch --pinentry-mode loopback --passphrase '')
	fi
	status_output="$(
		gpg "${add_key_args[@]}" --status-fd 1 --quick-add-key "$primary_fpr" default sign "$expire" 2>&1
	)" || dvm_die "failed to create GPG signing subkey: $status_output"
	subkey_fpr="$(
		printf '%s\n' "$status_output" |
			awk '$1 == "[GNUPG:]" && $2 == "KEY_CREATED" && $3 == "S" { print $4; exit }'
	)"
	[ -n "$subkey_fpr" ] || dvm_die "could not detect newly created signing subkey"

	gpg --armor --export "$primary_fpr" >"$public_file"
	gpg --armor --export-secret-subkeys "${subkey_fpr}!" >"$secret_file"
	chmod 0644 "$public_file"
	chmod 0600 "$secret_file"
	{
		printf 'PRIMARY_FPR=%s\n' "$(dvm_quote "$primary_fpr")"
		printf 'SUBKEY_FPR=%s\n' "$(dvm_quote "$subkey_fpr")"
		printf 'PUBLIC_FILE=%s\n' "$(dvm_quote "$public_file")"
		printf 'SECRET_FILE=%s\n' "$(dvm_quote "$secret_file")"
	} >"$meta_file"
	chmod 0600 "$meta_file"

	dvm_log "created signing subkey: $subkey_fpr"
	dvm_log "public key export: $public_file"
	dvm_log "secret subkey bundle: $secret_file"
	dvm_log "install with: dvm gpg install $name"
}

dvm_gpg_remove_secret_record() {
	local meta_file tmp
	meta_file="$1"
	[ -f "$meta_file" ] || return 0
	tmp="$(mktemp)"
	grep -v '^SECRET_FILE=' "$meta_file" >"$tmp" || true
	mv "$tmp" "$meta_file"
	chmod 0600 "$meta_file"
}

dvm_gpg_forget_secret_file() {
	local meta_file secret_file
	meta_file="$1"
	secret_file="$2"
	[ -n "$secret_file" ] || {
		dvm_warn "no recorded secret subkey bundle"
		return 0
	}
	case "$secret_file" in
	"$DVM_GPG_DIR"/*) ;;
	*)
		dvm_warn "not deleting secret bundle outside DVM_GPG_DIR: $secret_file"
		return 0
		;;
	esac
	rm -f "$secret_file"
	dvm_gpg_remove_secret_record "$meta_file"
	dvm_log "forgot secret subkey bundle: $secret_file"
}

dvm_gpg_bundle_fpr() (
	local bundle tmp fprs count
	bundle="$1"
	tmp="$(mktemp -d)"
	chmod 0700 "$tmp"
	trap 'rm -rf "$tmp"' EXIT
	GNUPGHOME="$tmp" gpg --batch --quiet --import "$bundle" >/dev/null 2>&1 ||
		dvm_die "could not inspect GPG bundle: $bundle"
	fprs="$(GNUPGHOME="$tmp" dvm_gpg_secret_subkeys "")"
	count="$(printf '%s\n' "$fprs" | sed '/^$/d' | wc -l | tr -d ' ')"
	case "$count" in
	1) printf '%s\n' "$fprs" ;;
	0) dvm_die "no secret subkey found in bundle: $bundle" ;;
	*) dvm_die "multiple secret subkeys found; pass --signing-key" ;;
	esac
)

dvm_gpg_install_remote() {
	cat <<'REMOTE'
set -euo pipefail
signing_key="${1%!}"
umask 077
mkdir -p "$HOME/.gnupg"
chmod 0700 "$HOME/.gnupg"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat >"$tmp"
gpg --batch --import "$tmp"
git config --global gpg.program gpg
git config --global user.signingkey "${signing_key}!"
git config --global commit.gpgsign true
for profile in "$HOME/.profile" "$HOME/.bashrc"; do
	touch "$profile"
	if ! grep -Fq "# BEGIN DVM GPG" "$profile"; then
		cat >>"$profile" <<'PROFILE'
# BEGIN DVM GPG
if command -v tty >/dev/null 2>&1; then
	GPG_TTY="$(tty 2>/dev/null || true)"
	export GPG_TTY
fi
if command -v gpg-connect-agent >/dev/null 2>&1; then
	gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
fi
# END DVM GPG
PROFILE
	fi
done
printf "configured git commit signing with GPG subkey %s\n" "$signing_key"
REMOTE
}

dvm_gpg_install() {
	local keep_secret meta_file name recorded_secret_file remote secret_file signing_key vm
	[ "$#" -ge 1 ] || dvm_die "usage: dvm gpg install <vm-name> [secret-subkey.asc] [--signing-key fpr] [--keep-secret]"
	name="$1"
	shift
	dvm_validate_name "$name"
	dvm_load_config
	keep_secret="0"
	secret_file=""
	signing_key=""
	recorded_secret_file=""
	meta_file="$DVM_GPG_DIR/$name.env"
	if [ -f "$meta_file" ]; then
		# shellcheck source=/dev/null
		source "$meta_file"
		recorded_secret_file="${SECRET_FILE:-}"
		secret_file="$recorded_secret_file"
		signing_key="${SUBKEY_FPR:-}"
	fi
	if [ "$#" -gt 0 ]; then
		case "${1:-}" in
		--*) ;;
		*)
			secret_file="$1"
			shift
			;;
		esac
	fi
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--signing-key)
			[ "$#" -gt 1 ] || dvm_die "--signing-key requires a value"
			signing_key="${2%!}"
			shift
			;;
		--keep-secret) keep_secret="1" ;;
		*) dvm_die "unknown gpg install option: $1" ;;
		esac
		shift
	done
	[ -n "$secret_file" ] || dvm_die "missing secret subkey bundle"
	[ -f "$secret_file" ] || dvm_die "secret subkey bundle not found: $secret_file"
	dvm_require gpg
	dvm_require limactl
	if [ -z "$signing_key" ]; then
		signing_key="$(dvm_gpg_bundle_fpr "$secret_file")"
	fi
	vm="$(dvm_vm_name "$name")"
	remote="$(dvm_gpg_install_remote)"
	limactl start "$vm"
	limactl shell "$vm" bash -c "$remote" dvm-gpg-install "$signing_key" <"$secret_file"
	if [ "$keep_secret" != "1" ] &&
		[ -n "$recorded_secret_file" ] &&
		[ "$secret_file" = "$recorded_secret_file" ]; then
		dvm_gpg_forget_secret_file "$meta_file" "$secret_file"
	fi
}

dvm_gpg_forget() {
	local meta_file name secret_file
	[ "$#" -eq 1 ] || dvm_die "usage: dvm gpg forget <vm-name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_config
	meta_file="$DVM_GPG_DIR/$name.env"
	[ -f "$meta_file" ] || dvm_die "missing GPG metadata: $meta_file"
	secret_file=""
	# shellcheck source=/dev/null
	source "$meta_file"
	secret_file="${SECRET_FILE:-}"
	dvm_gpg_forget_secret_file "$meta_file" "$secret_file"
}

dvm_gpg_revoke() {
	local name meta_file primary_fpr subkey_fpr index public_file
	local -a edit_args
	[ "$#" -eq 1 ] || dvm_die "usage: dvm gpg revoke <vm-name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_config
	dvm_require gpg
	meta_file="$DVM_GPG_DIR/$name.env"
	[ -f "$meta_file" ] || dvm_die "missing GPG metadata: $meta_file"
	# shellcheck source=/dev/null
	source "$meta_file"
	primary_fpr="${PRIMARY_FPR:-}"
	subkey_fpr="${SUBKEY_FPR:-}"
	public_file="${PUBLIC_FILE:-$DVM_GPG_DIR/$name-public-revoked.asc}"
	if [ -z "$primary_fpr" ] || [ -z "$subkey_fpr" ]; then
		dvm_die "metadata is missing PRIMARY_FPR or SUBKEY_FPR"
	fi
	index="$(dvm_gpg_subkey_index "$primary_fpr" "$subkey_fpr")"
	[ -n "$index" ] || dvm_die "could not find subkey $subkey_fpr under $primary_fpr"

	edit_args=(--command-fd 0 --status-fd 2)
	if [ "${DVM_GPG_BATCH:-0}" = "1" ]; then
		edit_args+=(--batch --yes --pinentry-mode loopback)
	fi
	printf 'key %s\nrevkey\ny\n0\n\ny\nsave\n' "$index" |
		gpg "${edit_args[@]}" --edit-key "$primary_fpr"
	gpg --armor --export "$primary_fpr" >"$public_file"
	chmod 0644 "$public_file"
	dvm_log "revoked subkey: $subkey_fpr"
	dvm_log "updated public key export: $public_file"
}

dvm_gpg_cmd() {
	local subcmd
	subcmd="${1:-help}"
	[ "$#" -eq 0 ] || shift
	case "$subcmd" in
	create) dvm_gpg_create "$@" ;;
	install) dvm_gpg_install "$@" ;;
	forget) dvm_gpg_forget "$@" ;;
	revoke) dvm_gpg_revoke "$@" ;;
	*)
		cat <<'HELP'
usage:
  dvm gpg create <vm-name> <primary-key> [--expire 1y]
  dvm gpg install <vm-name> [secret-subkey.asc] [--signing-key fpr] [--keep-secret]
  dvm gpg forget <vm-name>
  dvm gpg revoke <vm-name>
HELP
		;;
	esac
}
