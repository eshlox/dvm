#!/usr/bin/env bash
# shellcheck shell=bash

dvm_load_config() {
	# Config is intentionally shell: user-owned config can define variables and hooks.
	# shellcheck disable=SC1091
	source "$DVM_CORE/defaults/config.sh"
	if [ -f "$DVM_CONFIG/config.sh" ]; then
		# shellcheck source=/dev/null
		source "$DVM_CONFIG/config.sh"
	fi

	DVM_PREFIX="${DVM_PREFIX:-dvm}"
	DVM_TEMPLATE="${DVM_TEMPLATE:-template:fedora}"
	DVM_ARCH="${DVM_ARCH:-aarch64}"
	DVM_CPUS="${DVM_CPUS:-4}"
	DVM_MEMORY="${DVM_MEMORY:-8GiB}"
	DVM_DISK="${DVM_DISK:-80GiB}"
	DVM_GUEST_USER="${DVM_GUEST_USER:-$(id -un)}"
	DVM_GUEST_HOME="${DVM_GUEST_HOME:-/home/$DVM_GUEST_USER}"
	DVM_CODE_DIR="${DVM_CODE_DIR:-$DVM_GUEST_HOME/code}"
	DVM_PACKAGES="${DVM_PACKAGES:-git openssh-clients gpg}"
	DVM_SETUP_SCRIPTS="${DVM_SETUP_SCRIPTS:-$DVM_CONFIG/setup.d/fedora.sh}"
	DVM_SETUP_ALL_JOBS="${DVM_SETUP_ALL_JOBS:-1}"
	DVM_DOTFILES_DIR="${DVM_DOTFILES_DIR:-}"
	DVM_DOTFILES_TARGET="${DVM_DOTFILES_TARGET:-$DVM_GUEST_HOME/.dotfiles}"
	DVM_DOTFILES_EXCLUDES="${DVM_DOTFILES_EXCLUDES:-.git .ssh .gnupg .env secrets}"
	DVM_GPG_DIR="${DVM_GPG_DIR:-$DVM_STATE/gpg}"
	DVM_AI_NAME="${DVM_AI_NAME:-ai}"
	DVM_AI_PACKAGES="${DVM_AI_PACKAGES:-llama-cpp curl}"
	DVM_AI_SERVER_CMD="${DVM_AI_SERVER_CMD:-llama-server}"
	DVM_AI_SERVICE_NAME="${DVM_AI_SERVICE_NAME:-dvm-llama.service}"
	DVM_AI_SYSTEMD_DIR="${DVM_AI_SYSTEMD_DIR:-/etc/systemd/system}"
	DVM_AI_HOST="${DVM_AI_HOST:-127.0.0.1}"
	DVM_AI_PORT="${DVM_AI_PORT:-8080}"
	DVM_AI_MODELS_DIR="${DVM_AI_MODELS_DIR:-$DVM_GUEST_HOME/models}"
	DVM_AI_CURRENT_MODEL="${DVM_AI_CURRENT_MODEL:-$DVM_AI_MODELS_DIR/current.gguf}"
	DVM_AI_DEFAULT_MODEL="${DVM_AI_DEFAULT_MODEL:-qwen25-coder-7b-q4}"
	DVM_AI_MODELS="${DVM_AI_MODELS:-qwen25-coder-7b-q4=https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf?download=true}"
	DVM_AI_EXTRA_ARGS="${DVM_AI_EXTRA_ARGS:-}"
	DVM_AGENT_USER="${DVM_AGENT_USER:-dvm-agent}"
	DVM_AGENT_HOME="${DVM_AGENT_HOME:-/home/$DVM_AGENT_USER}"
	DVM_AGENT_PACKAGES="${DVM_AGENT_PACKAGES:-bubblewrap acl shadow-utils}"
	DVM_AGENT_CLAUDE_CHANNEL="${DVM_AGENT_CLAUDE_CHANNEL:-stable}"

	dvm_validate_config
}

dvm_validate_config() {
	case "$DVM_PREFIX" in
	[a-z]*)
		case "$DVM_PREFIX" in
		*[!a-z0-9-]* | *-) dvm_die "invalid DVM_PREFIX: $DVM_PREFIX" ;;
		esac
		;;
	*) dvm_die "invalid DVM_PREFIX: $DVM_PREFIX" ;;
	esac

	case "$DVM_GUEST_HOME" in
	/*) ;;
	*) dvm_die "DVM_GUEST_HOME must be an absolute path: $DVM_GUEST_HOME" ;;
	esac
	case "$DVM_CODE_DIR" in
	/*) ;;
	*) dvm_die "DVM_CODE_DIR must be an absolute path: $DVM_CODE_DIR" ;;
	esac
	case "$DVM_SETUP_ALL_JOBS" in
	'' | *[!0-9]* | 0) dvm_die "invalid DVM_SETUP_ALL_JOBS: $DVM_SETUP_ALL_JOBS" ;;
	esac
}

dvm_config_supported_vars() {
	cat <<'VARS'
DVM_PREFIX
DVM_TEMPLATE
DVM_ARCH
DVM_CPUS
DVM_MEMORY
DVM_DISK
DVM_GUEST_USER
DVM_GUEST_HOME
DVM_CODE_DIR
DVM_PACKAGES
DVM_SETUP_SCRIPTS
DVM_SETUP_ALL_JOBS
DVM_DOTFILES_DIR
DVM_DOTFILES_TARGET
DVM_DOTFILES_EXCLUDES
DVM_GPG_DIR
DVM_AI_NAME
DVM_AI_PACKAGES
DVM_AI_SERVER_CMD
DVM_AI_SERVICE_NAME
DVM_AI_SYSTEMD_DIR
DVM_AI_HOST
DVM_AI_PORT
DVM_AI_MODELS_DIR
DVM_AI_CURRENT_MODEL
DVM_AI_DEFAULT_MODEL
DVM_AI_MODELS
DVM_AI_EXTRA_ARGS
DVM_AGENT_USER
DVM_AGENT_HOME
DVM_AGENT_PACKAGES
DVM_AGENT_CLAUDE_CHANNEL
VARS
}

dvm_config_user_vars() {
	local config_file
	config_file="$1"
	[ -f "$config_file" ] || return 0
	sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}\(DVM_[A-Za-z0-9_]*\)=.*/\2/p' "$config_file" |
		sort -u
}

