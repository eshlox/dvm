# shellcheck shell=bash
# shellcheck disable=SC2016

guest_cd_script='
set -euo pipefail
code_dir="$1"
shift
case "$code_dir" in
	"~") code_dir="$HOME" ;;
	"~/"*) code_dir="$HOME/${code_dir#\~/}" ;;
esac
case "${TERM:-}" in
	xterm-ghostty|ghostty) export TERM=xterm-256color ;;
	""|dumb) ;;
	*)
		if command -v infocmp >/dev/null 2>&1 && ! infocmp "$TERM" >/dev/null 2>&1; then
			export TERM=xterm-256color
		fi
		;;
esac
mkdir -p "$code_dir"
cd "$code_dir"
if [ "$#" -eq 0 ]; then
	login_shell="$(getent passwd "$(id -un)" | cut -d: -f7 || true)"
	[ -n "$login_shell" ] || login_shell="${SHELL:-/bin/bash}"
	export SHELL="$login_shell"
	exec "$login_shell" -l
fi
exec "$@"
'

enter_vm() {
	ssh_vm "$1"
}

ssh_vm() {
	local name="$1"
	local term
	shift || true
	[ "${1:-}" != "--" ] || shift
	start_existing_vm "$name"
	term="$(guest_term)"
	restore_host_tty_on_exit
	limactl shell "$DVM_LIMA_NAME" env "TERM=$term" bash -c "$guest_cd_script" dvm-ssh "$DVM_CODE_DIR" "$@"
}

# Guest TUIs (zellij, nvim, fzf, ...) can leave xterm private modes enabled on
# the host terminal if they exit dirty. The leaked modes -- mouse tracking
# (1000/1002/1003 + SGR 1006), bracketed paste (2004), focus reporting (1004)
# -- make the host terminal print garbage on every keypress or pointer event.
# Send the disable sequences and stty sane on the way out so the host shell
# always lands on a clean tty.
restore_host_tty_on_exit() {
	[ -t 2 ] || return 0
	trap '
		printf "\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?2004l\e[?1004l" >&2
		stty sane 2>/dev/null || true
	' EXIT INT TERM HUP
}

guest_home_dir() {
	printf '/home/%s\n' "$DVM_USER"
}

guest_code_dir_abs() {
	local code_dir home
	home="$(guest_home_dir)"
	code_dir="${DVM_CODE_DIR%/}"
	case "$code_dir" in
	'') printf '/\n' ;;
	"~") printf '%s\n' "$home" ;;
	\~/*) printf '%s/%s\n' "$home" "${code_dir#\~/}" ;;
	/*) printf '%s\n' "$code_dir" ;;
	*) printf '%s/%s\n' "$home" "$code_dir" ;;
	esac
}

guest_cp_path() {
	local code_dir home path
	path="$1"
	home="$(guest_home_dir)"
	code_dir="$(guest_code_dir_abs)"
	case "$path" in
	'' | '.') printf '%s\n' "$code_dir" ;;
	"./"*) printf '%s/%s\n' "$code_dir" "${path#./}" ;;
	/*) printf '%s\n' "$path" ;;
	"~") printf '%s\n' "$home" ;;
	\~/*) printf '%s/%s\n' "$home" "${path#\~/}" ;;
	*) printf '%s/%s\n' "$code_dir" "$path" ;;
	esac
}

cp_fix_agent_acl() {
	local target="$1"
	shift || true
	limactl shell "$DVM_LIMA_NAME" bash -s -- "$DVM_AI_AGENT_USER" "$DVM_USER" "$(guest_home_dir)" "$(guest_code_dir_abs)" "$target" "$@" <<'SCRIPT'
set -euo pipefail

agent_user="$1"
vm_user="$2"
guest_home="$3"
code_dir="$4"
target="$5"
shift 5

command -v realpath >/dev/null 2>&1 || exit 0
code_dir="$(realpath -m "$code_dir")" || exit 0
target="$(realpath -m "$target")" || exit 0
case "$target" in
"$code_dir" | "$code_dir"/*) ;;
*) exit 0 ;;
esac
id -u "$agent_user" >/dev/null 2>&1 || exit 0
id -u "$vm_user" >/dev/null 2>&1 || vm_user=""
command -v setfacl >/dev/null 2>&1 || exit 0

if [ -d "$guest_home" ]; then
	sudo setfacl -m "u:$agent_user:--x" "$guest_home" || true
fi
code_parent="$(dirname "$code_dir")"
if [ -d "$code_parent" ] && [ "$code_parent" != "/" ]; then
	sudo setfacl -m "u:$agent_user:--x" "$code_parent" || true
fi
if [ -d "$code_dir" ]; then
	sudo setfacl -m "u:$agent_user:rwx" "$code_dir" || true
	[ -z "$vm_user" ] || sudo setfacl -m "u:$vm_user:rwx" "$code_dir" || true
	sudo setfacl -d -m "u:$agent_user:rwx" "$code_dir" || true
	[ -z "$vm_user" ] || sudo setfacl -d -m "u:$vm_user:rwx" "$code_dir" || true
fi

grant_dir_defaults() {
	[ -d "$1" ] || return 0
	case "$1" in
	"$code_dir" | "$code_dir"/*) ;;
	*) return 0 ;;
	esac
	sudo setfacl -d -m "u:$agent_user:rwx" "$1" || true
	[ -z "$vm_user" ] || sudo setfacl -d -m "u:$vm_user:rwx" "$1" || true
}

grant_path() {
	[ -e "$1" ] || return 0
	sudo setfacl -R -m "u:$agent_user:rwx" "$1" || true
	[ -z "$vm_user" ] || sudo setfacl -R -m "u:$vm_user:rwx" "$1" || true
	if [ -d "$1" ]; then
		sudo find "$1" -type d -exec setfacl -d -m "u:$agent_user:rwx" {} + || true
		[ -z "$vm_user" ] || sudo find "$1" -type d -exec setfacl -d -m "u:$vm_user:rwx" {} + || true
	else
		grant_dir_defaults "$(dirname "$1")"
	fi
}

if [ -d "$target" ]; then
	grant_dir_defaults "$target"
else
	grant_dir_defaults "$(dirname "$target")"
fi

if [ "$#" -eq 0 ] || [ ! -d "$target" ]; then
	grant_path "$target"
	exit 0
fi

for name in "$@"; do
	case "$name" in
	'' | '.' | '..' | */*) continue ;;
	esac
	grant_path "$target/$name"
