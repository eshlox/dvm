#!/usr/bin/env bash
# shellcheck shell=bash

dvm_vm_name() {
	printf '%s-%s\n' "$DVM_PREFIX" "$1"
}

dvm_vm_short_name() {
	local vm
	vm="$1"
	case "$vm" in
	"$DVM_PREFIX"-*) printf '%s\n' "${vm#"$DVM_PREFIX"-}" ;;
	*) return 1 ;;
	esac
}

dvm_lima_names() {
	limactl list --format '{{.Name}}' 2>/dev/null | sort
}

dvm_list_names() {
	local vm
	dvm_require limactl
	while IFS= read -r vm; do
		dvm_vm_short_name "$vm" || true
	done < <(dvm_lima_names)
}

dvm_lima_rows() {
	local format
	format="$(printf '{{.Name}}\t{{.Status}}\t{{.Dir}}')"
	limactl list --format "$format" 2>/dev/null || dvm_lima_names
}

dvm_vm_exists() {
	local vm
	vm="$1"
	dvm_lima_names | grep -Fxq "$vm"
}

dvm_vm_dir() {
	local dir row_vm status vm
	vm="$1"
	while IFS=$'\t' read -r row_vm status dir _; do
		[ "$row_vm" = "$vm" ] || continue
		printf '%s\n' "${dir:-${LIMA_HOME:-$HOME/.lima}/$vm}"
		return 0
	done < <(dvm_lima_rows)
	printf '%s\n' "${LIMA_HOME:-$HOME/.lima}/$vm"
}

