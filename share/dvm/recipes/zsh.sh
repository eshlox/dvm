#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y zsh util-linux-user

zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [ "$current_shell" != "$zsh_path" ]; then
	sudo chsh -s "$zsh_path" "$(id -un)"
fi
