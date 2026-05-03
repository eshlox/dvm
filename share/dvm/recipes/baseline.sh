#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y \
	git helix lazygit zsh fzf ripgrep fd-find tmux just \
	curl wget unzip tar gzip jq

mkdir -p "$HOME/.local/bin" "$HOME/code"

zsh_path="$(command -v zsh || true)"
current_shell="$(getent passwd "$(id -un)" | awk -F: '{ print $7 }')"
if [ -n "$zsh_path" ] && [ "$current_shell" != "$zsh_path" ]; then
	sudo chsh -s "$zsh_path" "$(id -un)" || true
fi
