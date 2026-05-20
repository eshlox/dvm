dvm_pkg curl
if ! dvm_has ollama; then
    curl -fsSL https://ollama.com/install.sh | sh
fi
sudo systemctl enable --now ollama || true
