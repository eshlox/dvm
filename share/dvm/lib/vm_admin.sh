# shellcheck shell=bash

dirty_check_vm() {
	start_vm >/dev/null
	limactl shell "$DVM_LIMA_NAME" bash -s -- "$DVM_CODE_DIR" <<'DVM_DIRTY_CHECK'
set -euo pipefail
code_dir="$1"
case "$code_dir" in
	"~") code_dir="$HOME" ;;
	"~/"*) code_dir="$HOME/${code_dir#\~/}" ;;
esac
[ -d "$code_dir" ] || exit 0
if ! command -v git >/dev/null 2>&1; then
	printf 'dvm: dirty check skipped: git not installed in VM\n' >&2
	exit 2
fi
dirty=0
while IFS= read -r git_entry; do
	if [ -d "$git_entry" ]; then
		repo="${git_entry%/.git}"
	else
		repo="$(dirname "$git_entry")"
	fi
	if ! git -C "$repo" diff --quiet ||
		! git -C "$repo" diff --cached --quiet ||
		[ -n "$(git -C "$repo" ls-files --others --exclude-standard)" ]; then
		printf 'dirty repository: %s\n' "$repo" >&2
		dirty=1
	fi
done < <(find "$code_dir" \( -type d -name .git -prune -print \) -o \( -type f -name .git -print \))

orphan_count=0
orphan_sample=()
while IFS= read -r f; do
	orphan_count=$((orphan_count + 1))
	if [ "${#orphan_sample[@]}" -lt 5 ]; then
		orphan_sample+=("$f")
	fi
done < <(find "$code_dir" \
	\( -type d -exec test -e {}/.git \; -prune \) -o \
	\( -type d -name .git -prune \) -o \
	\( -type f -print \) 2>/dev/null)

if [ "$orphan_count" -gt 0 ]; then
	printf 'dvm: %d file(s) outside any git repository under %s:\n' "$orphan_count" "$code_dir" >&2
	for f in "${orphan_sample[@]}"; do
		printf '  %s\n' "$f" >&2
	done
	if [ "$orphan_count" -gt "${#orphan_sample[@]}" ]; then
		printf '  ... (%d more)\n' "$((orphan_count - ${#orphan_sample[@]}))" >&2
	fi
	dirty=1
fi
exit "$dirty"
DVM_DIRTY_CHECK
}

list_vms() {
	limactl list | awk '
		NR == 1 {
			printf "%-16s %-10s %-18s %-7s %-9s %-9s %s\n", $1, $2, $3, $4, $5, $6, $7
			next
		}
		$1 ~ /^dvm-/ {
			sub(/^dvm-/, "", $1)
			printf "%-16s %-10s %-18s %-7s %-9s %-9s %s\n", $1, $2, $3, $4, $5, $6, $7
		}
	'
}

stop_vm() {
	local name
	name="${1:-}"
	[ -n "$name" ] || die "stop requires a VM name"
	load_vm "$name"
	vm_exists || die "VM does not exist: $DVM_LIMA_NAME"
	limactl stop "$DVM_LIMA_NAME"
}

rm_vm() {
	local force name orphan vm_file yes
	name="${1:-}"
	[ -n "$name" ] || die "rm requires a VM name"
	shift || true
	force=0
	orphan=0
	yes=0
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--yes) yes=1 ;;
		--force | -f) force=1 ;;
		*) die "unknown rm option: $1" ;;
		esac
		shift
	done
	[ "$yes" = "1" ] || die "rm requires --yes"
	name="$(public_vm_name "$name")"
	vm_file="$DVM_CONFIG/vms/$name.sh"
	if [ -f "$vm_file" ]; then
		load_vm "$name"
	else
		DVM_LIMA_NAME="dvm-$name"
		if vm_exists; then
			orphan=1
			printf 'dvm: warning: deleting Lima VM without DVM config: %s (missing %s)\n' "$DVM_LIMA_NAME" "$vm_file" >&2
		fi
	fi
	if [ "$force" != "1" ] && vm_exists && [ -f "$vm_file" ]; then
		local rc=0
		dirty_check_vm || rc=$?
		case "$rc" in
		0) ;;
		1) die "refusing to delete $DVM_LIMA_NAME; commit/stash changes, move untracked files, or pass --force" ;;
		2) die "refusing to delete $DVM_LIMA_NAME; dirty check incomplete (see warning above), pass --force to skip" ;;
		*) die "refusing to delete $DVM_LIMA_NAME; dirty check failed with status $rc, pass --force to skip" ;;
		esac
	elif [ "$force" != "1" ] && [ "$orphan" = "1" ]; then
		printf 'dvm: warning: dirty check skipped because DVM config is missing: %s\n' "$vm_file" >&2
	fi
	limactl stop "$DVM_LIMA_NAME" >/dev/null 2>&1 || true
	limactl delete "$DVM_LIMA_NAME"
}
