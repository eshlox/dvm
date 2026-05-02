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

dvm_lima_row() {
	local row_dir row_status row_vm vm
	vm="$1"
	while IFS=$'\t' read -r row_vm row_status row_dir _; do
		[ "$row_vm" = "$vm" ] || continue
		printf '%s\t%s\t%s\n' "$row_vm" "${row_status:-unknown}" "${row_dir:-${LIMA_HOME:-$HOME/.lima}/$vm}"
		return 0
	done < <(dvm_lima_rows)
	return 1
}

dvm_vm_exists() {
	local vm
	vm="$1"
	dvm_lima_names | grep -Fxq "$vm"
}

dvm_vm_dir() {
	local dir row_vm status vm
	vm="$1"
	if IFS=$'\t' read -r row_vm status dir < <(dvm_lima_row "$vm"); then
		printf '%s\n' "${dir:-${LIMA_HOME:-$HOME/.lima}/$vm}"
		return 0
	fi
	printf '%s\n' "${LIMA_HOME:-$HOME/.lima}/$vm"
}

dvm_vm_ports_from_yaml_parse() {
	local file mode
	file="$1/lima.yaml"
	mode="$2"
	[ -f "$file" ] || return 0
	awk -v mode="$mode" '
		function reset() {
			host = ""
			host_ip = ""
			guest = ""
			ignore = ""
		}
		function value(line, key, tmp) {
			tmp = line
			gsub(/"/, "", tmp)
			sub("^.*" key ":[[:space:]]*", "", tmp)
			sub("[[:space:]]*#.*$", "", tmp)
			sub("[[:space:]].*$", "", tmp)
			return tmp
		}
		function emit() {
			if (guest == "") {
				return
			}
			if (ignore == "true") {
				if (mode == "canonical") {
					print "ignore:" guest ":" guest
				}
				return
			}
			if (host != "") {
				if (mode == "canonical") {
					if (host_ip == "") {
						host_ip = "127.0.0.1"
					}
					print host_ip ":" host ":" guest
				} else {
					print host ":" guest
				}
			}
		}
		BEGIN {
			reset()
		}
		/^[[:space:]]*portForwards:/ {
			in_ports = 1
			next
		}
		in_ports && /^[^[:space:]-]/ {
			emit()
			reset()
			in_ports = 0
		}
		!in_ports {
			next
		}
		/^[[:space:]]*-/ {
			emit()
			reset()
		}
		/hostPort:[[:space:]]*/ {
			host = value($0, "hostPort")
		}
		/hostIP:[[:space:]]*/ {
			host_ip = value($0, "hostIP")
		}
		/guestPort:[[:space:]]*/ {
			guest = value($0, "guestPort")
		}
		/ignore:[[:space:]]*true/ {
			ignore = "true"
		}
		END {
			if (in_ports) {
				emit()
			}
		}
	' "$file"
}

dvm_vm_ports_from_yaml() {
	local ports
	ports="$(dvm_vm_ports_from_yaml_parse "$1" display | paste -sd, -)"
	printf '%s\n' "${ports:-"-"}"
}

dvm_vm_ports_canonical_from_yaml() {
	dvm_vm_ports_from_yaml_parse "$1" canonical | sort
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
		if [ -d "$dir" ]; then
			size="$(du -sh "$dir" 2>/dev/null | awk '{print $1}')" || size="-"
		fi
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
	{
		printf 'ignore:5355:5355\n'
		for port in $DVM_PORTS; do
			dvm_validate_port "$port"
			printf '%s:%s\n' "$DVM_HOST_IP" "$port"
		done
	} | sort
}

dvm_port_forwards_set_expr() {
	local expr guest host host_ip port
	expr='.portForwards = [{"guestPort":5355,"proto":"any","ignore":true}'
	host_ip="$(dvm_json "$DVM_HOST_IP")"
	for port in $DVM_PORTS; do
		dvm_validate_port "$port"
		host="${port%%:*}"
		guest="${port#*:}"
		expr="$expr,{\"hostPort\":$host,\"guestPort\":$guest,\"hostIP\":$host_ip,\"static\":true}"
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
	if ! limactl stop "$vm" >/dev/null 2>&1; then
		dvm_warn "could not stop $vm before editing port forwards; continuing"
	fi
	limactl edit --tty=false --set "$expr" --start "$vm" >/dev/null
}

dvm_create() {
	local name network_set vm
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
			--set "$(dvm_port_forwards_set_expr)" \
			--set ".containerd.system=false | .containerd.user=false"
		limactl "$@" "$DVM_TEMPLATE"
	fi
	dvm_setup "$name"
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
	# Recipes are trusted setup code; expose every DVM_* value, including secrets.
	while IFS= read -r var; do
		dvm_env_args+=("$var=${!var}")
	done < <(compgen -v DVM_ | sort)
}

dvm_stream_setup_script() {
	local fragment script
	script="$1"
	if [ -f "$DVM_CORE/recipes/_lib.sh" ]; then
		cat "$DVM_CORE/recipes/_lib.sh"
	fi
	if [ "$script" = "$DVM_CORE/recipes/ai.sh" ]; then
		for fragment in _ai-common.sh _ai-claude.sh _ai-codex.sh _ai-opencode.sh _ai-mistral.sh; do
			fragment="$DVM_CORE/recipes/$fragment"
			[ -f "$fragment" ] || dvm_die "internal AI recipe fragment missing: $fragment"
			cat "$fragment"
		done
	fi
	cat "$script"
}

dvm_run_setup_script() {
	local script vm
	vm="$1"
	script="$(dvm_recipe_path "$2")"
	[ -f "$script" ] || dvm_die "setup script not found: $script"
	dvm_log "running setup script: $script"
	dvm_build_env_args
	dvm_stream_setup_script "$script" | limactl shell "$vm" env "${dvm_env_args[@]}" bash -s
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

dvm_dotfiles_remote_script() {
	cat <<'REMOTE'
set -euo pipefail
target="$1"
home="$2"
case "$target" in
"$home"/*) ;;
*) echo "unsafe DVM_DOTFILES_TARGET: $target" >&2; exit 1 ;;
esac
case "$target" in
"$home" | "$home/.ssh" | "$home/.ssh/"* | "$home/.gnupg" | "$home/.gnupg/"* | *..*)
	echo "unsafe DVM_DOTFILES_TARGET: $target" >&2
	exit 1
	;;
esac
parent="${target%/*}"
mkdir -p "$parent"
home_real="$(cd "$home" 2>/dev/null && pwd -P)" || {
	echo "unsafe DVM_GUEST_HOME: $home" >&2
	exit 1
}
parent_real="$(cd "$parent" 2>/dev/null && pwd -P)" || {
	echo "unsafe DVM_DOTFILES_TARGET parent: $parent" >&2
	exit 1
}
case "$parent_real" in
"$home_real" | "$home_real"/*) ;;
*) echo "unsafe DVM_DOTFILES_TARGET parent: $parent" >&2; exit 1 ;;
esac
rm -rf "$target"
mkdir -p "$target"
set -- tar -C "$target"
if tar --help 2>/dev/null | grep -q -- "--warning="; then
	set -- "$@" --warning=no-unknown-keyword
fi
set -- "$@" -xf -
"$@"
REMOTE
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
	"$DVM_GUEST_HOME" | "$DVM_GUEST_HOME/.ssh" | "$DVM_GUEST_HOME/.ssh/"* | "$DVM_GUEST_HOME/.gnupg" | "$DVM_GUEST_HOME/.gnupg/"* | *..*)
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
	) | limactl shell "$vm" \
		bash -c "$(dvm_dotfiles_remote_script)" dvm-dotfiles "$target" "$DVM_GUEST_HOME"
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
	limactl shell "$vm" mkdir -p "$DVM_CODE_DIR"
	dvm_sync_dotfiles "$vm"
	for script in $DVM_SETUP_SCRIPTS; do
		dvm_run_setup_script "$vm" "$script"
	done
	dvm_run_inline_setup "$vm"
}

dvm_setup_all() {
	[ "$#" -eq 0 ] || dvm_die "usage: dvm setup-all"
	dvm_run_for_all setup
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
	[ "$#" -eq 0 ] || dvm_die "usage: dvm upgrade-all"
	dvm_run_for_all upgrade
}

dvm_run_for_all() {
	local action failed failures name ok total
	action="$1"
	failed="0"
	failures=()
	ok="0"
	total="0"
	dvm_load_defaults
	for name in $(dvm_list_names); do
		total=$((total + 1))
		if "$DVM_CORE/bin/dvm" "$action" "$name"; then
			ok=$((ok + 1))
		else
			failed="1"
			failures+=("$name")
			dvm_warn "$action failed: $name"
		fi
	done
	if [ "$failed" = "1" ]; then
		dvm_warn "$action-all: $ok/$total succeeded; failed: ${failures[*]}"
		return 1
	fi
	dvm_log "$action-all: $ok/$total succeeded"
}

dvm_guest_term() {
	printf '%s\n' "${DVM_GUEST_TERM:-${TERM:-xterm-256color}}"
}

dvm_lima_shell() {
	local remote vm
	vm="$1"
	shift
	# Expands inside the VM.
	# shellcheck disable=SC2016
	remote='if [ -n "${DVM_HOST_TERM:-}" ] && infocmp "$DVM_HOST_TERM" >/dev/null 2>&1; then export TERM="$DVM_HOST_TERM"; else export TERM=xterm-256color; fi; exec "$@"'
	limactl shell "$vm" env \
		"DVM_HOST_TERM=$(dvm_guest_term)" \
		"COLORTERM=${COLORTERM:-}" \
		bash -lc "$remote" dvm-shell "$@"
}

dvm_enter() {
	local name quoted_dir vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm enter <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	vm="$(dvm_vm_name "$name")"
	quoted_dir="$(dvm_quote "$DVM_CODE_DIR")"
	dvm_lima_shell "$vm" bash -lc "mkdir -p $quoted_dir; cd $quoted_dir; exec \${SHELL:-/bin/bash} -l"
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
		dvm_lima_shell "$vm" bash -lc "mkdir -p $quoted_dir; cd $quoted_dir; exec \${SHELL:-/bin/bash} -l"
		return 0
	fi
	dvm_lima_shell "$vm" "$@"
}

dvm_ssh_key() {
	local name remote vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm ssh-key <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	vm="$(dvm_vm_name "$name")"
	# Expands inside the VM.
	# shellcheck disable=SC2016
	remote='
set -euo pipefail
key="$HOME/.ssh/id_ed25519_dvm"
config="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
[ -f "$key" ] || ssh-keygen -t ed25519 -C "$DVM_NAME-dvm" -f "$key" -N ""
touch "$config"
chmod 600 "$config"
if ! grep -Eq "^[[:space:]]*IdentityFile[[:space:]]+$key([[:space:]]|$)" "$config"; then
	{
		printf "\nHost github.com\n"
		printf "  HostName github.com\n"
		printf "  User git\n"
		printf "  IdentityFile %s\n" "$key"
		printf "  IdentitiesOnly yes\n"
		printf "  AddKeysToAgent no\n"
	} >>"$config"
fi
if command -v git >/dev/null 2>&1; then
	git_config="$HOME/.config/git/config"
	mkdir -p "$(dirname "$git_config")"
	GIT_CONFIG_GLOBAL="$git_config" git config --global gpg.format ssh
	GIT_CONFIG_GLOBAL="$git_config" git config --global user.signingkey "$key.pub"
	GIT_CONFIG_GLOBAL="$git_config" git config --global commit.gpgsign true
fi
cat "$key.pub"
'
	limactl shell "$vm" env "DVM_NAME=$name" bash -lc "$remote"
}

dvm_gpg_key() {
	local name remote vm
	[ "$#" -eq 1 ] || dvm_die "usage: dvm gpg-key <name>"
	name="$1"
	dvm_validate_name "$name"
	dvm_load_vm_config "$name"
	vm="$(dvm_vm_name "$name")"
	# Expands inside the VM.
	# VM-local convenience key; see SECURITY.md for the disposable-VM threat model.
	# shellcheck disable=SC2016
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
