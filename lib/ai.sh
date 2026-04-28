#!/usr/bin/env bash
# shellcheck shell=bash

dvm_ai_usage() {
	cat <<'HELP'
usage:
  dvm ai create [name]
  dvm ai setup [name]
  dvm ai pull [--vm name] [model...]
  dvm ai models [name]
  dvm ai use [--vm name] <model>
  dvm ai status [name]
  dvm ai host [name]
HELP
}

dvm_ai_validate_token() {
	local label value
	label="$1"
	value="$2"
	case "$value" in
	'' | *[!A-Za-z0-9._/@:+-]*)
		dvm_die "invalid $label: $value"
		;;
	esac
}

dvm_ai_validate_model_alias() {
	local alias
	alias="$1"
	case "$alias" in
	'' | *[!A-Za-z0-9._-]* | .* | *..* | */*)
		dvm_die "invalid AI model alias: $alias"
		;;
	esac
}

dvm_ai_validate_url() {
	local url
	url="$1"
	case "$url" in
	http://* | https://*) ;;
	*) dvm_die "AI model URL must start with http:// or https://: $url" ;;
	esac
	case "$url" in
	*$'\n'* | *$'\r'* | *' '*)
		dvm_die "invalid AI model URL: $url"
		;;
	esac
}

dvm_ai_validate_config() {
	case "$DVM_AI_PORT" in
	'' | *[!0-9]*)
		dvm_die "invalid DVM_AI_PORT: $DVM_AI_PORT"
		;;
	esac

	dvm_ai_validate_token DVM_AI_SERVER_CMD "$DVM_AI_SERVER_CMD"
	dvm_ai_validate_token DVM_AI_SERVICE_NAME "$DVM_AI_SERVICE_NAME"
	dvm_ai_validate_token DVM_AI_SYSTEMD_DIR "$DVM_AI_SYSTEMD_DIR"
	dvm_ai_validate_token DVM_AI_HOST "$DVM_AI_HOST"
	dvm_ai_validate_token DVM_AI_MODELS_DIR "$DVM_AI_MODELS_DIR"
	dvm_ai_validate_token DVM_AI_CURRENT_MODEL "$DVM_AI_CURRENT_MODEL"

	case "$DVM_AI_MODELS_DIR" in
	/*) ;;
	*) dvm_die "DVM_AI_MODELS_DIR must be an absolute path: $DVM_AI_MODELS_DIR" ;;
	esac
	case "$DVM_AI_SYSTEMD_DIR" in
	/*) ;;
	*) dvm_die "DVM_AI_SYSTEMD_DIR must be an absolute path: $DVM_AI_SYSTEMD_DIR" ;;
	esac
	case "$DVM_AI_SERVICE_NAME" in
	*/*)
		dvm_die "DVM_AI_SERVICE_NAME must be a service name, not a path: $DVM_AI_SERVICE_NAME"
		;;
	esac
	case "$DVM_AI_CURRENT_MODEL" in
	"$DVM_AI_MODELS_DIR"/*) ;;
	*) dvm_die "DVM_AI_CURRENT_MODEL must stay under DVM_AI_MODELS_DIR: $DVM_AI_CURRENT_MODEL" ;;
	esac
	case "$DVM_AI_EXTRA_ARGS" in
	*$'\n'* | *$'\r'*)
		dvm_die "invalid DVM_AI_EXTRA_ARGS"
		;;
	esac
}

dvm_ai_model_filename() {
	local alias
	alias="$1"
	case "$alias" in
	*.gguf) printf '%s\n' "$alias" ;;
	*) printf '%s.gguf\n' "$alias" ;;
	esac
}

dvm_ai_model_url() {
	local alias spec spec_alias
	alias="$1"
	for spec in $DVM_AI_MODELS; do
		case "$spec" in
		*=*) ;;
		*) dvm_die "invalid DVM_AI_MODELS entry: $spec" ;;
		esac
		spec_alias="${spec%%=*}"
		if [ "$spec_alias" = "$alias" ]; then
			printf '%s\n' "${spec#*=}"
			return 0
		fi
	done
	return 1
}

dvm_ai_first_model_alias() {
	local spec
	for spec in $DVM_AI_MODELS; do
		case "$spec" in
		*=*)
			printf '%s\n' "${spec%%=*}"
			return 0
			;;
		*) dvm_die "invalid DVM_AI_MODELS entry: $spec" ;;
		esac
	done
	return 1
}

dvm_ai_model_aliases() {
	local spec
	for spec in $DVM_AI_MODELS; do
		case "$spec" in
		*=*) printf '%s\n' "${spec%%=*}" ;;
		*) dvm_die "invalid DVM_AI_MODELS entry: $spec" ;;
		esac
	done
}

dvm_ai_setup_remote() {
	cat <<'REMOTE'
set -euo pipefail
packages="$1"
server_cmd="$2"
models_dir="$3"
current_model="$4"
service_name="$5"
service_dir="$6"
listen_host="$7"
port="$8"
extra_args="$9"

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

server_path="$(command -v "$server_cmd")" || {
	echo "llama server command not found: $server_cmd" >&2
	exit 1
}

mkdir -p "$models_dir"
unit_tmp="$(mktemp)"
trap 'rm -f "$unit_tmp"' EXIT
cat >"$unit_tmp" <<UNIT
[Unit]
Description=DVM llama.cpp server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(id -un)
WorkingDirectory=$models_dir
ExecStart=$server_path -m $current_model --host $listen_host --port $port $extra_args
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

sudo mkdir -p "$service_dir"
sudo mv "$unit_tmp" "$service_dir/$service_name"
sudo chmod 0644 "$service_dir/$service_name"
sudo systemctl daemon-reload
sudo systemctl enable "$service_name"
if [ -e "$current_model" ]; then
	sudo systemctl restart "$service_name"
else
	echo "no active model yet; service enabled but not started"
fi
REMOTE
}

dvm_ai_pull_remote() {
	cat <<'REMOTE'
set -euo pipefail
models_dir="$1"
alias="$2"
url="$3"
filename="$4"
dest="$models_dir/$filename"
tmp="$dest.part"

mkdir -p "$models_dir"
command -v curl >/dev/null 2>&1 || {
	echo "curl is required in the guest image" >&2
	exit 1
}

echo "downloading $alias"
curl -fL --retry 3 --connect-timeout 20 -o "$tmp" "$url"
mv "$tmp" "$dest"
printf '%s\n' "$dest"
REMOTE
}

dvm_ai_use_remote() {
	cat <<'REMOTE'
set -euo pipefail
models_dir="$1"
current_model="$2"
service_name="$3"
model="$4"

case "$model" in
'' | */* | .* | *..*)
	echo "invalid model name: $model" >&2
	exit 1
	;;
