#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y nodejs npm

corepack_version="${DVM_COREPACK_VERSION:-0.34.0}"
current_corepack=""
if command -v corepack >/dev/null 2>&1; then
	current_corepack="$(corepack --version 2>/dev/null || true)"
fi

if [ "$corepack_version" = "latest" ] || [ "$current_corepack" != "$corepack_version" ]; then
	sudo npm install -g "corepack@$corepack_version"
fi

sudo corepack enable
