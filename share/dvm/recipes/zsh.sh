#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y zsh shadow-utils

zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [ "$current_shell" != "$zsh_path" ]; then
	sudo usermod --shell "$zsh_path" "$(id -un)"
fi
