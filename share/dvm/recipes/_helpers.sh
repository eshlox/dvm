#!/usr/bin/env bash

dvm_recipe_die() {
	printf 'dvm recipe: error: %s: %s\n' "$1" "$2" >&2
	exit 1
}

dvm_recipe_arch() {
	case "$(uname -m)" in
	aarch64 | arm64) printf '%s\n' arm64 ;;
	x86_64 | amd64) printf '%s\n' x86_64 ;;
	*) dvm_recipe_die "$1" "unsupported architecture: $(uname -m)" ;;
	esac
}

dvm_recipe_pin_current() {
	local name="$1"
	local sha256="$2"
	local cmd="$3"
	local marker="/usr/local/share/dvm/pins/$name.sha256"

	command -v "$cmd" >/dev/null 2>&1 || return 1
	[ -r "$marker" ] || return 1
	[ "$(cat "$marker")" = "$sha256" ]
}

dvm_recipe_mark_pin() {
	local name="$1"
	local sha256="$2"

	sudo mkdir -p /usr/local/share/dvm/pins
	printf '%s\n' "$sha256" | sudo tee "/usr/local/share/dvm/pins/$name.sha256" >/dev/null
}

dvm_recipe_download_verified() {
	local url="$1"
	local sha256="$2"
	local output="$3"

	curl -fL --retry 3 --retry-delay 2 --proto '=https' --tlsv1.2 -o "$output" "$url"
	printf '%s  %s\n' "$sha256" "$output" | sha256sum -c -
}

dvm_recipe_install_tar_bin() (
	name="$1"
	url="$2"
	sha256="$3"
	bin="$4"

	if dvm_recipe_pin_current "$name" "$sha256" "$bin"; then
		return 0
	fi

	work="$(mktemp -d)"
	trap 'rm -rf "$work"' EXIT
	archive="$work/archive.tar.gz"

	dvm_recipe_download_verified "$url" "$sha256" "$archive"
	tar -xzf "$archive" -C "$work"

	src="$(find "$work" -type f -name "$bin" -print -quit)"
	[ -n "$src" ] || dvm_recipe_die "$name" "missing binary in archive: $bin"

	sudo install -m 0755 "$src" "/usr/local/bin/$bin"
	dvm_recipe_mark_pin "$name" "$sha256"
)

dvm_recipe_install_zip_bins() (
	name="$1"
	url="$2"
	sha256="$3"
	shift 3

	if dvm_recipe_pin_current "$name" "$sha256" "$1"; then
		return 0
	fi

	work="$(mktemp -d)"
	trap 'rm -rf "$work"' EXIT
	archive="$work/archive.zip"

	dvm_recipe_download_verified "$url" "$sha256" "$archive"
	unzip -q "$archive" -d "$work"

	for bin in "$@"; do
		src="$(find "$work" -type f -name "$bin" -print -quit)"
		[ -n "$src" ] || dvm_recipe_die "$name" "missing binary in archive: $bin"
		sudo install -m 0755 "$src" "/usr/local/bin/$bin"
	done

	dvm_recipe_mark_pin "$name" "$sha256"
)

dvm_recipe_dnf_or_pinned() {
	local package="$1"
	local cmd="$2"
	local fallback="$3"
	local marker="/usr/local/share/dvm/pins/$package.sha256"

	sudo dnf5 install -y --skip-unavailable "$package" || true
	if rpm -q "$package" >/dev/null 2>&1 && [ -r "$marker" ] && [ -x "/usr/local/bin/$cmd" ]; then
		sudo rm -f "/usr/local/bin/$cmd" "$marker"
	fi
	if rpm -q "$package" >/dev/null 2>&1 && command -v "$cmd" >/dev/null 2>&1; then
		return 0
	fi
	"$fallback"
}
