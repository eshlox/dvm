#!/usr/bin/env bash
set -euo pipefail

port="${DVM_LLAMA_PORT:-8080}"
host="${DVM_LLAMA_HOST:-127.0.0.1}"
models_dir="${DVM_LLAMA_MODELS_DIR:-$HOME/models}"
model="${DVM_LLAMA_DEFAULT_MODEL:-}"
models="${DVM_LLAMA_MODELS:-}"
checksums="${DVM_LLAMA_MODELS_SHA256:-}"
service="${DVM_LLAMA_SERVICE:-dvm-llama.service}"
refresh="${DVM_LLAMA_REFRESH:-0}"

dvm_recipe_validate_service DVM_LLAMA_SERVICE "$service"
case "$models_dir" in
*' '* | *$'\n'* | *$'\r'*) dvm_recipe_die "DVM_LLAMA_MODELS_DIR cannot contain whitespace: $models_dir" ;;
esac
case "$host" in
'' | *[!A-Za-z0-9:._-]*) dvm_recipe_die "invalid DVM_LLAMA_HOST: $host" ;;
esac
dvm_recipe_validate_port DVM_LLAMA_PORT "$port"
dvm_recipe_validate_bool DVM_LLAMA_REFRESH "$refresh"
[ -n "$models" ] || {
	dvm_recipe_die "DVM_LLAMA_MODELS is required"
}

dvm_llama_validate_alias() {
	local alias kind
	kind="$1"
	alias="$2"
	case "$alias" in
	'' | */* | .* | *..* | *[!A-Za-z0-9._-]*) dvm_recipe_die "invalid $kind alias: $alias" ;;
	esac
}

selected_alias=""
selected_sha256=""
selected_url=""
for spec in $models; do
	case "$spec" in
	*=*) ;;
	*) dvm_recipe_die "invalid model spec: $spec" ;;
	esac
	alias="${spec%%=*}"
	url="${spec#*=}"
	dvm_llama_validate_alias model "$alias"
	dvm_recipe_validate_https_url "model URL" "$url"
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
	*) dvm_recipe_die "invalid checksum spec: $spec" ;;
	esac
	alias="${spec%%=*}"
	sha256="${spec#*=}"
	dvm_llama_validate_alias checksum "$alias"
	dvm_recipe_validate_sha256 "checksum for $alias" "$sha256"
	if [ "$alias" = "$selected_alias" ]; then
		selected_sha256="$sha256"
	fi
done

[ -n "$selected_alias" ] || {
	dvm_recipe_die "DVM_LLAMA_DEFAULT_MODEL not found in DVM_LLAMA_MODELS: $model"
}

sudo dnf5 install -y llama-cpp curl
mkdir -p "$models_dir"

target="$models_dir/$selected_alias.gguf"
url_file="$target.url"
download="0"
[ ! -f "$target" ] && download="1"
if [ "$refresh" = "1" ] || [ "$refresh" = "true" ]; then
	download="1"
fi
if [ -f "$url_file" ] && ! printf '%s\n' "$selected_url" | cmp -s - "$url_file"; then
	download="1"
fi
if [ -n "$selected_sha256" ] && [ -f "$target" ]; then
	actual_sha256="$(dvm_recipe_sha256_file "$target")"
	if [ "$actual_sha256" != "$selected_sha256" ]; then
		dvm_recipe_warn "llama: checksum mismatch for existing $target; redownloading"
		download="1"
	fi
fi
if [ "$download" = "1" ]; then
	tmp="$target.tmp.$$"
	rm -f "$tmp"
	printf 'llama: downloading %s from %s\n' "$selected_alias" "$selected_url"
	if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors "$selected_url" -o "$tmp"; then
		rm -f "$tmp"
		dvm_recipe_die "llama: model download failed: $selected_url"
	fi
	if [ -n "$selected_sha256" ]; then
		actual_sha256="$(dvm_recipe_sha256_file "$tmp")"
		if [ "$actual_sha256" != "$selected_sha256" ]; then
			rm -f "$tmp"
			dvm_recipe_die "llama: checksum mismatch for $selected_alias"
		fi
	fi
	mv "$tmp" "$target"
fi
printf '%s\n' "$selected_url" >"$url_file"
ln -sfn "$target" "$models_dir/current.gguf"

llama_server="$(command -v llama-server)"
sudo tee "/etc/systemd/system/$service" >/dev/null <<UNIT
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
UNIT

sudo systemctl daemon-reload
sudo systemctl enable "$service"
sudo systemctl restart "$service"
printf 'llama: http://127.0.0.1:%s (%s)\n' "$port" "$selected_alias"
