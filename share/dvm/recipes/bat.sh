#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y bat
bat cache --build
