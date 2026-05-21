#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local/bin}"

case "$PREFIX" in /*) ;; *) printf 'install.sh: PREFIX must be absolute: %s\n' "$PREFIX" >&2; exit 1 ;; esac
mkdir -p "$PREFIX"
ln -sfn "$ROOT/bin/dvm" "$PREFIX/dvm"
printf 'installed %s -> %s\n' "$PREFIX/dvm" "$ROOT/bin/dvm"
