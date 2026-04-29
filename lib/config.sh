#!/usr/bin/env bash
# shellcheck shell=bash

dvm_reset_config_vars() {
	local var
	while IFS= read -r var; do
		case "$var" in
		DVM_CORE | DVM_CONFIG | DVM_STATE | DVM_TEST_*) ;;
		*) unset "$var" ;;
		esac
	done < <(compgen -v DVM_)
	unset -f dvm_vm_setup 2>/dev/null || true
}

dvm_source_defaults() {
	# Config is intentionally shell: the user owns these files.
	DVM_PREFIX="${DVM_PREFIX:-dvm}"
	DVM_TEMPLATE="${DVM_TEMPLATE:-template:fedora}"
	DVM_ARCH="${DVM_ARCH:-$(dvm_default_arch)}"
	DVM_CPUS="${DVM_CPUS:-2}"
	DVM_MEMORY="${DVM_MEMORY:-4GiB}"
	DVM_DISK="${DVM_DISK:-40GiB}"
	DVM_NETWORK="${DVM_NETWORK:-user-v2}"
	DVM_GUEST_USER="${DVM_GUEST_USER:-$(id -un)}"
	DVM_GUEST_HOME="${DVM_GUEST_HOME:-/home/$DVM_GUEST_USER}"
	DVM_CODE_DIR="${DVM_CODE_DIR:-}"
	DVM_PACKAGES="${DVM_PACKAGES:-}"
	DVM_PORTS="${DVM_PORTS:-}"
	DVM_SETUP_SCRIPTS="${DVM_SETUP_SCRIPTS:-}"
	DVM_DOTFILES_DIR="${DVM_DOTFILES_DIR:-}"
	DVM_DOTFILES_TARGET="${DVM_DOTFILES_TARGET:-}"
	DVM_DOTFILES_EXCLUDES="${DVM_DOTFILES_EXCLUDES:-.git .ssh .gnupg .env secrets .aws .docker .kube .netrc .pypirc .npmrc .config/gh .config/op}"
	DVM_VM_CONFIG_DIR="${DVM_VM_CONFIG_DIR:-$DVM_CONFIG/vms}"
	DVM_RECIPE_DIR="${DVM_RECIPE_DIR:-$DVM_CONFIG/recipes}"
	if [ -f "$DVM_CONFIG/config.sh" ]; then
		# shellcheck source=/dev/null
		source "$DVM_CONFIG/config.sh"
	fi
}

dvm_default_arch() {
	case "$(uname -m)" in
	arm64 | aarch64) printf 'aarch64\n' ;;
	x86_64 | amd64) printf 'x86_64\n' ;;
	*) uname -m ;;
	esac
}

dvm_load_defaults() {
	dvm_reset_config_vars
	dvm_source_defaults
	dvm_validate_defaults
}

