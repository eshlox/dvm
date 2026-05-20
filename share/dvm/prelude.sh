set -euo pipefail

dvm_die() {
    printf 'dvm guest: %s\n' "$*" >&2
    exit 1
}

dvm_recipe_die() {
    printf 'dvm recipe %s: %s\n' "${1:-unknown}" "${2:-failed}" >&2
    exit 1
}

dvm_recipe_warn() {
    printf 'dvm recipe %s: warning: %s\n' "${1:-unknown}" "${2:-warning}" >&2
}

dvm_has() {
    command -v "$1" >/dev/null 2>&1
}

dvm_pkg() {
    [ "$#" -gt 0 ] || return 0
    dvm_has dnf5 || dvm_die "dnf5 not found; DVM supports Lima's latest Fedora template only"
    sudo dnf5 install -y "$@"
}

dvm_as_user() {
    sudo -u "$DVM_USER" -H "$@"
}

dvm_as_agent() {
    sudo -u "$DVM_AGENT_USER" -H "$@"
}

dvm_user_group() {
    id -gn "$1"
}

dvm_ensure_user() {
    local user="$1" home group
    if ! id "$user" >/dev/null 2>&1; then
        dvm_has useradd || dvm_pkg shadow-utils
        sudo useradd -m -s /bin/bash "$user"
    fi
    home="$(getent passwd "$user" | cut -d: -f6)"
    [ -n "$home" ] || dvm_die "user $user has no passwd entry"
    group="$(dvm_user_group "$user")" || dvm_die "user $user has no primary group"
    sudo install -d -o "$user" -g "$group" "$home"
}

dvm_user_home() {
    getent passwd "$DVM_USER" | cut -d: -f6
}

dvm_agent_home() {
    getent passwd "$DVM_AGENT_USER" | cut -d: -f6
}

dvm_secret() {
    local name="$1" path="/tmp/dvm-secret-$1"
    [ -r "$path" ] || dvm_recipe_die "${DVM_RECIPE:-secret}" "secret not staged: $name"
    printf '%s\n' "$path"
}

dvm_append_once() {
    local file="$1" line="$2"
    dvm_as_user bash -c '
        mkdir -p "$(dirname "$1")"
        touch "$1"
        grep -Fqx "$2" "$1" || printf "%s\n" "$2" >>"$1"
    ' bash "$file" "$line"
}

dvm_download_verified() {
    local name="$1" url="$2" sha256="$3" out="$4" tmp
    tmp="$(mktemp)"
    curl -fsSL "$url" -o "$tmp"
    printf '%s  %s\n' "$sha256" "$tmp" | sha256sum -c -
    sudo install -m 0755 "$tmp" "$out"
    rm -f "$tmp"
    printf 'installed %s -> %s\n' "$name" "$out"
}
