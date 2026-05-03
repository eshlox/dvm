#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y nodejs npm
corepack enable || true