esac

candidate="$models_dir/$model"
if [ ! -f "$candidate" ]; then
	candidate="$models_dir/$model.gguf"
fi
if [ ! -f "$candidate" ]; then
	echo "model not installed: $model" >&2
	exit 1
fi

rm -f "$current_model"
ln -s "$candidate" "$current_model"
sudo systemctl enable "$service_name"
sudo systemctl restart "$service_name"
printf 'active model: %s\n' "$(basename "$candidate")"
REMOTE
}

dvm_ai_models_remote() {
	cat <<'REMOTE'
set -euo pipefail
models_dir="$1"
current_model="$2"
active=""
found="0"

if [ -e "$current_model" ]; then
	active="$(readlink -f "$current_model" 2>/dev/null || true)"
fi

for file in "$models_dir"/*.gguf; do
	[ -e "$file" ] || continue
	[ "$(basename "$file")" = "$(basename "$current_model")" ] && continue
	found="1"
	marker=" "
	if [ -n "$active" ] && [ "$(readlink -f "$file" 2>/dev/null || true)" = "$active" ]; then
		marker="*"
	fi
	printf '%s %s\n' "$marker" "$(basename "$file")"
done

[ "$found" = "1" ] || printf 'no models installed\n'
REMOTE
}

dvm_ai_status_remote() {
	cat <<'REMOTE'
set -euo pipefail
service_name="$1"
current_model="$2"

service="$(systemctl is-active "$service_name" 2>/dev/null || true)"
enabled="$(systemctl is-enabled "$service_name" 2>/dev/null || true)"
model="none"
if [ -e "$current_model" ]; then
	model="$(basename "$(readlink -f "$current_model" 2>/dev/null || printf '%s' "$current_model")")"
fi

printf 'service: %s\n' "${service:-unknown}"
printf 'enabled: %s\n' "${enabled:-unknown}"
printf 'model: %s\n' "$model"
REMOTE
}

dvm_ai_host_remote() {
	cat <<'REMOTE'
set -euo pipefail
port="$1"
guest_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"

printf 'host: http://127.0.0.1:%s\n' "$port"
if [ -n "$guest_ip" ]; then
	printf 'guest: http://%s:%s\n' "$guest_ip" "$port"
fi
REMOTE
}

dvm_ai_vm_name_arg() {
	local usage name
	usage="$1"
	shift
	[ "$#" -le 1 ] || dvm_die "$usage"
	name="${1:-$DVM_AI_NAME}"
	dvm_validate_name "$name"
	printf '%s\n' "$name"
}

dvm_ai_start_vm() {
	local name vm
	name="$1"
	vm="$(dvm_vm_name "$name")"
	limactl start "$vm" >/dev/null
	printf '%s\n' "$vm"
}

dvm_ai_setup() {
	local name vm remote
	dvm_load_config
	name="$(dvm_ai_vm_name_arg "usage: dvm ai setup [name]" "$@")"
	dvm_ai_validate_config
	dvm_require limactl
	vm="$(dvm_ai_start_vm "$name")"
	remote="$(dvm_ai_setup_remote)"

	dvm_log "configuring llama.cpp in $vm"
	limactl shell "$vm" bash -c "$remote" dvm-ai-setup \
		"$DVM_AI_PACKAGES" \
		"$DVM_AI_SERVER_CMD" \
		"$DVM_AI_MODELS_DIR" \
		"$DVM_AI_CURRENT_MODEL" \
		"$DVM_AI_SERVICE_NAME" \
		"$DVM_AI_SYSTEMD_DIR" \
		"$DVM_AI_HOST" \
		"$DVM_AI_PORT" \
		"$DVM_AI_EXTRA_ARGS"
}

dvm_ai_pull_one() {
	local vm request alias url filename remote
	vm="$1"
	request="$2"

	case "$request" in
	*=*)
		alias="${request%%=*}"
		url="${request#*=}"
		;;
	*)
		alias="$request"
		url="$(dvm_ai_model_url "$alias")" || dvm_die "unknown AI model alias: $alias"
		;;
	esac

	dvm_ai_validate_model_alias "$alias"
	dvm_ai_validate_url "$url"
	filename="$(dvm_ai_model_filename "$alias")"
	remote="$(dvm_ai_pull_remote)"

	dvm_log "pulling AI model into $vm: $alias"
	limactl shell "$vm" bash -c "$remote" dvm-ai-pull \
		"$DVM_AI_MODELS_DIR" \
		"$alias" \
		"$url" \
		"$filename"
}

dvm_ai_pull() {
	local name vm alias
	dvm_load_config
	name="$DVM_AI_NAME"
	if [ "${1:-}" = "--vm" ]; then
		[ "$#" -ge 2 ] || dvm_die "usage: dvm ai pull [--vm name] [model...]"
		name="$2"
		shift 2
	fi
	dvm_validate_name "$name"
	dvm_ai_validate_config
	dvm_require limactl
	vm="$(dvm_ai_start_vm "$name")"

	if [ "$#" -eq 0 ]; then
		[ -n "$DVM_AI_MODELS" ] || dvm_die "no AI models configured"
		while IFS= read -r alias; do
			[ -n "$alias" ] || continue
			dvm_ai_pull_one "$vm" "$alias"
		done < <(dvm_ai_model_aliases)
		return 0
	fi

	for alias in "$@"; do
		dvm_ai_pull_one "$vm" "$alias"
	done
}

dvm_ai_use() {
	local name vm model remote
	dvm_load_config
	name="$DVM_AI_NAME"
	if [ "${1:-}" = "--vm" ]; then
		[ "$#" -ge 3 ] || dvm_die "usage: dvm ai use [--vm name] <model>"
		name="$2"
		shift 2
	fi
	[ "$#" -eq 1 ] || dvm_die "usage: dvm ai use [--vm name] <model>"
	model="$1"
	dvm_validate_name "$name"
	dvm_ai_validate_config
	dvm_ai_validate_model_alias "$model"
	dvm_require limactl
	vm="$(dvm_ai_start_vm "$name")"
	remote="$(dvm_ai_use_remote)"

	limactl shell "$vm" bash -c "$remote" dvm-ai-use \
		"$DVM_AI_MODELS_DIR" \
		"$DVM_AI_CURRENT_MODEL" \
		"$DVM_AI_SERVICE_NAME" \
		"$model"
}

dvm_ai_models() {
	local name vm remote
	dvm_load_config
	name="$(dvm_ai_vm_name_arg "usage: dvm ai models [name]" "$@")"
	dvm_ai_validate_config
	dvm_require limactl
	vm="$(dvm_ai_start_vm "$name")"
	remote="$(dvm_ai_models_remote)"
	limactl shell "$vm" bash -c "$remote" dvm-ai-models "$DVM_AI_MODELS_DIR" "$DVM_AI_CURRENT_MODEL"
}

dvm_ai_status() {
	local name vm remote
	dvm_load_config
	name="$(dvm_ai_vm_name_arg "usage: dvm ai status [name]" "$@")"
	dvm_ai_validate_config
	dvm_require limactl
	vm="$(dvm_ai_start_vm "$name")"
	remote="$(dvm_ai_status_remote)"
	printf 'vm: %s\n' "$name"
	limactl shell "$vm" bash -c "$remote" dvm-ai-status "$DVM_AI_SERVICE_NAME" "$DVM_AI_CURRENT_MODEL"
}

dvm_ai_host() {
	local name vm remote
	dvm_load_config
	name="$(dvm_ai_vm_name_arg "usage: dvm ai host [name]" "$@")"
	dvm_ai_validate_config
	dvm_require limactl
	vm="$(dvm_ai_start_vm "$name")"
	remote="$(dvm_ai_host_remote)"
	printf 'vm: %s\n' "$name"
	limactl shell "$vm" bash -c "$remote" dvm-ai-host "$DVM_AI_PORT"
}

dvm_ai_create() {
	local name default_model
	dvm_load_config
	name="$(dvm_ai_vm_name_arg "usage: dvm ai create [name]" "$@")"
	dvm_ai_validate_config

	dvm_create "$name"
	dvm_ai_setup "$name"

	if [ -n "$DVM_AI_MODELS" ]; then
		dvm_ai_pull --vm "$name"
		default_model="$DVM_AI_DEFAULT_MODEL"
		if [ -z "$default_model" ]; then
			default_model="$(dvm_ai_first_model_alias || true)"
		fi
		if [ -n "$default_model" ]; then
			dvm_ai_use --vm "$name" "$default_model"
		fi
	fi
}

dvm_ai_cmd() {
	local cmd
	cmd="${1:-help}"
	[ "$#" -eq 0 ] || shift
	case "$cmd" in
	create | new) dvm_ai_create "$@" ;;
	setup) dvm_ai_setup "$@" ;;
	pull | download) dvm_ai_pull "$@" ;;
	models | ls) dvm_ai_models "$@" ;;
	use | switch) dvm_ai_use "$@" ;;
	status) dvm_ai_status "$@" ;;
	host | url) dvm_ai_host "$@" ;;
	help | -h | --help) dvm_ai_usage ;;
	*)
		dvm_ai_usage
		dvm_die "unknown ai command: $cmd"
		;;
	esac
}
