# Description: llama.cpp service (dedicated VM)
# Single-model env-var model:
#   DVM_LLAMA_HOST=127.0.0.1        (default)
#   DVM_LLAMA_PORT=8080             (default)
#   DVM_LLAMA_MODEL_URL=https://example/model.gguf
#   DVM_LLAMA_MODEL_SHA256=<64-hex>
port="${DVM_LLAMA_PORT:-8080}"
host="${DVM_LLAMA_HOST:-127.0.0.1}"
service="dvm-llama.service"
models_dir="${DVM_LLAMA_MODELS_DIR:-$HOME/models}"

dvm_recipe_validate_port llama "$port"
dvm_recipe_validate_service llama "$service"
case "$host" in
'' | *[!A-Za-z0-9:._-]*) dvm_recipe_die llama "invalid host: $host" ;;
esac

dvm_pkg llama-cpp curl
mkdir -p "$models_dir"

if [ -n "${DVM_LLAMA_MODEL_URL:-}" ]; then
    [ -n "${DVM_LLAMA_MODEL_SHA256:-}" ] || dvm_recipe_die llama "DVM_LLAMA_MODEL_SHA256 is required"
    dvm_recipe_validate_sha256 llama "$DVM_LLAMA_MODEL_SHA256"
    target="$models_dir/current.gguf"
    if [ ! -f "$target" ]; then
        dvm_download_verified "$DVM_LLAMA_MODEL_URL" "$DVM_LLAMA_MODEL_SHA256" "$target.tmp"
        mv "$target.tmp" "$target"
    fi
fi

llama_server="$(command -v llama-server)"
sudo tee "/etc/systemd/system/$service" >/dev/null <<EOF
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
EOF

sudo systemctl daemon-reload
if [ -f "$models_dir/current.gguf" ]; then
    sudo systemctl enable "$service"
    sudo systemctl restart "$service"
    printf 'llama: http://%s:%s\n' "$host" "$port"
else
    printf 'llama: place a model at %s/current.gguf or set DVM_LLAMA_MODEL_URL+DVM_LLAMA_MODEL_SHA256\n' "$models_dir"
fi