done
SCRIPT
}

cp_vm() {
	local acl_name_count arg base copy_into_vm endpoint_count endpoint_name guest_target
	local i name opts_count path source_count target_arg vm_name
	local -a acl_names operands opts rewritten
	acl_names=()
	operands=()
	opts=()
	rewritten=()
	acl_name_count=0
	copy_into_vm=0
	opts_count=0
	vm_name=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--)
			shift
			while [ "$#" -gt 0 ]; do
				operands+=("$1")
				shift
			done
			;;
		-r | --recursive | -v | --verbose)
			opts+=("$1")
			opts_count=$((opts_count + 1))
			;;
		--backend=*)
			opts+=("$1")
			opts_count=$((opts_count + 1))
			;;
		--backend)
			[ "$#" -gt 1 ] || die "cp --backend requires a value"
			opts+=("$1" "$2")
			opts_count=$((opts_count + 2))
			shift
			;;
		-*) die "unknown cp option: $1" ;;
		*) operands+=("$1") ;;
		esac
		shift || true
	done
	[ "${#operands[@]}" -ge 2 ] || die "cp requires a source and target"

	endpoint_count=0
	for arg in "${operands[@]}"; do
		case "$arg" in
		*:*)
			name="${arg%%:*}"
			if endpoint_name="$(dvm_endpoint_name "$name")"; then
				endpoint_count=$((endpoint_count + 1))
				if [ -n "$vm_name" ] && [ "$vm_name" != "$endpoint_name" ]; then
					die "cp can only address one VM at a time"
				fi
				vm_name="$endpoint_name"
			fi
			;;
		esac
	done
	[ "$endpoint_count" -gt 0 ] || die "cp requires one side to use name:path"
	[ "$endpoint_count" -lt "${#operands[@]}" ] || die "cp requires one host path and one VM path"

	start_existing_vm "$vm_name"
	limactl shell "$DVM_LIMA_NAME" mkdir -p "$(guest_code_dir_abs)"

	target_arg="${operands[$((${#operands[@]} - 1))]}"
	case "$target_arg" in
	*:*)
		name="${target_arg%%:*}"
		if endpoint_name="$(dvm_endpoint_name "$name")"; then
			copy_into_vm=1
			guest_target="$(guest_cp_path "${target_arg#*:}")"
			source_count=$((${#operands[@]} - 1))
			i=0
			while [ "$i" -lt "$source_count" ]; do
				arg="${operands[$i]}"
				base="${arg%/}"
				base="${base##*/}"
				if [ -n "$base" ]; then
					acl_names+=("$base")
					acl_name_count=$((acl_name_count + 1))
				fi
				i=$((i + 1))
			done
		fi
		;;
	esac

	for arg in "${operands[@]}"; do
		case "$arg" in
		*:*)
			name="${arg%%:*}"
			if endpoint_name="$(dvm_endpoint_name "$name")"; then
				path="${arg#*:}"
				rewritten+=("$DVM_LIMA_NAME:$(guest_cp_path "$path")")
			else
				rewritten+=("$arg")
			fi
			;;
		*) rewritten+=("$arg") ;;
		esac
	done
	if [ "$opts_count" -gt 0 ]; then
		limactl copy "${opts[@]}" "${rewritten[@]}"
	else
		limactl copy "${rewritten[@]}"
	fi
	if [ "$copy_into_vm" = "1" ]; then
		if [ "$acl_name_count" -gt 0 ]; then
			cp_fix_agent_acl "$guest_target" "${acl_names[@]}"
		else
			cp_fix_agent_acl "$guest_target"
		fi
	fi
}

default_log_unit() {
	local recipe count unit
	count=0
	unit=""
	if [ "${#DVM_RECIPES[@]}" -gt 0 ]; then
		for recipe in "${DVM_RECIPES[@]}"; do
			case "$recipe" in
			cloudflared)
				unit="$DVM_CLOUDFLARED_SERVICE"
				count=$((count + 1))
				;;
			llama)
				unit="$DVM_LLAMA_SERVICE"
				count=$((count + 1))
				;;
			tailscale)
				unit="tailscaled.service"
				count=$((count + 1))
				;;
			esac
		done
	fi
	[ "$count" -eq 1 ] || return 1
	printf '%s\n' "$unit"
}

logs_vm() {
	local name unit
	name="${1:-}"
	[ -n "$name" ] || die "log requires a VM name"
	shift || true
	start_existing_vm "$name"
	if [ "$#" -gt 0 ]; then
		case "$1" in
		-*) unit="$(default_log_unit)" || die "log requires a unit when the VM has zero or multiple known service recipes" ;;
		*)
			unit="$1"
			shift
			;;
		esac
	else
		unit="$(default_log_unit)" || die "log requires a unit when the VM has zero or multiple known service recipes"
	fi
	if [ "$#" -eq 0 ]; then
		set -- --no-pager -n 100
	fi
	limactl shell "$DVM_LIMA_NAME" sudo journalctl -u "$unit" "$@"
}
