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

start_existing_vm() {
	local name="$1"
	load_vm "$name"
	vm_exists || die "VM does not exist: $DVM_LIMA_NAME; run dvm sync $name first"
	start_vm
}

require_existing_vm() {
	load_vm "$1"
	vm_exists || die "VM does not exist: $DVM_LIMA_NAME"
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
		update_port_forwards
	fi
	start_vm
}
