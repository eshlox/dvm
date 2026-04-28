#!/usr/bin/env bash
# shellcheck shell=bash

dvm_doctor() {
	local missing cmd
	missing="0"
	dvm_load_config

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

	[ "$missing" = "0" ] || return 1
}
