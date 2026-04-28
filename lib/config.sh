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
	DVM_DOTFILES_DIR="${DVM_DOTFILES_DIR:-}"
	DVM_DOTFILES_TARGET="${DVM_DOTFILES_TARGET:-$DVM_GUEST_HOME/.dotfiles}"
	DVM_DOTFILES_EXCLUDES="${DVM_DOTFILES_EXCLUDES:-.git .ssh .gnupg .env secrets}"
	DVM_GPG_DIR="${DVM_GPG_DIR:-$DVM_STATE/gpg}"
	DVM_AI_NAME="${DVM_AI_NAME:-ai}"
	DVM_AI_PACKAGES="${DVM_AI_PACKAGES:-llama-cpp curl}"
	DVM_AI_SERVER_CMD="${DVM_AI_SERVER_CMD:-llama-server}"
	DVM_AI_SERVICE_NAME="${DVM_AI_SERVICE_NAME:-dvm-llama.service}"
	DVM_AI_SYSTEMD_DIR="${DVM_AI_SYSTEMD_DIR:-/etc/systemd/system}"
	DVM_AI_HOST="${DVM_AI_HOST:-0.0.0.0}"
	DVM_AI_PORT="${DVM_AI_PORT:-8080}"
	DVM_AI_MODELS_DIR="${DVM_AI_MODELS_DIR:-$DVM_GUEST_HOME/models}"
	DVM_AI_CURRENT_MODEL="${DVM_AI_CURRENT_MODEL:-$DVM_AI_MODELS_DIR/current.gguf}"
	DVM_AI_DEFAULT_MODEL="${DVM_AI_DEFAULT_MODEL:-qwen25-coder-7b-q4}"
	DVM_AI_MODELS="${DVM_AI_MODELS:-qwen25-coder-7b-q4=https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf?download=true}"
	DVM_AI_EXTRA_ARGS="${DVM_AI_EXTRA_ARGS:-}"
}

dvm_init() {
	dvm_load_config
	mkdir -p "$DVM_CONFIG/setup.d" "$DVM_STATE" "$DVM_GPG_DIR"
	chmod 0700 "$DVM_STATE" "$DVM_GPG_DIR"

	if [ ! -f "$DVM_CONFIG/config.sh" ]; then
		cp "$DVM_CORE/defaults/config.sh" "$DVM_CONFIG/config.sh"
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
