#!/usr/bin/env bash
# shellcheck shell=bash

dvm_log() {
	printf '%s\n' "$*" >&2
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
	dvm_validate_name_value name "$name"
}

dvm_validate_name_value() {
	local label name
	label="$1"
	name="$2"
	case "$name" in
	[a-z]*)
		case "$name" in
		*[!a-z0-9-]* | *-) dvm_die "invalid $label: $name" ;;
		esac
		;;
	*) dvm_die "invalid $label: $name" ;;
	esac
}

dvm_validate_port_number() {
	local label number value
	label="$1"
	number="$2"
	case "$number" in
	'' | *[!0-9]*)
		dvm_die "invalid $label port: $number"
		;;
	0*)
		dvm_die "invalid $label port: $number"
		;;
	esac
	value="$number"
	if [ "${#value}" -gt 5 ] || [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
		dvm_die "invalid $label port: $number"
	fi
}

dvm_validate_ipv4() {
	local label octet rest value
	label="$1"
	value="$2"
	case "$value" in
	'' | *[!0-9.]* | *.*.*.*.* | .* | *. | *..*)
		dvm_die "invalid $label: $value"
		;;
	esac
	rest="$value"
	while :; do
		octet="${rest%%.*}"
		case "$octet" in
		'' | *[!0-9]*)
			dvm_die "invalid $label: $value"
			;;
		esac
		if [ "${#octet}" -gt 1 ]; then
			case "$octet" in
			0*) dvm_die "invalid $label: $value" ;;
			esac
		fi
		if [ "${#octet}" -gt 3 ] || [ "$octet" -gt 255 ]; then
			dvm_die "invalid $label: $value"
		fi
		case "$rest" in
		*.*) rest="${rest#*.}" ;;
		*) break ;;
		esac
	done
	case "$value" in
	*.*.*.*) ;;
	*) dvm_die "invalid $label: $value" ;;
	esac
}

dvm_validate_systemd_unit() {
	local label unit
	label="$1"
	unit="$2"
	case "$unit" in
	*.service) ;;
	*) dvm_die "$label must end with .service: $unit" ;;
	esac
	case "$unit" in
	*/* | *..* | *[!A-Za-z0-9_.@-]*) dvm_die "invalid $label: $unit" ;;
	esac
}
