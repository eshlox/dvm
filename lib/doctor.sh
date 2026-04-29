#!/usr/bin/env bash
# shellcheck shell=bash

dvm_doctor() {
	local config_file missing cmd unknown_var
	missing="0"
	dvm_load_config
	config_file="$DVM_CONFIG/config.sh"

	printf 'core: %s\n' "$DVM_CORE"
	printf 'config: %s\n' "$DVM_CONFIG"
	printf 'state: %s\n' "$DVM_STATE"
	printf 'prefix: %s\n' "$DVM_PREFIX"

	for cmd in bash limactl ssh-keygen git; do
		if dvm_command_exists "$cmd"; then
			printf 'ok: %s\n' "$cmd"
		else
			dvm_warn "missing: $cmd"
			missing="1"
		fi
	done

	if dvm_command_exists gpg; then
		printf 'ok: gpg\n'
	else
		dvm_warn "missing optional: gpg (needed for dvm gpg commands)"
	fi

	if [ ! -f "$config_file" ]; then
		dvm_warn "missing config file: $config_file (run: dvm init)"
	else
		while IFS= read -r unknown_var; do
			[ -n "$unknown_var" ] || continue
			dvm_warn "unknown config variable in config.sh: $unknown_var"
		done < <(dvm_config_unknown_vars "$config_file")
	fi

	if [ "$DVM_AI_HOST" = "0.0.0.0" ]; then
		dvm_warn "DVM_AI_HOST=0.0.0.0 exposes llama-server on the VM network; use 127.0.0.1 unless intentional"
	fi

	[ "$missing" = "0" ] || return 1
}
