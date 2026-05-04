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

Installs a tiny DVM launcher. With --init, copies default config into ~/.config/dvm
without overwriting existing files. Bundled recipes, the Lima template, and example VM
configs stay in the repo under share/dvm.
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

shell_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

install_launcher() {
	local dst root_q
	dst="$PREFIX/$NAME"
	root_q="$(shell_quote "$ROOT")"
	mkdir -p "$(dirname "$dst")"
	if [ -L "$dst" ]; then
		rm -f "$dst"
	fi
	{
		printf '#!/usr/bin/env bash\n'
		printf 'set -euo pipefail\n'
		printf 'DVM_ROOT=%s\n' "$root_q"
		cat <<'LAUNCHER'
src="$DVM_ROOT/bin/dvm"
[ -f "$src" ] || {
	printf 'dvm launcher: missing %s\n' "$src" >&2
	exit 1
}

tmp_dir="${TMPDIR:-/tmp}"
tmp="$(mktemp "${tmp_dir%/}/dvm-run.XXXXXX")"
cleanup() {
	rm -f "$tmp"
}
trap cleanup EXIT INT TERM

cp "$src" "$tmp"
chmod 0700 "$tmp"
DVM_ROOT="$DVM_ROOT" bash "$tmp" "$@"
LAUNCHER
	} >"$dst"
	chmod 0755 "$dst"
	printf 'installed %s -> %s\n' "$dst" "$ROOT/bin/dvm"
}

init_config() {
	local src file rel
	src="$ROOT/share/dvm"
	[ -d "$src" ] || die "missing share/dvm defaults"
	mkdir -p "$DVM_CONFIG/vms"
	mkdir -p "$DVM_CONFIG/recipes"
	while IFS= read -r -d '' file; do
		rel="${file#"$src"/}"
		case "$rel" in
		lima.yaml.in) ;;
		recipes/*) ;;
		vms/*) ;;
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

install_launcher

if [ "$do_init" = "1" ]; then
	init_config
fi
