#!/usr/bin/env bash
set -euo pipefail

: "${DVM_CHEZMOI_REPO:?DVM_CHEZMOI_REPO is required for recipe chezmoi}"

sudo dnf5 install -y chezmoi git

if [ ! -d "$HOME/.local/share/chezmoi/.git" ]; then
	rm -rf "$HOME/.local/share/chezmoi"
	chezmoi init "$DVM_CHEZMOI_REPO"
else
	chezmoi git -- pull --ff-only
fi

chezmoi apply
