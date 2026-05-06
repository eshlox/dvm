#!/usr/bin/env bash
# Description: bat (cat with syntax highlighting)
set -euo pipefail

sudo dnf5 install -y bat
bat cache --build
