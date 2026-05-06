# shellcheck shell=bash

usage() {
	cat <<'HELP'
usage:
  dvm init <name> [template]
  dvm sync <name>
  dvm sync --all
  dvm sh <name>
  dvm ssh <name> -- <command...>
  dvm cp [-r] [-v] [--backend auto|scp|rsync] <source...> <target>
  dvm log <name> [unit] [journalctl-args...]
  dvm ssh-key <name>
  dvm gpg-key <name>
  dvm ls
  dvm stop <name>
  dvm rm <name> --yes [--force]
HELP
}

die() {
	printf 'dvm: error: %s\n' "$*" >&2
	exit 1
}

safe_name() {
	case "${1:-}" in
	'' | *[!a-z0-9-]* | -*) return 1 ;;
	[a-z]*) return 0 ;;
	*) return 1 ;;
	esac
}

public_vm_name() {
	local name="$1"
	case "$name" in
	dvm-*) name="${name#dvm-}" ;;
	esac
	safe_name "$name" || die "unsafe VM name: $1"
	printf '%s\n' "$name"
}

guest_term() {
	case "${TERM:-}" in
	'' | xterm-ghostty | ghostty) printf '%s\n' xterm-256color ;;
	*) printf '%s\n' "$TERM" ;;
	esac
}

validate_identifier() {
	local label="$1"
	local value="$2"
	case "$value" in
	'' | [.-]* | *[!A-Za-z0-9._-]*) die "invalid $label: $value" ;;
	esac
}

validate_lima_name() {
	case "$1" in
	'' | *[!a-z0-9-]* | -*) die "invalid DVM_LIMA_NAME: $1" ;;
	esac
}

validate_positive_int() {
	local label="$1"
	local value="$2"
	case "$value" in
	'' | *[!0-9]*) die "invalid $label: $value" ;;
	esac
	[ "$value" -gt 0 ] || die "invalid $label: $value"
}

validate_lima_size() {
	local label="$1"
	local value="$2"
	case "$value" in
	'' | [!0-9]* | *[!A-Za-z0-9._+-]*) die "invalid $label: $value" ;;
	esac
}

validate_guest_path() {
	local label="$1"
	local value="$2"
	local newline carriage
	newline=$'\n'
	carriage=$'\r'
	case "$value" in
	'' | *"$newline"* | *"$carriage"* | *'"'* | *'`'* | *\\* | *'$'*) die "invalid $label: $value" ;;
	esac
}

validate_cloudflared_token() {
	case "$1" in
	*[!A-Za-z0-9._=-]*) die "invalid cloudflared token characters" ;;
	esac
}

dvm_endpoint_name() {
	local name="$1"
	case "$name" in
	dvm-*) name="${name#dvm-}" ;;
	esac
	safe_name "$name" || return 1
	printf '%s\n' "$name"
}

open_editor() {
	local file="$1"
	local editor="${EDITOR:-${VISUAL:-vi}}"
	[ -n "$editor" ] || editor="vi"
	# shellcheck disable=SC2086
	$editor "$file"
}

host_max_cpus() {
	if command -v nproc >/dev/null 2>&1; then
		nproc 2>/dev/null && return 0
	fi
	if command -v sysctl >/dev/null 2>&1; then
		sysctl -n hw.ncpu 2>/dev/null && return 0
	fi
	printf '?\n'
}

host_max_memory() {
	local kb bytes
	if [ -r /proc/meminfo ]; then
		kb="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)"
		if [ -n "$kb" ]; then
			printf '%dGiB\n' "$((kb / 1024 / 1024))"
			return 0
		fi
	fi
	if command -v sysctl >/dev/null 2>&1; then
		bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"
		if [ -n "$bytes" ]; then
			printf '%dGiB\n' "$((bytes / 1024 / 1024 / 1024))"
			return 0
		fi
	fi
	printf '?\n'
}

render_vm_template() {
	local src="$1" dst="$2"
	local max_cpus max_memory line
	max_cpus="$(host_max_cpus)"
	max_memory="$(host_max_memory)"
	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
		*__DVM_HOST_MAX_CPUS__*) line="${line//__DVM_HOST_MAX_CPUS__/$max_cpus}" ;;
		esac
		case "$line" in
		*__DVM_HOST_MAX_MEMORY__*) line="${line//__DVM_HOST_MAX_MEMORY__/$max_memory}" ;;
		esac
		printf '%s\n' "$line"
	done <"$src" >"$dst"
}

