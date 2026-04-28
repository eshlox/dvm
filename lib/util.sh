#!/usr/bin/env bash
# shellcheck shell=bash

dvm_log() {
	printf '%s\n' "$*"
}

dvm_warn() {
	printf 'dvm: warning: %s\n' "$*" >&2
}

dvm_die() {
	printf 'dvm: error: %s\n' "$*" >&2
	exit 1
}

dvm_command_exists() {
	command -v "$1" >/dev/null 2>&1
}

dvm_require() {
	dvm_command_exists "$1" || dvm_die "required command not found: $1"
}

dvm_quote() {
	local value
	value="${1:-}"
	printf "'%s'" "$(printf '%s' "$value" | sed "s/'/'\\\\''/g")"
}

dvm_json() {
	local value
	value="${1:-}"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	printf '"%s"' "$value"
}

dvm_validate_name() {
	local name
	name="$1"
	case "$name" in
	'' | *[!a-z0-9-]* | -*)
		dvm_die "invalid name '$name'; use lowercase letters, numbers, and hyphens"
		;;
	esac
}