dvm_config_unknown_vars() {
	local config_file supported
	config_file="$1"
	supported="$(mktemp)"
	dvm_config_supported_vars | sort -u >"$supported"
	comm -23 <(dvm_config_user_vars "$config_file") "$supported"
	rm -f "$supported"
}

dvm_config_usage() {
	cat <<'HELP'
usage:
  dvm config path
  dvm config print-defaults
  dvm config print-template
  dvm config diff
HELP
}

dvm_config_template() {
	cat <<'CONFIG'
# DVM user config.
#
# This file is for local overrides only. DVM loads defaults from the core before
# sourcing this file, so it can stay mostly empty.
#
# Inspect current defaults:
#   dvm config print-defaults
#
# Compare this file with the generated override template:
#   dvm config diff

# VM defaults:
# DVM_PREFIX="dvm"
# DVM_CPUS="4"
# DVM_MEMORY="8GiB"
# DVM_DISK="80GiB"

# Packages installed by `dvm setup <name>`:
# DVM_PACKAGES="git openssh-clients gpg helix ripgrep fd-find jq"

# Optional dotfiles snapshot copied into each VM during setup:
# DVM_DOTFILES_DIR="$HOME/.dotfiles"
# DVM_DOTFILES_TARGET="$DVM_GUEST_HOME/.dotfiles"

# Run setup for multiple VMs in parallel:
# DVM_SETUP_ALL_JOBS="2"

# Local llama.cpp AI VM:
# DVM_AI_HOST="127.0.0.1"
# DVM_AI_PORT="8080"

# Hosted AI tools run as this restricted user:
# DVM_AGENT_USER="dvm-agent"
CONFIG
}

dvm_config_cmd() {
	local cmd config_file diff_rc template_file
	cmd="${1:-help}"
	[ "$#" -eq 0 ] || shift
	config_file="$DVM_CONFIG/config.sh"
	case "$cmd" in
	path)
		[ "$#" -eq 0 ] || dvm_die "usage: dvm config path"
		printf '%s\n' "$config_file"
		;;
	print-defaults | defaults)
		[ "$#" -eq 0 ] || dvm_die "usage: dvm config print-defaults"
		cat "$DVM_CORE/defaults/config.sh"
		;;
	print-template | template)
		[ "$#" -eq 0 ] || dvm_die "usage: dvm config print-template"
		dvm_config_template
		;;
	diff)
		[ "$#" -eq 0 ] || dvm_die "usage: dvm config diff"
		[ -f "$config_file" ] || dvm_die "config not found: $config_file; run dvm init"
		template_file="$(mktemp)"
		dvm_config_template >"$template_file"
		diff_rc="0"
		diff -u "$template_file" "$config_file" || diff_rc="$?"
		rm -f "$template_file"
		[ "$diff_rc" -le 1 ] || return "$diff_rc"
		;;
	help | -h | --help)
		dvm_config_usage
		;;
	*)
		dvm_config_usage
		dvm_die "unknown config command: $cmd"
		;;
	esac
}

dvm_init() {
	dvm_load_config
	mkdir -p "$DVM_CONFIG/setup.d" "$DVM_STATE" "$DVM_GPG_DIR"
	chmod 0700 "$DVM_STATE" "$DVM_GPG_DIR"

	if [ ! -f "$DVM_CONFIG/config.sh" ]; then
		dvm_config_template >"$DVM_CONFIG/config.sh"
		dvm_log "created $DVM_CONFIG/config.sh"
	fi
	if [ ! -f "$DVM_CONFIG/setup.d/fedora.sh" ]; then
		cp "$DVM_CORE/defaults/setup-fedora.sh" "$DVM_CONFIG/setup.d/fedora.sh"
		chmod 0755 "$DVM_CONFIG/setup.d/fedora.sh"
		dvm_log "created $DVM_CONFIG/setup.d/fedora.sh"
	fi
	dvm_log "config: $DVM_CONFIG"
	dvm_log "state: $DVM_STATE"
}
