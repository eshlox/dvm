
dvm_recipe_die() {
	printf 'dvm recipe: error: %s: %s\n' "$1" "$2" >&2
	exit 1
}

dvm_recipe_warn() {
	printf 'dvm recipe: warning: %s: %s\n' "$1" "$2" >&2
}

dvm_recipe_require_agent_user() {
	command -v dvm_agent_write_wrapper >/dev/null 2>&1 || {
		printf 'dvm: recipe %s requires use agent-user before use %s\n' "$1" "$1" >&2
		exit 1
	}
}

dvm_recipe_bool() {
	local recipe="$1"
	local name="$2"
	local value="$3"
	case "$value" in
	1 | true | yes) printf '1\n' ;;
	0 | false | no) printf '0\n' ;;
	*)
		printf 'dvm: recipe %s: %s must be 1 or 0\n' "$recipe" "$name" >&2
		exit 1
		;;
	esac
}

dvm_recipe_validate_port() {
	case "$2" in
	'' | *[!0-9]*) dvm_recipe_die "$1" "invalid port: $2" ;;
	esac
	[ "$2" -ge 1 ] && [ "$2" -le 65535 ] || dvm_recipe_die "$1" "invalid port: $2"
}

dvm_recipe_validate_service() {
	case "$2" in
	*.service) ;;
	*) dvm_recipe_die "$1" "service must end with .service: $2" ;;
	esac
	case "$2" in
	*/* | *..* | *[!A-Za-z0-9_.@-]*) dvm_recipe_die "$1" "invalid service name: $2" ;;
	esac
}

dvm_recipe_validate_alias() {
	case "$2" in
	'' | */* | .* | *..* | *[!A-Za-z0-9._-]*) dvm_recipe_die "$1" "invalid model alias: $2" ;;
	esac
}

dvm_recipe_validate_https_url() {
	case "$2" in
	https://*) ;;
	*) dvm_recipe_die "$1" "model URL must use https://: $2" ;;
	esac
	case "$2" in
	*' '* | *$'\n'* | *$'\r'*) dvm_recipe_die "$1" "invalid model URL: $2" ;;
	esac
}

dvm_recipe_validate_sha256() {
	case "$2" in
	????????????????????????????????????????????????????????????????)
		case "$2" in
		*[!A-Fa-f0-9]*) dvm_recipe_die "$1" "sha256 must be a 64-character hex digest" ;;
		esac
		;;
	*) dvm_recipe_die "$1" "sha256 must be a 64-character hex digest" ;;
	esac
}

dvm_recipe_sha256_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$2" | awk '{ print $1 }'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$2" | awk '{ print $1 }'
	else
		dvm_recipe_die "$1" "sha256sum or shasum is required"
	fi
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

dvm_recipe_install_pinned() {
	local name="$1"
	local package="$2"
	local cmd="$3"
	local archive_type="$4"
	local arm_url="$5"
	local arm_sha256="$6"
	local x86_url="$7"
	local x86_sha256="$8"
	local -a bins deps
	shift 8
	bins=("$@")

	dvm_recipe_install_pinned_fallback() {
		local url sha256
		deps=(ca-certificates curl)
		case "$archive_type" in
		tar) deps+=(tar gzip) ;;
		zip) deps+=(unzip) ;;
		*) dvm_recipe_die "$name" "unsupported archive type: $archive_type" ;;
		esac
		sudo dnf5 install -y "${deps[@]}"
		case "$(dvm_recipe_arch "$name")" in
		arm64)
			url="$arm_url"
			sha256="$arm_sha256"
			;;
		x86_64)
			url="$x86_url"
			sha256="$x86_sha256"
			;;
		esac
		case "$archive_type" in
		tar) dvm_recipe_install_tar_bin "$name" "$url" "$sha256" "$cmd" ;;
		zip) dvm_recipe_install_zip_bins "$name" "$url" "$sha256" "${bins[@]}" ;;
		esac
	}

	dvm_recipe_dnf_or_pinned "$package" "$cmd" dvm_recipe_install_pinned_fallback
}