dvm_vm_ports_from_yaml() {
	local file guest host ports
	file="$1/lima.yaml"
	[ -f "$file" ] || {
		printf -- '-\n'
		return 0
	}
	ports="$(
		awk '
			/hostPort:/ { host=$NF; gsub(/"/, "", host) }
			/guestPort:/ { guest=$NF; gsub(/"/, "", guest) }
			host && guest { print host ":" guest; host=""; guest="" }
		' "$file" | paste -sd, -
	)"
	printf '%s\n' "${ports:-"-"}"
}

dvm_vm_ports_canonical_from_yaml() {
	local file
	file="$1/lima.yaml"
	[ -f "$file" ] || return 0
	awk '
		/hostPort:/ { host=$NF; gsub(/"/, "", host) }
		/guestPort:/ { guest=$NF; gsub(/"/, "", guest) }
		host && guest { print host ":" guest; host=""; guest="" }
	' "$file" | sort
}

dvm_list() {
	local dir ports short size status vm
	[ "$#" -eq 0 ] || dvm_die "usage: dvm list"
	dvm_load_defaults
	printf '%-18s %-12s %-10s %-18s %s\n' NAME STATUS SIZE PORTS DIR
	while IFS=$'\t' read -r vm status dir _; do
		[ -n "$vm" ] || continue
		short="$(dvm_vm_short_name "$vm")" || continue
		dir="${dir:-${LIMA_HOME:-$HOME/.lima}/$vm}"
		size="-"
		[ -d "$dir" ] && size="$(du -sh "$dir" 2>/dev/null | awk '{print $1}')" || true
		ports="$(dvm_vm_ports_from_yaml "$dir")"
		printf '%-18s %-12s %-10s %-18s %s\n' "$short" "${status:-unknown}" "${size:-"-"}" "$ports" "$dir"
	done < <(dvm_lima_rows | sort)
}

dvm_validate_port() {
	local guest host port
	port="$1"
	case "$port" in
	'' | *[!0-9:]* | *:*:*) dvm_die "invalid port forward: $1" ;;
	esac
	case "$port" in
	*:*) ;;
	*) dvm_die "port forward must be host:guest: $1" ;;
	esac
	host="${port%%:*}"
	guest="${port#*:}"
	dvm_validate_port_number host "$host"
	dvm_validate_port_number guest "$guest"
}

dvm_configured_ports_canonical() {
	local port
	printf '5355:5355\n'
	for port in $DVM_PORTS; do
		dvm_validate_port "$port"
		printf '%s\n' "$port"
	done | sort
}

dvm_port_forwards_set_expr() {
	local expr first guest host port
	expr='.portForwards = [{"guestPort":5355,"proto":"any","ignore":true}'
	first="0"
	for port in $DVM_PORTS; do
		dvm_validate_port "$port"
		host="${port%%:*}"
		guest="${port#*:}"
		if [ "$first" = "1" ]; then
			first="0"
		else
			expr="$expr,"
		fi
		expr="$expr{\"hostPort\":$host,\"guestPort\":$guest,\"hostIP\":\"127.0.0.1\"}"
	done
	printf '%s]\n' "$expr"
}

dvm_apply_port_config() {
	local actual desired expr vm vm_dir
	vm="$1"
	dvm_vm_exists "$vm" || dvm_die "VM not found: $vm"
	vm_dir="$(dvm_vm_dir "$vm")"
	desired="$(dvm_configured_ports_canonical | paste -sd' ' -)"
	actual="$(dvm_vm_ports_canonical_from_yaml "$vm_dir" | paste -sd' ' -)"
	[ "$desired" = "$actual" ] && return 0
	dvm_log "updating port forwards for $vm (restart required)"
	expr="$(dvm_port_forwards_set_expr)"
	limactl stop "$vm" >/dev/null 2>&1 || true
	limactl edit --tty=false --set "$expr" --start "$vm" >/dev/null
}

dvm_create() {
	local name network_set port vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm create <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	case "$DVM_NETWORK" in
	user-v2) network_set='[{"lima":"user-v2"}]' ;;
	vzNAT) network_set='[{"vzNAT":true}]' ;;
	esac

	if dvm_vm_exists "$vm"; then
		dvm_log "VM already exists: $vm"
	else
		dvm_log "creating $vm"
		set -- create \
			--name "$vm" \
			--tty=false \
			--set ".vmType=\"vz\"" \
			--set ".arch=$(dvm_json "$DVM_ARCH")" \
			--set ".cpus=$DVM_CPUS" \
			--set ".memory=$(dvm_json "$DVM_MEMORY")" \
			--set ".disk=$(dvm_json "$DVM_DISK")" \
			--set ".user.name=$(dvm_json "$DVM_GUEST_USER")" \
			--set ".user.home=$(dvm_json "$DVM_GUEST_HOME")" \
			--set ".mountType=\"virtiofs\"" \
			--set ".mounts=[]" \
			--set ".networks=$network_set" \
			--set '.portForwards=[{"guestPort":5355,"proto":"any","ignore":true}]' \
			--set ".containerd.system=false | .containerd.user=false"
		for port in $DVM_PORTS; do
			dvm_validate_port "$port"
			set -- "$@" --port-forward "$port,static=true"
		done
		limactl "$@" "$DVM_TEMPLATE"
	fi
	dvm_setup "$name"
}

dvm_package_setup_remote() {
	cat <<'REMOTE'
set -euo pipefail
code_dir="$1"
packages="$2"
mkdir -p "$code_dir"
if [ -n "$packages" ]; then
	for package in $packages; do
		case "$package" in
		-* | *[!A-Za-z0-9._+:@-]*)
			echo "invalid package token: $package" >&2
			exit 1
			;;
		esac
	done
	command -v dnf5 >/dev/null 2>&1 || {
		echo "dnf5 is required in the guest image" >&2
		exit 1
	}
	# shellcheck disable=SC2086
	sudo dnf5 install -y $packages
fi
REMOTE
}

dvm_recipe_path() {
	local core_script script user_script
	script="$1"
	case "$script" in
	/* | ./* | ../*) printf '%s\n' "$script" ;;
	*)
		user_script="$DVM_RECIPE_DIR/$script"
		core_script="$DVM_CORE/recipes/$script"
		if [ -f "$user_script" ]; then
			[ -f "$core_script" ] && dvm_warn "using user recipe that shadows built-in recipe: $user_script"
			printf '%s\n' "$user_script"
		else
			printf '%s\n' "$core_script"
		fi
		;;
	esac
}

dvm_env_args=()

dvm_build_env_args() {
	local var
	dvm_env_args=()
	while IFS= read -r var; do
		dvm_env_args+=("$var=${!var}")
	done < <(compgen -v DVM_ | sort)
}

dvm_run_setup_script() {
	local script vm
	vm="$1"
	script="$(dvm_recipe_path "$2")"
	[ -f "$script" ] || dvm_die "setup script not found: $script"
	dvm_log "running setup script: $script"
	dvm_build_env_args
	limactl shell "$vm" env "${dvm_env_args[@]}" bash -s <"$script"
}

dvm_run_inline_setup() {
	local vm
	vm="$1"
	if ! declare -F dvm_vm_setup >/dev/null; then
		return 0
	fi
	dvm_log "running inline setup from $(dvm_vm_config_path "$DVM_NAME")"
	{
		printf 'set -euo pipefail\n'
		declare -f dvm_vm_setup
		printf 'dvm_vm_setup\n'
	} | {
		dvm_build_env_args
		limactl shell "$vm" env "${dvm_env_args[@]}" bash -s
	}
}

dvm_resolve_host_dir() {
	(cd "$1" 2>/dev/null && pwd -P) || dvm_die "directory not found: $1"
}

dvm_sync_dotfiles() {
	local exclude source_real target vm
	vm="$1"
	[ -n "$DVM_DOTFILES_DIR" ] || return 0
	[ -d "$DVM_DOTFILES_DIR" ] || dvm_die "dotfiles directory not found: $DVM_DOTFILES_DIR"
	dvm_require tar
	source_real="$(dvm_resolve_host_dir "$DVM_DOTFILES_DIR")"
	target="${DVM_DOTFILES_TARGET%/}"
	case "$target" in
	"$DVM_GUEST_HOME" | "$DVM_GUEST_HOME/.ssh" | "$DVM_GUEST_HOME/.gnupg" | *..*)
		dvm_die "unsafe DVM_DOTFILES_TARGET: $target"
		;;
	"$DVM_GUEST_HOME"/*) ;;
	*) dvm_die "DVM_DOTFILES_TARGET must stay under DVM_GUEST_HOME: $target" ;;
	esac
	dvm_log "syncing dotfiles: $source_real -> $target"
	(
		cd "$source_real" || exit 1
		export COPYFILE_DISABLE=1
		set -- tar
		if tar --help 2>/dev/null | grep -q -- '--no-xattrs'; then
			set -- "$@" --no-xattrs
		fi
		set -- "$@" -cf -
		for exclude in $DVM_DOTFILES_EXCLUDES; do
			set -- "$@" --exclude "$exclude"
		done
		set -- "$@" .
		"$@"
	) | limactl shell "$vm" bash -c 'set -euo pipefail; target="$1"; rm -rf "$target"; mkdir -p "$target"; set -- tar -C "$target"; if tar --help 2>/dev/null | grep -q -- "--warning="; then set -- "$@" --warning=no-unknown-keyword; fi; set -- "$@" -xf -; "$@"' dvm-dotfiles "$target"
}

dvm_setup() {
	local name script vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm setup <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	dvm_apply_port_config "$vm"
	limactl start "$vm" >/dev/null
	limactl shell "$vm" bash -c "$(dvm_package_setup_remote)" dvm-setup "$DVM_CODE_DIR" "$DVM_PACKAGES"
	dvm_sync_dotfiles "$vm"
	for script in $DVM_SETUP_SCRIPTS; do
		dvm_run_setup_script "$vm" "$script"
	done
	dvm_run_inline_setup "$vm"
}

dvm_setup_all() {
	local name
	[ "$#" -eq 0 ] || dvm_die "usage: dvm setup-all"
	dvm_load_defaults
	for name in $(dvm_list_names); do
		dvm_setup "$name"
	done
}

dvm_upgrade_remote() {
	cat <<'REMOTE'
set -euo pipefail
command -v dnf5 >/dev/null 2>&1 || {
	echo "dnf5 is required in the guest image" >&2
	exit 1
}
sudo dnf5 upgrade -y
REMOTE
}

dvm_upgrade() {
	local name vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm upgrade <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	dvm_apply_port_config "$vm"
	limactl start "$vm" >/dev/null
	dvm_log "upgrading $vm"
	limactl shell "$vm" bash -c "$(dvm_upgrade_remote)" dvm-upgrade
	dvm_setup "$name"
}

dvm_upgrade_all() {
	local name
	[ "$#" -eq 0 ] || dvm_die "usage: dvm upgrade-all"
	dvm_load_defaults
	for name in $(dvm_list_names); do
		dvm_upgrade "$name"
	done
}

dvm_enter() {
	local name quoted_dir vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm enter <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	vm="$(dvm_vm_name "$name")"
	quoted_dir="$(dvm_quote "$DVM_CODE_DIR")"
	limactl shell "$vm" bash -lc "mkdir -p $quoted_dir; cd $quoted_dir; exec \${SHELL:-/bin/bash} -l"
}

dvm_ssh() {
	local name quoted_dir vm
	[ "$#" -ge 1 ] || dvm_die "usage: dvm ssh <name> [command...]"
	name="$1"
	shift
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	vm="$(dvm_vm_name "$name")"
	if [ "$#" -eq 0 ]; then
		quoted_dir="$(dvm_quote "$DVM_CODE_DIR")"
		limactl shell "$vm" bash -lc "mkdir -p $quoted_dir; cd $quoted_dir; exec \${SHELL:-/bin/bash} -l"
		return 0
	fi
	limactl shell "$vm" "$@"
}

dvm_ssh_key() {
	local name remote vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm ssh-key <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	vm="$(dvm_vm_name "$name")"
	remote='set -euo pipefail; key="$HOME/.ssh/id_ed25519_dvm"; config="$HOME/.ssh/config"; mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"; [ -f "$key" ] || ssh-keygen -t ed25519 -C "$DVM_NAME-dvm" -f "$key" -N ""; touch "$config"; chmod 600 "$config"; if ! grep -Eq "^[[:space:]]*IdentityFile[[:space:]]+$key([[:space:]]|$)" "$config"; then { printf "\nHost github.com\n"; printf "  HostName github.com\n"; printf "  User git\n"; printf "  IdentityFile %s\n" "$key"; printf "  IdentitiesOnly yes\n"; printf "  AddKeysToAgent no\n"; } >>"$config"; fi; cat "$key.pub"'
	limactl shell "$vm" env "DVM_NAME=$name" bash -lc "$remote"
}

dvm_gpg_key() {
	local name remote vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm gpg-key <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	vm="$(dvm_vm_name "$name")"
	remote='set -euo pipefail; uid="$DVM_NAME dvm <dvm-$DVM_NAME@local>"; if ! gpg --list-secret-keys "$uid" >/dev/null 2>&1; then gpg --batch --passphrase "" --quick-gen-key "$uid" ed25519 sign 1y; fi; gpg --armor --export "$uid"; gpg --with-colons --list-secret-keys "$uid" | awk -F: '"'"'$1 == "fpr" { print "fingerprint: " $10; exit }'"'"''
	limactl shell "$vm" env "DVM_NAME=$name" bash -lc "$remote"
}

dvm_dirty_check_remote() {
	cat <<'REMOTE'
set -euo pipefail
code_dir="$1"
[ -d "$code_dir" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
dirty=0
while IFS= read -r gitdir; do
	repo="${gitdir%/.git}"
	if ! git -C "$repo" diff --quiet ||
		! git -C "$repo" diff --cached --quiet ||
		[ -n "$(git -C "$repo" ls-files --others --exclude-standard)" ]; then
		echo "dirty repository: $repo" >&2
		dirty=1
	fi
done < <(find "$code_dir" \( -type d -name .git -prune -print \) -o \( -type f -name .git -print \))
exit "$dirty"
REMOTE
}

dvm_rm() {
	local force name vm
	force="0"
	[ "$#" -ge 1 ] || dvm_die "usage: dvm rm <name> [--force]"
	name="$1"
	shift
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--force | -f) force="1" ;;
		*) dvm_die "unknown rm option: $1" ;;
		esac
		shift
	done
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	vm="$(dvm_vm_name "$name")"
	if [ "$force" != "1" ]; then
		if ! limactl start "$vm" >/dev/null; then
			dvm_die "could not start $vm to check for dirty repos; retry with --force if you accept the risk"
		fi
		limactl shell "$vm" bash -c "$(dvm_dirty_check_remote)" dvm-dirty "$DVM_CODE_DIR" ||
			dvm_die "refusing to delete $vm; commit/stash changes or pass --force"
	fi
	limactl delete --force "$vm"
}
