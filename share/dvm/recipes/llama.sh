#!/usr/bin/env bash
set -euo pipefail

llama_die() {
	printf 'dvm recipe: error: llama: %s\n' "$*" >&2
	exit 1
}

llama_warn() {
	printf 'dvm recipe: warning: llama: %s\n' "$*" >&2
}

llama_validate_port() {
	case "$1" in
	'' | *[!0-9]*) llama_die "invalid port: $1" ;;
	esac
	if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
		llama_die "invalid port: $1"
	fi
}

llama_validate_service() {
	case "$1" in
	*.service) ;;
	*) llama_die "service must end with .service: $1" ;;
	esac
	case "$1" in
	*/* | *..* | *[!A-Za-z0-9_.@-]*) llama_die "invalid service name: $1" ;;
	esac
}

llama_validate_alias() {
	case "$1" in
	'' | */* | .* | *..* | *[!A-Za-z0-9._-]*) llama_die "invalid model alias: $1" ;;
	esac
}

llama_validate_https_url() {
	case "$1" in
	https://*) ;;
	*) llama_die "model URL must use https://: $1" ;;
	esac
	case "$1" in
	*' '* | *$'\n'* | *$'\r'*) llama_die "invalid model URL: $1" ;;
	esac
}

llama_validate_sha256() {
	case "$1" in
	????????????????????????????????????????????????????????????????) ;;
	*) llama_die "sha256 must be a 64-character hex digest" ;;
	esac
	case "$1" in
	*[!A-Fa-f0-9]*) llama_die "sha256 must be a 64-character hex digest" ;;
	esac
}

llama_sha256_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{ print $1 }'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | awk '{ print $1 }'
	else
		llama_die "sha256sum or shasum is required"
	fi
}

port="${DVM_LLAMA_PORT:-8080}"
host="${DVM_LLAMA_HOST:-0.0.0.0}"
models_dir="${DVM_LLAMA_MODELS_DIR:-$HOME/models}"
model="${DVM_LLAMA_DEFAULT_MODEL:-}"
models="${DVM_LLAMA_MODELS:-}"
checksums="${DVM_LLAMA_MODELS_SHA256:-}"
service="${DVM_LLAMA_SERVICE:-dvm-llama.service}"
refresh="${DVM_LLAMA_REFRESH:-0}"

if [ -z "$models" ] && [ -n "${DVM_LLAMA_MODEL_URL:-}" ]; then
	models="current=$DVM_LLAMA_MODEL_URL"
	model="${model:-current}"
	if [ -z "$checksums" ] && [ -n "${DVM_LLAMA_MODEL_SHA256:-}" ]; then
		checksums="current=$DVM_LLAMA_MODEL_SHA256"
	fi
fi

llama_validate_port "$port"
llama_validate_service "$service"
case "$host" in
'' | *[!A-Za-z0-9:._-]*) llama_die "invalid host: $host" ;;
esac
case "$models_dir" in
*' '* | *$'\n'* | *$'\r'*) llama_die "models dir cannot contain whitespace: $models_dir" ;;
esac
case "$refresh" in
0 | 1 | true | false) ;;
*) llama_die "DVM_LLAMA_REFRESH must be 0, 1, true, or false" ;;
esac

sudo dnf5 install -y llama-cpp curl
mkdir -p "$models_dir"

selected_alias=""
selected_sha256=""
selected_url=""
target="$models_dir/current.gguf"

if [ -n "$models" ]; then
	for spec in $models; do
		case "$spec" in
		*=*) ;;
		*) llama_die "invalid model spec: $spec" ;;
		esac
		alias="${spec%%=*}"
		url="${spec#*=}"
		llama_validate_alias "$alias"
		llama_validate_https_url "$url"
		if [ -z "$model" ]; then
			model="$alias"
		fi
		if [ "$alias" = "$model" ]; then
			selected_alias="$alias"
			selected_url="$url"
		fi
	done

	for spec in ${checksums//,/ }; do
		[ -n "$spec" ] || continue
		case "$spec" in
		*=*) ;;
		*) llama_die "invalid checksum spec: $spec" ;;
		esac
		alias="${spec%%=*}"
		sha256="${spec#*=}"
		llama_validate_alias "$alias"
		llama_validate_sha256 "$sha256"
		if [ "$alias" = "$selected_alias" ]; then
			selected_sha256="$sha256"
		fi
	done

	[ -n "$selected_alias" ] || llama_die "DVM_LLAMA_DEFAULT_MODEL not found in DVM_LLAMA_MODELS: $model"
	target="$models_dir/$selected_alias.gguf"
	url_file="$target.url"
	download="0"
	[ ! -f "$target" ] && download="1"
	case "$refresh" in
	1 | true) download="1" ;;
	esac
	if [ -f "$url_file" ] && ! printf '%s\n' "$selected_url" | cmp -s - "$url_file"; then
		download="1"
	fi
	if [ -n "$selected_sha256" ] && [ -f "$target" ]; then
		actual_sha256="$(llama_sha256_file "$target")"
		if [ "$actual_sha256" != "$selected_sha256" ]; then
			llama_warn "checksum mismatch for existing $target; redownloading"
			download="1"
		fi
	fi
	if [ "$download" = "1" ]; then
		tmp="$target.tmp.$$"
		rm -f "$tmp"
		printf 'llama: downloading %s from %s\n' "$selected_alias" "$selected_url"
		if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors "$selected_url" -o "$tmp"; then
			rm -f "$tmp"
			llama_die "model download failed: $selected_url"
		fi
		if [ -n "$selected_sha256" ]; then
			actual_sha256="$(llama_sha256_file "$tmp")"
			if [ "$actual_sha256" != "$selected_sha256" ]; then
				rm -f "$tmp"
				llama_die "checksum mismatch for $selected_alias"
			fi
		fi
		mv "$tmp" "$target"
	fi
	printf '%s\n' "$selected_url" >"$url_file"
	ln -sfn "$target" "$models_dir/current.gguf"
else
	selected_alias="current"
fi

llama_server="$(command -v llama-server)"
sudo tee "/etc/systemd/system/$service" >/dev/null <<DVM_LLAMA_SERVICE
[Unit]
Description=DVM llama.cpp server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(id -un)
WorkingDirectory=$models_dir
ExecStart=$llama_server -m $models_dir/current.gguf --host $host --port $port
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
DVM_LLAMA_SERVICE

sudo systemctl daemon-reload
if [ -f "$models_dir/current.gguf" ]; then
	sudo systemctl enable "$service"
	sudo systemctl restart "$service"
	printf 'llama: http://127.0.0.1:%s (%s)\n' "$port" "$selected_alias"
else
	printf '%s\n' 'llama: place a model at ~/models/current.gguf or set DVM_LLAMA_MODELS, then run dvm apply llama'
fi
