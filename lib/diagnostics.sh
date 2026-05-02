#!/usr/bin/env bash
# shellcheck shell=bash

dvm_status() {
	local dir name ports row_vm short size status vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm status <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	dvm_vm_exists "$vm" || dvm_die "VM not found: $vm"
	if IFS=$'\t' read -r row_vm status dir < <(dvm_lima_row "$vm"); then
		:
	else
		status="unknown"
		dir="${LIMA_HOME:-$HOME/.lima}/$vm"
	fi
	short="$(dvm_vm_short_name "$vm")"
	size="-"
	if [ -d "$dir" ]; then
		size="$(du -sh "$dir" 2>/dev/null | awk '{print $1}')" || size="-"
	fi
	ports="$(dvm_vm_ports_from_yaml "$dir")"
	printf 'name: %s\n' "$short"
	printf 'vm: %s\n' "$vm"
	printf 'status: %s\n' "${status:-unknown}"
	printf 'size: %s\n' "${size:-"-"}"
	printf 'ports: %s\n' "$ports"
	printf 'host-ip: %s\n' "$DVM_HOST_IP"
	printf 'code-dir: %s\n' "$DVM_CODE_DIR"
	printf 'setup-scripts: %s\n' "${DVM_SETUP_SCRIPTS:-"-"}"
	printf 'dotfiles: %s\n' "${DVM_DOTFILES_DIR:-"-"}"
	printf 'dir: %s\n' "$dir"
}

dvm_default_log_unit() {
	local count script unit
	count="0"
	unit=""
	for script in $DVM_SETUP_SCRIPTS; do
		case "${script##*/}" in
		llama.sh)
			unit="${DVM_LLAMA_SERVICE:-dvm-llama.service}"
			count=$((count + 1))
			;;
		cloudflared.sh)
			unit="${DVM_CLOUDFLARED_SERVICE:-dvm-cloudflared.service}"
			count=$((count + 1))
			;;
		esac
	done
	[ "$count" -eq 1 ] || return 1
	printf '%s\n' "$unit"
}

dvm_logs() {
	local name unit vm
	[ "$#" -ge 1 ] || dvm_die "usage: dvm logs <name> [unit] [journalctl-args...]"
	name="$1"
	shift
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	dvm_vm_exists "$vm" || dvm_die "VM not found: $vm"
	unit=""
	if [ "$#" -gt 0 ]; then
		case "$1" in
		*.service)
			unit="$1"
			shift
			;;
		esac
	fi
	if [ -z "$unit" ]; then
		unit="$(dvm_default_log_unit)" ||
			dvm_die "usage: dvm logs <name> <unit> [journalctl-args...]"
	fi
	dvm_validate_systemd_unit unit "$unit"
	if [ "$#" -eq 0 ]; then
		set -- --no-pager -n 100
	fi
	limactl shell "$vm" sudo journalctl -u "$unit" "$@"
}

dvm_doctor_failures=0
dvm_doctor_warnings=0

dvm_doctor_ok() {
	printf 'ok: %s\n' "$*"
}

dvm_doctor_warn() {
	dvm_doctor_warnings=$((dvm_doctor_warnings + 1))
	printf 'warn: %s\n' "$*"
}

dvm_doctor_fail() {
	dvm_doctor_failures=$((dvm_doctor_failures + 1))
	printf 'fail: %s\n' "$*"
}

dvm_doctor_command() {
	local required tool
	tool="$1"
	required="$2"
	if dvm_command_exists "$tool"; then
		dvm_doctor_ok "$tool found: $(command -v "$tool")"
	elif [ "$required" = "1" ]; then
		dvm_doctor_fail "required command not found: $tool"
	else
		dvm_doctor_warn "optional command not found: $tool"
	fi
}

dvm_doctor_disk() {
	local available_kb path
	path="${DVM_STATE:-$HOME}"
	while [ ! -e "$path" ] && [ "$path" != "/" ]; do
		path="${path%/*}"
		[ -n "$path" ] || path="/"
	done
	available_kb="$(df -Pk "$path" 2>/dev/null | awk 'NR == 2 { print $4 }')" || available_kb=""
	if [ -z "$available_kb" ]; then
		dvm_doctor_warn "could not check free disk space at $path"
	elif [ "$available_kb" -lt 10485760 ]; then
		dvm_doctor_warn "less than 10 GiB free at $path"
	else
		dvm_doctor_ok "free disk space at $path"
	fi
}

