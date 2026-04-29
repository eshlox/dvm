#!/usr/bin/env bash
# shellcheck shell=bash

dvm_vm_name() {
	local name
	name="$1"
	printf '%s-%s\n' "$DVM_PREFIX" "$name"
}

dvm_vm_short_name() {
	local vm
	vm="$1"
	case "$vm" in
	"$DVM_PREFIX"-*) printf '%s\n' "${vm#"$DVM_PREFIX"-}" ;;
	*) return 1 ;;
	esac
}

dvm_list_names() {
	local vm
	dvm_load_config
	dvm_require limactl
	while IFS= read -r vm; do
		dvm_vm_short_name "$vm" || true
	done < <(limactl list --format '{{.Name}}' 2>/dev/null | sort)
}

dvm_lima_list_rows() {
	local format
	format="$(printf '{{.Name}}\t{{.Status}}\t{{.Dir}}')"
	if limactl list --format "$format" 2>/dev/null; then
		return 0
	fi
	format="$(printf '{{.Name}}\t{{.Status}}')"
	if limactl list --format "$format" 2>/dev/null; then
		return 0
	fi
	limactl list --format '{{.Name}}' 2>/dev/null
}

dvm_vm_dir_size() {
	local dir size
	dir="$1"
	size="-"
	if [ -d "$dir" ]; then
		size="$(du -sh "$dir" 2>/dev/null | awk '{print $1}')" || size="-"
	fi
	printf '%s\n' "${size:-"-"}"
}

dvm_vm_ram_usage() {
	local vm
	vm="$1"
	limactl shell "$vm" bash -lc '
		if command -v free >/dev/null 2>&1; then
			free -h | awk '"'"'$1 == "Mem:" { print $3 "/" $2; exit }'"'"'
		else
			printf "-\n"
		fi
	' 2>/dev/null || printf -- '-\n'
}

dvm_vm_listening_ports() {
	local vm
	vm="$1"
	limactl shell "$vm" bash -lc '
		if ! command -v ss >/dev/null 2>&1; then
			printf "-\n"
			exit 0
		fi
		ports="$(
			ss -H -tln 2>/dev/null |
				awk '"'"'{
					addr = $4
					if (addr ~ /\]:[0-9]+$/) {
						sub(/^.*\]:/, "", addr)
					} else {
						sub(/^.*:/, "", addr)
					}
					if (addr ~ /^[0-9]+$/) {
						print addr
					}
				}'"'"' |
				sort -n -u |
				paste -sd, -
		)"
		printf "%s\n" "${ports:-"-"}"
	' 2>/dev/null || printf -- '-\n'
}

dvm_vm_has_port_forward_dir() {
	local dir file guest_port host_port
	dir="$1"
	host_port="$2"
	guest_port="$3"
	file="$dir/lima.yaml"
	[ -f "$file" ] || return 1
	grep -Eq "hostPort:[[:space:]]*\"?$host_port\"?([[:space:]]*(#.*)?)?$" "$file" &&
		grep -Eq "guestPort:[[:space:]]*\"?$guest_port\"?([[:space:]]*(#.*)?)?$" "$file"
}

dvm_vm_ai_url() {
	local dir short status vm
	vm="$1"
	short="$2"
	status="$3"
	dir="$4"
	if [ "$short" != "$DVM_AI_NAME" ]; then
		printf -- '-\n'
		return 0
	fi
	case "$status" in
	Running | running) ;;
	*)
		printf -- '-\n'
		return 0
		;;
	esac
	if dvm_vm_has_port_forward_dir "$dir" "$DVM_AI_PORT" "$DVM_AI_PORT"; then
		printf 'http://127.0.0.1:%s\n' "$DVM_AI_PORT"
	else
		printf 'run dvm ai expose\n'
	fi
}

