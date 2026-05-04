#!/usr/bin/env bash
set -euo pipefail

: "${DVM_CHEZMOI_REPO:?DVM_CHEZMOI_REPO is required for recipe chezmoi}"

sudo dnf5 install -y chezmoi git

dvm_chezmoi_toml_string() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//$'\n'/\\n}"
	value="${value//$'\r'/\\r}"
	value="${value//$'\t'/\\t}"
	printf '"%s"' "$value"
}

dvm_chezmoi_has_data() {
	[ -n "${DVM_CHEZMOI_ROLE:-}" ] ||
		[ -n "${DVM_CHEZMOI_NAME:-}" ] ||
		[ -n "${DVM_CHEZMOI_EMAIL:-}" ] ||
		[ -n "${DVM_CHEZMOI_SIGNING_KEY:-}" ] ||
		[ -n "${DVM_CHEZMOI_DEPLOY_KEY:-}" ]
}

dvm_chezmoi_write_data_config() {
	local deploy_key signing_key
	signing_key="${DVM_CHEZMOI_SIGNING_KEY:-~/.ssh/id_ed25519_dvm_signing.pub}"
	deploy_key="${DVM_CHEZMOI_DEPLOY_KEY:-~/.ssh/id_ed25519_dvm.pub}"

	printf '[data]\n'
	[ -z "${DVM_CHEZMOI_ROLE:-}" ] || printf 'role = %s\n' "$(dvm_chezmoi_toml_string "$DVM_CHEZMOI_ROLE")"
	[ -z "${DVM_CHEZMOI_NAME:-}" ] || printf 'name = %s\n' "$(dvm_chezmoi_toml_string "$DVM_CHEZMOI_NAME")"
	[ -z "${DVM_CHEZMOI_EMAIL:-}" ] || printf 'email = %s\n' "$(dvm_chezmoi_toml_string "$DVM_CHEZMOI_EMAIL")"
	printf 'signingKey = %s\n' "$(dvm_chezmoi_toml_string "$signing_key")"
	printf 'deployKey = %s\n' "$(dvm_chezmoi_toml_string "$deploy_key")"
}

if [ -n "${DVM_CHEZMOI_CONFIG_TOML:-}" ] || dvm_chezmoi_has_data; then
	mkdir -p "$HOME/.config/chezmoi"
	config="$HOME/.config/chezmoi/chezmoi.toml"
	tmp="$(mktemp "${config}.XXXXXX")"
	if (
		umask 077
		if [ -n "${DVM_CHEZMOI_CONFIG_TOML:-}" ]; then
			printf '%s\n' "$DVM_CHEZMOI_CONFIG_TOML"
		else
			dvm_chezmoi_write_data_config
		fi >"$tmp"
	) && chmod 600 "$tmp" && mv "$tmp" "$config"; then
		:
	else
		rm -f "$tmp"
		exit 1
	fi
fi

if [ ! -d "$HOME/.local/share/chezmoi/.git" ]; then
	rm -rf "$HOME/.local/share/chezmoi"
	chezmoi init "$DVM_CHEZMOI_REPO"
else
	chezmoi git -- pull --ff-only
fi

chezmoi apply
