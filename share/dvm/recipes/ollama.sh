dvm_pkg curl
if ! dvm_has ollama; then
    if [ -z "${DVM_OLLAMA_URL:-}" ] || [ -z "${DVM_OLLAMA_SHA256:-}" ]; then
        dvm_recipe_die "$DVM_RECIPE" "set DVM_OLLAMA_URL and DVM_OLLAMA_SHA256 for a pinned Ollama binary"
    fi
    dvm_download_verified ollama "$DVM_OLLAMA_URL" "$DVM_OLLAMA_SHA256" /usr/local/bin/ollama
fi
# systemd may be unavailable in minimal/test guests; installation still succeeds.
sudo systemctl enable --now ollama || true
