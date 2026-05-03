#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local/bin}"
NAME="${DVM_COMMAND_NAME:-dvm}"
DVM_CONFIG="${DVM_CONFIG:-$HOME/.config/dvm}"

usage() {
	cat <<'HELP'
usage:
  ./install.sh [--name dvm] [--prefix ~/.local/bin] [--init]

Installs the tiny Bash DVM wrapper by symlink. With --init, copies default config,
Lima template, recipes, and example VM configs into ~/.config/dvm without overwriting
existing files.
HELP
}

die() {
	printf 'install.sh: error: %s\n' "$*" >&2
	exit 1
}

install_file() {
	local src="$1"
	local dst="$2"
	if [ -e "$dst" ]; then
		return 0
	fi
	mkdir -p "$(dirname "$dst")"
	cp "$src" "$dst"
}

init_config() {
	local src file rel
	src="$ROOT/share/dvm"
	[ -d "$src" ] || die "missing share/dvm defaults"
	mkdir -p "$DVM_CONFIG/vms"
	while IFS= read -r -d '' file; do
		rel="${file#"$src"/}"
		case "$rel" in
		vms/*) install_file "$file" "$DVM_CONFIG/examples/$rel" ;;
		*) install_file "$file" "$DVM_CONFIG/$rel" ;;
		esac
	done < <(find "$src" -type f -print0)
	printf 'initialized config in %s\n' "$DVM_CONFIG"
}

do_init=0
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
		do_init=1
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

if [ "$do_init" = "1" ]; then
	init_config
fi