dvm_validate_defaults() {
	DVM_CODE_DIR="${DVM_CODE_DIR:-$DVM_GUEST_HOME/code}"
	DVM_DOTFILES_TARGET="${DVM_DOTFILES_TARGET:-$DVM_GUEST_HOME/.dotfiles}"

	dvm_validate_name_value DVM_PREFIX "$DVM_PREFIX"
	case "$DVM_GUEST_HOME" in
	/*) ;;
	*) dvm_die "DVM_GUEST_HOME must be absolute: $DVM_GUEST_HOME" ;;
	esac
	case "$DVM_CODE_DIR" in
	/*) ;;
	*) dvm_die "DVM_CODE_DIR must be absolute: $DVM_CODE_DIR" ;;
	esac
	case "$DVM_CPUS" in
	'' | *[!0-9]* | 0) dvm_die "invalid DVM_CPUS: $DVM_CPUS" ;;
	esac
	case "$DVM_MEMORY" in
	'' | *[!0-9A-Za-z]*)
		dvm_die "invalid DVM_MEMORY: $DVM_MEMORY"
		;;
	esac
	printf '%s\n' "$DVM_MEMORY" | grep -Eq '^[0-9]+([KMGTP]i?B)?$' || dvm_die "invalid DVM_MEMORY: $DVM_MEMORY"
	case "$DVM_DISK" in
	'' | *[!0-9A-Za-z]*)
		dvm_die "invalid DVM_DISK: $DVM_DISK"
		;;
	esac
	printf '%s\n' "$DVM_DISK" | grep -Eq '^[0-9]+([KMGTP]i?B)?$' || dvm_die "invalid DVM_DISK: $DVM_DISK"
	case "$DVM_NETWORK" in
	user-v2 | vzNAT) ;;
	*) dvm_die "invalid DVM_NETWORK: $DVM_NETWORK" ;;
	esac
}

dvm_vm_config_path() {
	local name
	name="$1"
	printf '%s/%s.sh\n' "$DVM_VM_CONFIG_DIR" "$name"
}

dvm_load_vm_config() {
	local config_file name
	name="$1"
	dvm_reset_config_vars
	dvm_source_defaults
	DVM_NAME="$name"
	config_file="$(dvm_vm_config_path "$name")"
	if [ -f "$config_file" ]; then
		# shellcheck source=/dev/null
		source "$config_file"
	fi
	dvm_validate_defaults
	# Exposed to recipes and inline setup via dvm_build_env_args.
	# shellcheck disable=SC2034
	DVM_NAME="$name"
	# shellcheck disable=SC2034
	DVM_VM_NAME="$(dvm_vm_name "$name")"
}

dvm_global_config_template() {
	cat <<'CONFIG'
# DVM global defaults.
# This file is sourced before every per-VM config in vms/<name>.sh.

# Core VM defaults:
# DVM_PREFIX="dvm"
# DVM_CPUS="2"
# DVM_MEMORY="4GiB"
# DVM_DISK="40GiB"
# DVM_NETWORK="user-v2"

# Defaults for most development VMs:
# DVM_PACKAGES="git ripgrep fd-find jq helix yazi"
# DVM_DOTFILES_DIR="$HOME/.dotfiles"
# DVM_SETUP_SCRIPTS="common.sh"

# Put shared recipes in:
#   ~/.config/dvm/recipes/common.sh
# Use recipes for tools that need extra repos or custom commands, like lazygit from Terra.
#
# Per-VM configs can append to these values:
#   DVM_PACKAGES="$DVM_PACKAGES nodejs pnpm"
#
# Or disable them for special VMs:
#   DVM_PACKAGES=""
#   DVM_DOTFILES_DIR=""
#   DVM_SETUP_SCRIPTS=""
CONFIG
}

dvm_vm_config_template() {
	local name
	name="$1"
	cat <<CONFIG
# DVM config for "$name".
# This file is shell sourced on the host before create/setup.

# Inherited defaults:
# This VM inherits ~/.config/dvm/config.sh first. Override, append, or clear values here.

# VM size/template:
# DVM_TEMPLATE="template:fedora"
# DVM_CPUS="2"
# DVM_MEMORY="4GiB"
# DVM_DISK="40GiB"
# DVM_NETWORK="user-v2"

# Add packages to the global default package list:
# DVM_PACKAGES="\$DVM_PACKAGES nodejs pnpm"

# Or replace/disable global default packages:
# DVM_PACKAGES="git ripgrep jq"
# DVM_PACKAGES=""

# Host localhost forwards, written as host:guest pairs.
# DVM_PORTS="3000:3000 5173:5173"

# Dotfiles:
# Inherit DVM_DOTFILES_DIR from global config, override it, or disable it:
# DVM_DOTFILES_DIR="\$HOME/.dotfiles"
# DVM_DOTFILES_DIR=""

# Setup scripts:
# Names are resolved from \$DVM_RECIPE_DIR, then \$DVM_CORE/recipes, then as paths.
# Append to global setup:
# DVM_SETUP_SCRIPTS="\$DVM_SETUP_SCRIPTS my-setup.sh"
# Replace or disable global setup:
# DVM_SETUP_SCRIPTS="my-setup.sh"
# DVM_SETUP_SCRIPTS=""

# Inline setup. Uncomment to run commands inside the VM as the guest user.
# dvm_vm_setup() {
# 	sudo dnf5 install -y nodejs pnpm
# }
CONFIG

	case "$name" in
	ai)
		cat <<'CONFIG'

# Llama VM example:
# Usually disable normal dev defaults for a dedicated AI VM.
# DVM_PACKAGES=""
# DVM_DOTFILES_DIR=""
# DVM_SETUP_SCRIPTS="llama.sh"
# DVM_PORTS="8080:8080"
# DVM_LLAMA_HOST="0.0.0.0"
# DVM_LLAMA_MODELS="qwen=https://example.com/model.gguf"
# DVM_LLAMA_DEFAULT_MODEL="qwen"
CONFIG
		;;
	cloudflared)
		cat <<'CONFIG'

# cloudflared VM example:
# Usually disable normal dev defaults for a dedicated connector VM.
# DVM_CPUS="1"
# DVM_MEMORY="1GiB"
# DVM_DISK="10GiB"
# DVM_PACKAGES=""
# DVM_DOTFILES_DIR=""
# DVM_SETUP_SCRIPTS="cloudflared.sh"
# DVM_CLOUDFLARED_TOKEN="${CLOUDFLARED_TOKEN:-}"
CONFIG
		;;
	esac
}

dvm_open_editor() {
	local file editor
	file="$1"
	editor="${VISUAL:-${EDITOR:-}}"
	if [ -n "$editor" ] && [ -t 0 ] && [ -t 1 ]; then
		"$editor" "$file"
	else
		dvm_log "config: $file"
	fi
}

dvm_init() {
	local config_file name
	dvm_load_defaults
	mkdir -p "$DVM_CONFIG" "$DVM_STATE" "$DVM_VM_CONFIG_DIR" "$DVM_RECIPE_DIR"
	chmod 0700 "$DVM_STATE"

	if [ ! -f "$DVM_CONFIG/config.sh" ]; then
		dvm_global_config_template >"$DVM_CONFIG/config.sh"
		dvm_log "created $DVM_CONFIG/config.sh"
	fi

	if [ "$#" -eq 0 ]; then
		dvm_log "config: $DVM_CONFIG"
		return 0
	fi
	[ "$#" -eq 1 ] || dvm_die "usage: dvm init [name]"
	name="$1"
	dvm_validate_name "$name"
	config_file="$(dvm_vm_config_path "$name")"
	if [ ! -f "$config_file" ]; then
		dvm_vm_config_template "$name" >"$config_file"
		dvm_log "created $config_file"
	fi
	dvm_open_editor "$config_file"
}

dvm_edit() {
	local config_file name
	[ "$#" -eq 1 ] || dvm_die "usage: dvm edit <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_defaults
	config_file="$(dvm_vm_config_path "$name")"
	[ -f "$config_file" ] || dvm_die "VM config not found: $config_file; run dvm init $name"
	dvm_open_editor "$config_file"
}
