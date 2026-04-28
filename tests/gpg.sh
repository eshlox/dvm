#!/usr/bin/env bash
set -euo pipefail

command -v gpg >/dev/null 2>&1 || {
	echo "skipping GPG test; gpg not found"
	exit 0
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export GNUPGHOME="$TMP/gnupg"
export DVM_CONFIG="$TMP/config"
export DVM_STATE="$TMP/state"
export DVM_GPG_BATCH="1"
mkdir -p "$HOME" "$GNUPGHOME"
chmod 0700 "$GNUPGHOME"

gpg --batch --pinentry-mode loopback --passphrase '' \
	--quick-generate-key "DVM Test <dvm-test@example.invalid>" ed25519 cert 1d >/dev/null 2>"$TMP/gpg-generate.err"

primary="$(
	gpg --with-colons --fingerprint --list-secret-keys "dvm-test@example.invalid" 2>/dev/null |
		awk -F: '$1 == "fpr" { print $10; exit }'
)"
[ -n "$primary" ]

"$ROOT/bin/dvm" init >/dev/null 2>&1
"$ROOT/bin/dvm" gpg create app "$primary" --expire 1d >"$TMP/create.out" 2>"$TMP/create.err"
grep -Fq 'created signing subkey:' "$TMP/create.err"

# shellcheck source=/dev/null
source "$DVM_STATE/gpg/app.env"
[ -s "$PUBLIC_FILE" ]
[ -s "$SECRET_FILE" ]
[ -n "$SUBKEY_FPR" ]
secret_file="$SECRET_FILE"

"$ROOT/bin/dvm" gpg forget app >"$TMP/forget.out" 2>"$TMP/forget.err"
[ ! -e "$secret_file" ]
grep -Fq "forgot secret subkey bundle: $secret_file" "$TMP/forget.err"
if grep -Fq 'SECRET_FILE=' "$DVM_STATE/gpg/app.env"; then
	echo "GPG metadata still records deleted secret file" >&2
	exit 1
fi

"$ROOT/bin/dvm" gpg revoke app >"$TMP/revoke.out" 2>"$TMP/revoke.err"
grep -Fq "revoked subkey: $SUBKEY_FPR" "$TMP/revoke.err"