init_vm() {
	local name template src dst
	name="${1:-}"
	[ -n "$name" ] || die "init requires a VM name"
	template="${2:-app}"
	name="$(public_vm_name "$name")"
	safe_name "$template" || die "unsafe template name: $template"
	src="$DVM_SHARE/vms/$template.sh"
	[ -f "$src" ] || die "missing VM template: $template"
	dst="$DVM_CONFIG/vms/$name.sh"
	if [ -e "$dst" ]; then
		printf 'dvm: VM config already exists: %s\n' "$dst" >&2
	else
		mkdir -p "$(dirname "$dst")"
		render_vm_template "$src" "$dst"
		printf 'dvm: created VM config: %s\n' "$dst"
	fi
	open_editor "$dst"
}

recipe_file() {
	local name="$1"
	local path
	path="$DVM_CONFIG/recipes/$name.sh"
	if [ -f "$path" ]; then
		printf '%s\n' "$path"
		return 0
	fi
	path="$DVM_SHARE/recipes/$name.sh"
	if [ -f "$path" ]; then
		printf '%s\n' "$path"
		return 0
	fi
	die "no recipe: $name"
}

use() {
	local name="${1:-}"
	[ -n "$name" ] || die "use requires a recipe name"
	recipe_file "$name" >/dev/null
	DVM_RECIPES+=("$name")
}

uses_recipe() {
	local recipe
	for recipe in "${DVM_RECIPES[@]}"; do
		[ "$recipe" = "$1" ] && return 0
	done
	return 1
}

load_vm() {
	local name="$1"
	local vm_file
	name="$(public_vm_name "$name")"

	reset_vm_vars

	# shellcheck source=/dev/null
	[ -f "$DVM_SHARE/config.sh" ] && source "$DVM_SHARE/config.sh"
	# shellcheck source=/dev/null
	[ -f "$DVM_CONFIG/config.sh" ] && source "$DVM_CONFIG/config.sh"

	# shellcheck disable=SC2034
	DVM_NAME="$name"
	DVM_LIMA_NAME="${DVM_LIMA_NAME:-dvm-$name}"
	DVM_CODE_ROOT="${DVM_CODE_ROOT:-~/code}"
	DVM_CODE_DIR="${DVM_CODE_DIR:-${DVM_CODE_ROOT%/}/$name}"
	DVM_PORTS="${DVM_PORTS:-}"
	DVM_ARCH="${DVM_ARCH:-default}"
	DVM_AI_AGENT_USER="${DVM_AI_AGENT_USER:-dvm-agent}"

	vm_file="$DVM_CONFIG/vms/$name.sh"
	[ -f "$vm_file" ] || die "missing VM config: $vm_file"
	# shellcheck source=/dev/null
	source "$vm_file"

	DVM_CODE_DIR="${DVM_CODE_DIR:-${DVM_CODE_ROOT%/}/$name}"
	DVM_PORTS="${DVM_PORTS:-}"
	DVM_CPUS="${DVM_CPUS:-2}"
	DVM_MEMORY="${DVM_MEMORY:-2GiB}"
	DVM_DISK="${DVM_DISK:-10GiB}"
	DVM_USER="${DVM_USER:-${USER:-developer}}"
	DVM_HOST_IP="${DVM_HOST_IP:-127.0.0.1}"
	DVM_LLAMA_SERVICE="${DVM_LLAMA_SERVICE:-dvm-llama.service}"
	DVM_CLOUDFLARED_SERVICE="${DVM_CLOUDFLARED_SERVICE:-dvm-cloudflared.service}"
	resolve_arch
	validate_vm_config
}

reset_vm_vars() {
	local var
	while IFS= read -r var; do
		case "$var" in
		DVM_ROOT | DVM_SHARE | DVM_CONFIG | DVM_FAKE_STATE) ;;
		DVM_*) unset "$var" || true ;;
		esac
	done < <(compgen -A variable)
	DVM_RECIPES=()
}

resolve_arch() {
	if [ "${DVM_ARCH:-default}" != "default" ]; then
		return 0
	fi
	case "$(uname -m)" in
	arm64 | aarch64) DVM_ARCH="aarch64" ;;
	x86_64 | amd64) DVM_ARCH="x86_64" ;;
	*) die "cannot resolve DVM_ARCH=default for $(uname -m)" ;;
	esac
}

validate_vm_config() {
	local item
	validate_lima_name "$DVM_LIMA_NAME"
	validate_identifier DVM_USER "$DVM_USER"
	validate_identifier DVM_AI_AGENT_USER "$DVM_AI_AGENT_USER"
	case "$DVM_ARCH" in
	aarch64 | x86_64) ;;
	*) die "invalid DVM_ARCH: $DVM_ARCH" ;;
	esac
	validate_positive_int DVM_CPUS "$DVM_CPUS"
	validate_lima_size DVM_MEMORY "$DVM_MEMORY"
	validate_lima_size DVM_DISK "$DVM_DISK"
	validate_guest_path DVM_CODE_DIR "$DVM_CODE_DIR"
	validate_host_ip "$DVM_HOST_IP"
	for item in ${DVM_PORTS:-}; do
		normalize_port "$item" >/dev/null
	done
}
