#!/usr/bin/env bash
set -euo pipefail

# This script is copied to ~/.config/dvm/setup.d/fedora.sh by `dvm init`.
# Edit the copied user config, not this default.

mkdir -p "$DVM_CODE_DIR"

# Example user setup:
#
# if ! command -v hx >/dev/null 2>&1; then
#   sudo dnf5 install -y helix ripgrep fd-find jq
# fi
#
# if [ ! -d "$HOME/.dotfiles" ]; then
#   git clone https://github.com/example/dotfiles.git "$HOME/.dotfiles"
# fi
# "$HOME/.dotfiles/install.sh"