dvm_list_long() {
	local ai_url dir ports ram short size status vm
	printf '%-18s %-12s %-8s %-13s %-18s %-24s %s\n' \
		"NAME" "STATUS" "SIZE" "RAM" "PORTS" "AI_URL" "DIR"
	while IFS=$'\t' read -r vm status dir _; do
		[ -n "$vm" ] || continue
		short="$(dvm_vm_short_name "$vm")" || continue
		status="${status:-unknown}"
		dir="${dir:-${LIMA_HOME:-$HOME/.lima}/$vm}"
		size="$(dvm_vm_dir_size "$dir")"
		ram="-"
		ports="-"
		case "$status" in
		Running | running)
			ram="$(dvm_vm_ram_usage "$vm")"
			ports="$(dvm_vm_listening_ports "$vm")"
			;;
		esac
		ai_url="$(dvm_vm_ai_url "$vm" "$short" "$status" "$dir")"
		printf '%-18s %-12s %-8s %-13s %-18s %-24s %s\n' \
			"$short" "$status" "$size" "$ram" "$ports" "$ai_url" "$dir"
	done < <(dvm_lima_list_rows | sort)
}

dvm_list() {
	local long
	long="0"
	while [ "$#" -gt 0 ]; do
		case "$1" in
		-l | --long | --status) long="1" ;;
		*) dvm_die "usage: dvm list [--long]" ;;
		esac
		shift
	done
	dvm_load_config
	dvm_require limactl
	if [ "$long" = "1" ]; then
		dvm_list_long
	else
		dvm_list_names
	fi
}

dvm_create() {
	local name port_forward vm
	local -a port_forward_args
	[ "$#" -eq 1 ] || dvm_die "usage: dvm new <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_config
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	port_forward_args=()
	for port_forward in ${DVM_CREATE_PORT_FORWARDS:-}; do
		case "$port_forward" in
		'' | *[!A-Za-z0-9.,:=_-]*)
			dvm_die "invalid port forward: $port_forward"
			;;
		esac
		port_forward_args+=(--port-forward "$port_forward")
	done

	if limactl list --format '{{.Name}}' 2>/dev/null | grep -Fxq "$vm"; then
		dvm_log "VM already exists: $vm"
	else
		dvm_log "creating $vm from $DVM_TEMPLATE"
		limactl create \
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
			--set ".networks=[{\"vzNAT\":true}]" \
			--set ".containerd.system=false | .containerd.user=false" \
			"${port_forward_args[@]}" \
			"$DVM_TEMPLATE"
	fi

	limactl start "$vm"
	dvm_setup "$name"
	dvm_key "$name"
}

dvm_core_setup_remote() {
	cat <<'REMOTE'
set -euo pipefail
name="$1"
code_dir="$2"
packages="$3"

mkdir -p "$HOME/.ssh" "$HOME/.gnupg" "$code_dir"
chmod 0700 "$HOME/.ssh" "$HOME/.gnupg"

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

key="$HOME/.ssh/id_ed25519_$name"
if [ ! -f "$key" ]; then
	ssh-keygen -t ed25519 -C "$name-dvm" -f "$key" -N ''
fi

ssh_config="$HOME/.ssh/config"
touch "$ssh_config"
chmod 0600 "$ssh_config"
if ! grep -Fq "# BEGIN DVM $name GITHUB" "$ssh_config"; then
	cat >>"$ssh_config" <<CONFIG
# BEGIN DVM $name GITHUB
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_$name
  IdentitiesOnly yes
# END DVM $name GITHUB
CONFIG
fi
REMOTE
}

dvm_resolve_host_dir() {
	local dir
	dir="$1"
	(
		cd "$dir" 2>/dev/null &&
			pwd -P
	) || dvm_die "directory not found: $dir"
}

dvm_validate_dotfiles_source() {
	local source_real home_real
	source_real="$1"
	home_real="$(dvm_resolve_host_dir "$HOME")"

	case "$source_real" in
	/ | "$home_real" | "$home_real/.ssh" | "$home_real/.ssh/"* | "$home_real/.gnupg" | "$home_real/.gnupg/"*)
		dvm_die "refusing dangerous DVM_DOTFILES_DIR: $source_real"
		;;
	esac
}

dvm_strip_trailing_slashes() {
	local path
	path="$1"
	while [ "$path" != "/" ] && [ "${path%/}" != "$path" ]; do
		path="${path%/}"
	done
	printf '%s\n' "$path"
}

