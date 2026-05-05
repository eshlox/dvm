# shellcheck shell=bash
# shellcheck disable=SC2034

vm_dir() {
	local dir name
	while IFS=$'\t' read -r name dir _; do
		if [ "$name" = "$DVM_LIMA_NAME" ]; then
			printf '%s\n' "${dir:-${LIMA_HOME:-$HOME/.lima}/$DVM_LIMA_NAME}"
			return 0
		fi
	done < <(limactl list --format '{{.Name}}	{{.Dir}}' 2>/dev/null || true)
	printf '%s\n' "${LIMA_HOME:-$HOME/.lima}/$DVM_LIMA_NAME"
}

update_port_forwards() {
	local actual desired dir expr
	dir="$(vm_dir)"
	desired="$(configured_ports_canonical | paste -sd' ' -)"
	actual="$(ports_canonical_from_yaml "$dir/lima.yaml" | paste -sd' ' -)"
	[ "$desired" = "$actual" ] && return 0
	printf 'dvm: updating port forwards for %s\n' "$DVM_LIMA_NAME" >&2
	expr="$(port_set_expr)"
	limactl stop "$DVM_LIMA_NAME" >/dev/null 2>&1 || true
	limactl edit --tty=false --set "$expr" --start "$DVM_LIMA_NAME" >/dev/null
}

lima_yaml_scalar() {
	local file="$1"
	local key="$2"
	[ -f "$file" ] || return 0
	awk -v key="$key" '
		$0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
			value = $0
			sub("^[[:space:]]*" key ":[[:space:]]*", "", value)
			sub("[[:space:]]*#.*$", "", value)
			gsub(/"/, "", value)
			gsub(/\047/, "", value)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
			print value
			exit
		}
	' "$file"
}

lima_size_gib() {
	local converted label value
	label="$1"
	value="$2"
	if ! converted="$(
		awk -v value="$value" '
			BEGIN {
				gsub(/^"|"$/, "", value)
				if (value !~ /^[0-9]+([.][0-9]+)?([A-Za-z]*)$/) exit 1
				number = value + 0
				unit = value
				sub(/^[0-9]+([.][0-9]+)?/, "", unit)
				unit = tolower(unit)
				if (unit == "" || unit == "g" || unit == "gb" || unit == "gib") factor = 1
				else if (unit == "m" || unit == "mb" || unit == "mib") factor = 1 / 1024
				else if (unit == "k" || unit == "kb" || unit == "kib") factor = 1 / (1024 * 1024)
				else if (unit == "t" || unit == "tb" || unit == "tib") factor = 1024
				else if (unit == "b") factor = 1 / (1024 * 1024 * 1024)
				else exit 1
				printf "%.6g\n", number * factor
			}
		'
	)"; then
		die "invalid $label size for Lima edit: $value"
	fi
	printf '%s\n' "$converted"
}

lima_size_gib_or_empty() {
	case "$2" in
	'' | null) return 0 ;;
	esac
	lima_size_gib "$1" "$2"
}

lima_float_equal() {
	awk -v a="$1" -v b="$2" 'BEGIN { d = a - b; if (d < 0) d = -d; exit(d <= 0.000001 ? 0 : 1) }'
}

lima_float_less() {
	awk -v a="$1" -v b="$2" 'BEGIN { exit((a + 0) < (b + 0) - 0.000001 ? 0 : 1) }'
}

update_vm_resources() {
	local changed current_cpus current_disk current_disk_gib current_memory
	local current_memory_gib desired_disk_gib desired_memory_gib dir file
	dir="$(vm_dir)"
	file="$dir/lima.yaml"
	[ -f "$file" ] || return 0

	current_cpus="$(lima_yaml_scalar "$file" cpus)"
	current_memory="$(lima_yaml_scalar "$file" memory)"
	current_disk="$(lima_yaml_scalar "$file" disk)"
	desired_memory_gib="$(lima_size_gib DVM_MEMORY "$DVM_MEMORY")"
	desired_disk_gib="$(lima_size_gib DVM_DISK "$DVM_DISK")"
	current_memory_gib="$(lima_size_gib_or_empty memory "$current_memory")"
	current_disk_gib="$(lima_size_gib_or_empty disk "$current_disk")"

	if [ -n "$current_disk_gib" ] && lima_float_less "$desired_disk_gib" "$current_disk_gib"; then
		die "refusing to shrink DVM_DISK for $DVM_LIMA_NAME from $current_disk to $DVM_DISK; create a backup and recreate the VM instead"
	fi

	changed=0
	[ "$current_cpus" = "$DVM_CPUS" ] || changed=1
	if [ -z "$current_memory_gib" ] || ! lima_float_equal "$desired_memory_gib" "$current_memory_gib"; then
		changed=1
	fi
	if [ -z "$current_disk_gib" ] || ! lima_float_equal "$desired_disk_gib" "$current_disk_gib"; then
		changed=1
	fi
	[ "$changed" = "1" ] || return 0

	printf 'dvm: updating VM resources for %s\n' "$DVM_LIMA_NAME" >&2
	limactl stop "$DVM_LIMA_NAME" >/dev/null 2>&1 || true
	limactl edit --tty=false --cpus "$DVM_CPUS" --memory "$desired_memory_gib" --disk "$desired_disk_gib" "$DVM_LIMA_NAME" >/dev/null
}

render_template() {
	local template="$1"
	if command -v envsubst >/dev/null 2>&1; then
		envsubst <"$template"
	else
		perl -pe 's/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/exists $ENV{$1} ? $ENV{$1} : $&/ge' "$template"
	fi
}

vm_exists() {
	vm_listed || vm_local_config_exists
}

vm_listed() {
	limactl list --format '{{.Name}}' 2>/dev/null | grep -Fxq "$DVM_LIMA_NAME"
}

vm_local_config_exists() {
	[ -f "${LIMA_HOME:-$HOME/.lima}/$DVM_LIMA_NAME/lima.yaml" ]
}

start_vm() {
	if limactl start "$DVM_LIMA_NAME"; then
		return 0
	fi
	if ! vm_listed && vm_local_config_exists; then
		die "Lima instance directory exists but limactl cannot start $DVM_LIMA_NAME; inspect or remove ${LIMA_HOME:-$HOME/.lima}/$DVM_LIMA_NAME"
	fi
	return 1
}

ensure_vm() {
	local create_output template tmp tmp_dir
	if ! vm_exists; then
		template="$DVM_CONFIG/lima.yaml.in"
		[ -f "$template" ] || template="$DVM_SHARE/lima.yaml.in"
		[ -f "$template" ] || die "missing Lima template"
		tmp_dir="${TMPDIR:-/tmp}"
		tmp="$(mktemp "${tmp_dir%/}/dvm-lima.XXXXXX")"
		DVM_PORT_FORWARDS_YAML="$(render_ports)"
		export DVM_NAME DVM_LIMA_NAME DVM_ARCH DVM_CPUS DVM_MEMORY DVM_DISK
		export DVM_USER DVM_CODE_DIR DVM_PORT_FORWARDS_YAML
		render_template "$template" >"$tmp"
		if ! create_output="$(limactl create --name "$DVM_LIMA_NAME" --tty=false "$tmp" 2>&1)"; then
			rm -f "$tmp"
			case "$create_output" in
			*"already exists"*)
				update_vm_resources
				update_port_forwards
				;;
			*)
				printf '%s\n' "$create_output" >&2
				return 1
				;;
			esac
		else
			rm -f "$tmp"
		fi
	else
		update_vm_resources
		update_port_forwards
	fi
	start_vm
}