dvm_doctor_port() {
	local actual dir other port vm
	port="$1"
	vm="$2"
	dir="$3"
	actual="$(dvm_vm_ports_canonical_from_yaml "$dir" | grep -Fx "$DVM_HOST_IP:$port" || true)"
	if [ -n "$actual" ]; then
		dvm_doctor_ok "port already configured on $vm: $port"
		return 0
	fi
	other="$(dvm_vm_ports_canonical_from_yaml "$dir" | awk -F: -v port="$port" '$2 ":" $3 == port { print; exit }')"
	if [ -n "$other" ]; then
		dvm_doctor_warn "port configured with a different host IP; run dvm setup $DVM_NAME: $port"
		return 0
	fi
	if ! dvm_command_exists lsof; then
		dvm_doctor_warn "cannot check host port availability without lsof: $port"
		return 0
	fi
	if lsof -nP -iTCP:"${port%%:*}" -sTCP:LISTEN >/dev/null 2>&1; then
		dvm_doctor_fail "host port appears to be in use: ${port%%:*}"
	else
		dvm_doctor_ok "host port available: ${port%%:*}"
	fi
}

dvm_doctor() {
	local config dir name port script version vm
	[ "$#" -le 1 ] || dvm_die "usage: dvm doctor [name]"
	dvm_doctor_failures=0
	dvm_doctor_warnings=0
	name="${1:-}"
	if [ -n "$name" ]; then
		dvm_validate_name "$name"
		dvm_load_vm_config "$name"
	else
		dvm_load_defaults
	fi

	dvm_doctor_command limactl 1
	dvm_doctor_command tar 1
	dvm_doctor_command git 0
	dvm_doctor_command lsof 0
	case "$(uname -s)" in
	Darwin) dvm_doctor_ok "host OS is macOS" ;;
	*) dvm_doctor_warn "DVM is only implemented and tested on macOS" ;;
	esac
	if dvm_command_exists sysctl && [ "$(uname -s)" = "Darwin" ]; then
		case "$(sysctl -n kern.hv_support 2>/dev/null || true)" in
		1) dvm_doctor_ok "Apple Hypervisor support is available" ;;
		*) dvm_doctor_warn "could not confirm Apple Hypervisor support" ;;
		esac
	fi
	if dvm_command_exists limactl; then
		version="$(limactl --version 2>/dev/null || true)"
		[ -n "$version" ] && dvm_doctor_ok "$version"
		limactl list >/dev/null 2>&1 && dvm_doctor_ok "limactl list works" ||
			dvm_doctor_fail "limactl list failed"
	fi
	dvm_doctor_disk

	if [ -n "$name" ]; then
		config="$(dvm_vm_config_path "$name")"
		[ -f "$config" ] && dvm_doctor_ok "config found: $config" ||
			dvm_doctor_warn "config not found, using defaults: $config"
		vm="$(dvm_vm_name "$name")"
		dir="$(dvm_vm_dir "$vm")"
		if dvm_vm_exists "$vm"; then
			dvm_doctor_ok "VM exists: $vm"
		else
			dvm_doctor_warn "VM does not exist yet: $vm"
		fi
		case "$DVM_HOST_IP" in
		127.0.0.1) dvm_doctor_ok "ports bind to localhost" ;;
		0.0.0.0) dvm_doctor_warn "ports bind to all host interfaces" ;;
		*) dvm_doctor_warn "ports bind to custom host IP: $DVM_HOST_IP" ;;
		esac
		for port in $DVM_PORTS; do
			dvm_validate_port "$port"
			dvm_doctor_port "$port" "$vm" "$dir"
		done
		if [ -n "$DVM_DOTFILES_DIR" ]; then
			[ -d "$DVM_DOTFILES_DIR" ] && dvm_doctor_ok "dotfiles directory found" ||
				dvm_doctor_fail "dotfiles directory not found: $DVM_DOTFILES_DIR"
		fi
		for script in $DVM_SETUP_SCRIPTS; do
			[ -f "$(dvm_recipe_path "$script")" ] && dvm_doctor_ok "setup script found: $script" ||
				dvm_doctor_fail "setup script not found: $script"
		done
	fi

	if [ "$dvm_doctor_failures" -gt 0 ]; then
		printf 'doctor: %s failure(s), %s warning(s)\n' "$dvm_doctor_failures" "$dvm_doctor_warnings"
		return 1
	fi
	printf 'doctor: ok'
	if [ "$dvm_doctor_warnings" -gt 0 ]; then
		printf ' (%s warning(s))' "$dvm_doctor_warnings"
	fi
	printf '\n'
}
