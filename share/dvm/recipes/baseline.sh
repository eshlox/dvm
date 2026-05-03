#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y \
	git curl wget unzip tar gzip jq

mkdir -p "$HOME/.local/bin" "$HOME/code"
