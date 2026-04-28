#!/usr/bin/env bash
# shellcheck shell=bash

dvm_doctor() {
	local missing cmd
	missing="0"
	dvm_load_config

	dvm_log "core: $DVM_CORE"
	dvm_log "config: $DVM_CONFIG"
	dvm_log "state: $DVM_STATE"
	dvm_log "prefix: $DVM_PREFIX"

	for cmd in bash limactl ssh-keygen git; do
		if dvm_command_exists "$cmd"; then
			dvm_log "ok: $cmd"
		else
			dvm_warn "missing: $cmd"
			missing="1"
		fi
	done

	if dvm_command_exists gpg; then
		dvm_log "ok: gpg"
	else
		dvm_warn "missing optional: gpg (needed for dvm gpg commands)"
	fi

	[ "$missing" = "0" ] || return 1
}
