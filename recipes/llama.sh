#!/usr/bin/env bash
set -euo pipefail

port="${DVM_LLAMA_PORT:-8080}"
host="${DVM_LLAMA_HOST:-127.0.0.1}"
models_dir="${DVM_LLAMA_MODELS_DIR:-$HOME/models}"
model="${DVM_LLAMA_DEFAULT_MODEL:-}"
models="${DVM_LLAMA_MODELS:-}"
service="${DVM_LLAMA_SERVICE:-dvm-llama.service}"
refresh="${DVM_LLAMA_REFRESH:-0}"

case "$service" in
*.service) ;;
*) echo "DVM_LLAMA_SERVICE must end with .service: $service" >&2; exit 1 ;;
esac
case "$service" in
*/* | *..* | *[!A-Za-z0-9_.@-]*) echo "invalid DVM_LLAMA_SERVICE: $service" >&2; exit 1 ;;
esac
case "$models_dir" in
*' '* | *$'\n'* | *$'\r'*) echo "DVM_LLAMA_MODELS_DIR cannot contain whitespace: $models_dir" >&2; exit 1 ;;
esac
case "$host" in
'' | *[!A-Za-z0-9:._-]*) echo "invalid DVM_LLAMA_HOST: $host" >&2; exit 1 ;;
esac
case "$port" in
'' | *[!0-9]*) echo "invalid DVM_LLAMA_PORT: $port" >&2; exit 1 ;;
esac
if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
	echo "invalid DVM_LLAMA_PORT: $port" >&2
	exit 1
fi
case "$refresh" in
0 | 1 | true | false) ;;
*) echo "invalid DVM_LLAMA_REFRESH: $refresh" >&2; exit 1 ;;
esac
[ -n "$models" ] || {
	echo "DVM_LLAMA_MODELS is required" >&2
	exit 1
}

selected_alias=""
selected_url=""
for spec in $models; do
	case "$spec" in
	*=*) ;;
	*) echo "invalid model spec: $spec" >&2; exit 1 ;;
	esac
	alias="${spec%%=*}"
	url="${spec#*=}"
	case "$alias" in
	'' | */* | .* | *..* | *[!A-Za-z0-9._-]*) echo "invalid model alias: $alias" >&2; exit 1 ;;
	esac
	case "$url" in
	https://*) ;;
	*) echo "model URL must use https://: $url" >&2; exit 1 ;;
	esac
	case "$url" in
	*' '* | *$'\n'* | *$'\r'*) echo "invalid model URL: $url" >&2; exit 1 ;;
	esac
	if [ -z "$model" ]; then
		model="$alias"
	fi
	if [ "$alias" = "$model" ]; then
		selected_alias="$alias"
		selected_url="$url"
	fi
done

[ -n "$selected_alias" ] || {
	echo "DVM_LLAMA_DEFAULT_MODEL not found in DVM_LLAMA_MODELS: $model" >&2
	exit 1
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
if [ "$download" = "1" ]; then
	tmp="$target.tmp.$$"
	rm -f "$tmp"
	printf 'llama: downloading %s from %s\n' "$selected_alias" "$selected_url"
	if ! curl -fL --retry 3 --retry-delay 2 --retry-all-errors "$selected_url" -o "$tmp"; then
		rm -f "$tmp"
		echo "llama: model download failed: $selected_url" >&2
		exit 1
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