dvm_normalize_dotfiles_target() {
	local target guest_home
	target="$1"
	target="$(dvm_strip_trailing_slashes "$target")"
	guest_home="$(dvm_strip_trailing_slashes "$DVM_GUEST_HOME")"

	case "$target" in
	/*) ;;
	*) dvm_die "DVM_DOTFILES_TARGET must be an absolute path: $target" ;;
	esac

	case "$target" in
	*/../* | */.. | */./* | */.)
		dvm_die "DVM_DOTFILES_TARGET must not contain . or .. path segments: $target"
		;;
	esac

	case "$target" in
	"$guest_home")
		dvm_die "refusing unsafe DVM_DOTFILES_TARGET: $target"
		;;
	"$guest_home/.ssh" | "$guest_home/.ssh/"* | \
		"$guest_home/.gnupg" | "$guest_home/.gnupg/"*)
		dvm_die "refusing unsafe DVM_DOTFILES_TARGET: $target"
		;;
	"$guest_home"/*) ;;
	*) dvm_die "DVM_DOTFILES_TARGET must stay under DVM_GUEST_HOME: $target" ;;
	esac

	printf '%s\n' "$target"
}

dvm_sync_dotfiles_remote() {
	cat <<'REMOTE'
set -euo pipefail
target="$1"
parent="$(dirname "$target")"

mkdir -p "$parent"
rm -rf "$target"
mkdir -p "$target"
tar -C "$target" -xf -
REMOTE
}

dvm_sync_dotfiles() {
	local vm source_real target remote exclude
	vm="$1"
	[ -n "$DVM_DOTFILES_DIR" ] || return 0

	[ -d "$DVM_DOTFILES_DIR" ] || dvm_die "dotfiles directory not found: $DVM_DOTFILES_DIR"
	dvm_require tar

	source_real="$(dvm_resolve_host_dir "$DVM_DOTFILES_DIR")"
	dvm_validate_dotfiles_source "$source_real"

	target="$(dvm_normalize_dotfiles_target "$DVM_DOTFILES_TARGET")"

	remote="$(dvm_sync_dotfiles_remote)"

	dvm_log "syncing dotfiles into $vm: $source_real -> $target"
	(
		cd "$source_real" || exit 1
		set -- tar -cf -
		for exclude in $DVM_DOTFILES_EXCLUDES; do
			set -- "$@" --exclude "$exclude"
		done
		set -- "$@" .
		"$@"
	) | limactl shell "$vm" bash -c "$remote" dvm-dotfiles "$target"
}

dvm_setup() {
	local name vm remote script
	[ "$#" -eq 1 ] || dvm_die "usage: dvm setup <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_config
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	remote="$(dvm_core_setup_remote)"

	limactl start "$vm"
	dvm_log "running core setup in $vm"
	limactl shell "$vm" bash -c "$remote" dvm-setup "$name" "$DVM_CODE_DIR" "$DVM_PACKAGES"
	dvm_sync_dotfiles "$vm"

	for script in $DVM_SETUP_SCRIPTS; do
		[ -n "$script" ] || continue
		[ -f "$script" ] || dvm_die "setup script not found: $script"
		dvm_log "running user setup in $vm: $script"
		limactl shell "$vm" env \
			"DVM_NAME=$name" \
			"DVM_VM_NAME=$vm" \
			"DVM_CODE_DIR=$DVM_CODE_DIR" \
			"DVM_DOTFILES_TARGET=$DVM_DOTFILES_TARGET" \
			bash -s <"$script"
	done
}

dvm_setup_all_finish() {
	local name pid status_dir rc
	name="$1"
	pid="$2"
	status_dir="$3"
	if wait "$pid"; then
		rc="0"
	else
		rc="$?"
	fi
	if [ -s "$status_dir/$name.out" ]; then
		sed "s/^/[$name] /" "$status_dir/$name.out"
	fi
	if [ -s "$status_dir/$name.err" ]; then
		sed "s/^/[$name] /" "$status_dir/$name.err" >&2
	fi
	return "$rc"
}

dvm_setup_all() {
	local active failed failed_names jobs name status_dir total
	local -a names pids
	[ "$#" -eq 0 ] || dvm_die "usage: dvm setup-all"
	dvm_load_config
	jobs="$DVM_SETUP_ALL_JOBS"
	status_dir="$(mktemp -d)"
	active="0"
	failed="0"
	failed_names=""
	total="0"
	names=()
	pids=()

	for name in $(dvm_list_names); do
		total=$((total + 1))
		(
			dvm_setup "$name"
		) >"$status_dir/$name.out" 2>"$status_dir/$name.err" &
		names+=("$name")
		pids+=("$!")
		active=$((active + 1))

		if [ "$active" -ge "$jobs" ]; then
			if ! dvm_setup_all_finish "${names[0]}" "${pids[0]}" "$status_dir"; then
				failed=$((failed + 1))
				failed_names="$failed_names ${names[0]}"
			fi
			names=("${names[@]:1}")
			pids=("${pids[@]:1}")
			active=$((active - 1))
		fi
	done

	while [ "$active" -gt 0 ]; do
		if ! dvm_setup_all_finish "${names[0]}" "${pids[0]}" "$status_dir"; then
			failed=$((failed + 1))
			failed_names="$failed_names ${names[0]}"
		fi
		names=("${names[@]:1}")
		pids=("${pids[@]:1}")
		active=$((active - 1))
	done

	rm -rf "$status_dir"
	if [ "$total" -eq 0 ]; then
		dvm_log "setup-all complete: no VMs found"
	elif [ "$failed" -eq 0 ]; then
		dvm_log "setup-all complete: $total succeeded"
	else
		dvm_warn "setup-all failed for $failed of $total:$failed_names"
		return 1
	fi
}

dvm_enter() {
	local name vm quoted_dir remote
	[ "$#" -eq 1 ] || dvm_die "usage: dvm enter <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_config
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	quoted_dir="$(dvm_quote "$DVM_CODE_DIR")"
	remote="mkdir -p $quoted_dir; cd $quoted_dir; exec \${SHELL:-/bin/bash} -l"
	limactl shell "$vm" bash -lc "$remote"
}

dvm_ssh() {
	local name vm
	[ "$#" -ge 1 ] || dvm_die "usage: dvm ssh <name> [command...]"
	name="$1"
	shift
	dvm_validate_name "$name"
	dvm_load_config
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	limactl shell "$vm" "$@"
}

dvm_key() {
	local name vm remote
	[ "$#" -eq 1 ] || dvm_die "usage: dvm key <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_config
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"
	remote="cat \"\$HOME/.ssh/id_ed25519_$name.pub\""
	dvm_log "public key for $name:"
	limactl shell "$vm" bash -lc "$remote"
}

dvm_dirty_check_remote() {
	cat <<'REMOTE'
set -euo pipefail
code_dir="$1"
dirty=0

if ! command -v git >/dev/null 2>&1; then
	echo "git is not installed; cannot verify clean repositories" >&2
	exit 2
fi

[ -d "$code_dir" ] || exit 0

while IFS= read -r gitdir; do
	repo="${gitdir%/.git}"
	if ! git -C "$repo" diff --quiet ||
		! git -C "$repo" diff --cached --quiet ||
		[ -n "$(git -C "$repo" ls-files --others --exclude-standard)" ]; then
		echo "dirty repository: $repo" >&2
		dirty=1
	fi
done < <(
	find "$code_dir" \
		\( -type d -name .git -prune -print \) -o \
		\( -type f -name .git -print \)
)

exit "$dirty"
REMOTE
}

dvm_rm() {
	local force name vm remote meta_file primary_fpr subkey_fpr
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
	dvm_load_config
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"

	if [ "$force" != "1" ]; then
		remote="$(dvm_dirty_check_remote)"
		limactl start "$vm"
		if ! limactl shell "$vm" bash -c "$remote" dvm-dirty-check "$DVM_CODE_DIR"; then
			dvm_die "refusing to delete $vm; commit/stash changes or pass --force"
		fi
	fi

	limactl delete --force "$vm"

	meta_file="$DVM_GPG_DIR/$name.env"
	if [ -f "$meta_file" ]; then
		PRIMARY_FPR=""
		SUBKEY_FPR=""
		# shellcheck source=/dev/null
		source "$meta_file"
		primary_fpr="${PRIMARY_FPR:-}"
		subkey_fpr="${SUBKEY_FPR:-}"
		if [ -n "$subkey_fpr" ]; then
			dvm_warn "GPG signing subkey still exists for $name: $subkey_fpr"
			if [ -n "$primary_fpr" ]; then
				dvm_warn "primary key: $primary_fpr"
			fi
			dvm_warn "revoke it when this VM should no longer sign: dvm gpg revoke $name"
		fi
	fi
}
