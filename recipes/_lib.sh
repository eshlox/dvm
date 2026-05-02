#!/usr/bin/env bash
# shellcheck shell=bash

dvm_recipe_log() {
	printf '%s\n' "$*" >&2
}

dvm_recipe_warn() {
	printf 'dvm recipe: warning: %s\n' "$*" >&2
}

dvm_recipe_die() {
	printf 'dvm recipe: error: %s\n' "$*" >&2
	exit 1
}

dvm_recipe_quote() {
	printf '%q' "$1"
}

dvm_recipe_array_literal() {
	local item
	for item in "$@"; do
		printf ' %q' "$item"
	done
}

dvm_recipe_validate_service() {
	local label service
	label="$1"
	service="$2"
	case "$service" in
	*.service) ;;
	*) dvm_recipe_die "$label must end with .service: $service" ;;
	esac
	case "$service" in
	*/* | *..* | *[!A-Za-z0-9_.@-]*) dvm_recipe_die "invalid $label: $service" ;;
	esac
}

dvm_recipe_validate_port() {
	local label port
	label="$1"
	port="$2"
	case "$port" in
	'' | *[!0-9]* | 0*) dvm_recipe_die "invalid $label: $port" ;;
	esac
	if [ "${#port}" -gt 5 ] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
		dvm_recipe_die "invalid $label: $port"
	fi
}

dvm_recipe_validate_bool() {
	local label value
	label="$1"
	value="$2"
	case "$value" in
	0 | 1 | true | false) ;;
	*) dvm_recipe_die "invalid $label: $value" ;;
	esac
}

dvm_recipe_validate_https_url() {
	local label url
	label="$1"
	url="$2"
	case "$url" in
	https://*) ;;
	*) dvm_recipe_die "$label must use https://: $url" ;;
	esac
	case "$url" in
	*' '* | *$'\n'* | *$'\r'*) dvm_recipe_die "invalid $label: $url" ;;
	esac
}

dvm_recipe_validate_sha256() {
	local label value
	label="$1"
	value="$2"
	case "$value" in
	????????????????????????????????????????????????????????????????) ;;
	*) dvm_recipe_die "$label must be a 64-character sha256 hex digest" ;;
	esac
	case "$value" in
	*[!A-Fa-f0-9]*) dvm_recipe_die "$label must be a 64-character sha256 hex digest" ;;
	esac
}

dvm_recipe_record_ssh_host() {
	local host known_hosts
	host="$1"
	case "$host" in
	'' | *[!A-Za-z0-9_.-]*) dvm_recipe_die "invalid SSH host: $host" ;;
	esac
	command -v ssh-keygen >/dev/null 2>&1 || dvm_recipe_die "ssh-keygen is required"
	command -v ssh-keyscan >/dev/null 2>&1 || dvm_recipe_die "ssh-keyscan is required"
	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"
	known_hosts="$HOME/.ssh/known_hosts"
	touch "$known_hosts"
	chmod 600 "$known_hosts"
	if ! ssh-keygen -F "$host" -f "$known_hosts" >/dev/null 2>&1; then
		ssh-keyscan "$host" >>"$known_hosts" 2>/dev/null ||
			dvm_recipe_die "could not scan SSH host key: $host"
	fi
}

dvm_recipe_sha256_file() {
	local file
	file="$1"
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$file" | awk '{ print $1 }'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$file" | awk '{ print $1 }'
	else
		dvm_recipe_die "sha256sum or shasum is required"
	fi
}
