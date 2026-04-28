#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local/bin}"
NAME="${DVM_COMMAND_NAME:-dvm}"

usage() {
	cat <<'HELP'
usage:
  ./install.sh [--name dvm] [--prefix ~/.local/bin] [--init]

Installs by symlink. This repository remains the core; user config lives in
~/.config/dvm by default.
HELP
}

die() {
	printf 'install.sh: error: %s\n' "$*" >&2
	exit 1
}

init_config="0"
while [ "$#" -gt 0 ]; do
	case "$1" in
	--name)
		[ "$#" -gt 1 ] || die "--name requires a value"
		NAME="$2"
		shift
		;;
	--prefix)
		[ "$#" -gt 1 ] || die "--prefix requires a value"
		PREFIX="$2"
		shift
		;;
	--init)
		init_config="1"
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		die "unknown option: $1"
		;;
	esac
	shift
done

case "$NAME" in
'' | *[!A-Za-z0-9._-]* | .* | *..*) die "unsafe command name: $NAME" ;;
esac
case "$PREFIX" in
/*) ;;
*) die "--prefix must be absolute: $PREFIX" ;;
esac

mkdir -p "$PREFIX"
ln -sfn "$ROOT/bin/dvm" "$PREFIX/$NAME"
printf 'installed %s -> %s\n' "$PREFIX/$NAME" "$ROOT/bin/dvm"

if [ "$init_config" = "1" ]; then
	"$PREFIX/$NAME" init
fi
