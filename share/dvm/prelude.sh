# shellcheck shell=bash
# Concatenated into every guest sync script. Not run standalone.
set -euo pipefail
dvm_die() { printf 'dvm recipe: %s\n' "$*" >&2; exit 1; }
dvm_recipe_die() { printf 'dvm recipe: %s: %s\n' "$1" "$2" >&2; exit 1; }
dvm_recipe_warn() { printf 'dvm recipe: %s: %s\n' "$1" "$2" >&2; }
dvm_pkg() {
    if command -v dnf5 >/dev/null 2>&1; then sudo dnf5 install -y "$@"
    elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y "$@"
    else dvm_die "no supported package manager"; fi
}
dvm_secret() {
    local f="/tmp/dvm-secret-$1"
    [ -r "$f" ] || dvm_recipe_die "$1" "secret not staged"
    printf '%s\n' "$f"
}
dvm_recipe_bool() {
    case "$3" in 1|true|yes|on) printf 1 ;; 0|false|no|off|'') printf 0 ;;
    *) dvm_recipe_die "$1" "$2 must be 1 or 0 (got $3)" ;; esac
}
dvm_recipe_require_agent_user() {
    command -v dvm_agent_write_wrapper >/dev/null 2>&1 \
        || dvm_recipe_die "$1" "requires agent-user recipe first"
}
dvm_recipe_validate_port() {
    case "$2" in ''|*[!0-9]*) dvm_recipe_die "$1" "invalid port: $2" ;; esac
    if [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
        dvm_recipe_die "$1" "port out of range: $2"
    fi
}
dvm_recipe_validate_service() {
    case "$2" in *.service) ;; *) dvm_recipe_die "$1" "service must end with .service: $2" ;; esac
    case "$2" in */*|*..*|*[!A-Za-z0-9_.@-]*) dvm_recipe_die "$1" "invalid service name: $2" ;; esac
}
dvm_recipe_validate_sha256() {
    case "$2" in
        ????????????????????????????????????????????????????????????????)
            case "$2" in *[!A-Fa-f0-9]*) dvm_recipe_die "$1" "sha256 must be 64 hex" ;; esac ;;
        *) dvm_recipe_die "$1" "sha256 must be 64 hex" ;;
    esac
}
dvm_recipe_arch() {
    case "$(uname -m)" in aarch64|arm64) echo aarch64 ;; x86_64|amd64) echo x86_64 ;;
    *) dvm_recipe_die "$1" "unsupported arch: $(uname -m)" ;; esac
}
dvm_download_verified() {
    curl -fL --retry 3 --retry-delay 2 --proto '=https' --tlsv1.2 -o "$3" "$1"
    printf '%s  %s\n' "$2" "$3" | sha256sum -c -
}
dvm_install_pinned() {
    local name="$1" arm_url="$2" arm_sha="$3" x86_url="$4" x86_sha="$5" kind="$6"; shift 6
    dvm_recipe_validate_sha256 "$name" "$arm_sha"
    dvm_recipe_validate_sha256 "$name" "$x86_sha"
    local url sha
    case "$(dvm_recipe_arch "$name")" in
        aarch64) url="$arm_url"; sha="$arm_sha" ;;
        x86_64) url="$x86_url"; sha="$x86_sha" ;;
    esac
    local work; work="$(mktemp -d)"; trap 'rm -rf "$work"' RETURN
    case "$kind" in
        tar)
            dvm_download_verified "$url" "$sha" "$work/a.tar.gz"
            tar -xzf "$work/a.tar.gz" -C "$work"
            local bin; bin="$(find "$work" -type f -name "$1" -print -quit)"
            [ -n "$bin" ] || dvm_recipe_die "$name" "missing binary in archive: $1"
            sudo install -m 0755 "$bin" "/usr/local/bin/$1"
            ;;
        zip)
            sudo dnf5 install -y unzip >/dev/null 2>&1 || sudo dnf install -y unzip
            dvm_download_verified "$url" "$sha" "$work/a.zip"
            unzip -q "$work/a.zip" -d "$work"
            local b src
            for b in "$@"; do
                src="$(find "$work" -type f -name "$b" -print -quit)"
                [ -n "$src" ] || dvm_recipe_die "$name" "missing binary in archive: $b"
                sudo install -m 0755 "$src" "/usr/local/bin/$b"
            done
            ;;
        *) dvm_recipe_die "$name" "unsupported archive: $kind" ;;
    esac
}
# Per-sync idempotent baseline.
id -u "$DVM_USER" >/dev/null 2>&1 || sudo useradd -m -s /bin/bash "$DVM_USER"
sudo install -d -o "$DVM_USER" -g "$DVM_USER" "$DVM_CODE_DIR"
