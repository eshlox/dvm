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

dvm_create() {
	local name vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm new <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_config
	dvm_require limactl
	vm="$(dvm_vm_name "$name")"

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

dvm_validate_dotfiles_target() {
	local target
	target="$1"

	case "$target" in
	/*) ;;
	*) dvm_die "DVM_DOTFILES_TARGET must be an absolute path: $target" ;;
	esac

	case "$target" in
	"$DVM_GUEST_HOME")
		dvm_die "refusing unsafe DVM_DOTFILES_TARGET: $target"
		;;
	"$DVM_GUEST_HOME/.ssh" | "$DVM_GUEST_HOME/.ssh/"* | \
		"$DVM_GUEST_HOME/.gnupg" | "$DVM_GUEST_HOME/.gnupg/"*)
		dvm_die "refusing unsafe DVM_DOTFILES_TARGET: $target"
		;;
	"$DVM_GUEST_HOME"/*) ;;
	*) dvm_die "DVM_DOTFILES_TARGET must stay under DVM_GUEST_HOME: $target" ;;
	esac
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

	target="$DVM_DOTFILES_TARGET"
	dvm_validate_dotfiles_target "$target"

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

dvm_setup_all() {
	local name
	for name in $(dvm_list_names); do
		dvm_setup "$name"
	done
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
done < <(find "$code_dir" -mindepth 2 -maxdepth 5 -type d -name .git -prune)

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
