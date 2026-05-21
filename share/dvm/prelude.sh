set -Eeuo pipefail

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
    local name="$1" var path
    case "$name" in
        ''|[0-9]*|*[!A-Za-z0-9_]*)
            dvm_recipe_die "${DVM_RECIPE:-secret}" "invalid secret name: $name"
            ;;
    esac
    var="DVM_SECRET_PATH_$name"
    path="${!var:-}"
    [ -n "$path" ] || dvm_recipe_die "${DVM_RECIPE:-secret}" "secret not staged: $name"
    sudo test -r "$path" || dvm_recipe_die "${DVM_RECIPE:-secret}" "secret not readable: $name"
    printf '%s\n' "$path"
}

dvm_has_secret() {
    local name="$1" var path
    case "$name" in
        ''|[0-9]*|*[!A-Za-z0-9_]*)
            return 1
            ;;
    esac
    var="DVM_SECRET_PATH_$name"
    path="${!var:-}"
    [ -n "$path" ] && sudo test -r "$path"
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
    case "$url" in
        https://*) ;;
        *) dvm_recipe_die "${DVM_RECIPE:-download}" "$name download URL must use https" ;;
    esac
    tmp="$(mktemp)"
    if ! curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$tmp"; then
        rm -f "$tmp"
        dvm_recipe_die "${DVM_RECIPE:-download}" "failed to download $name"
    fi
    if ! printf '%s  %s\n' "$sha256" "$tmp" | sha256sum -c -; then
        rm -f "$tmp"
        dvm_recipe_die "${DVM_RECIPE:-download}" "checksum failed for $name"
    fi
    sudo install -d -m 0755 "$(dirname "$out")"
    sudo install -m 0755 "$tmp" "$out"
    rm -f "$tmp"
    printf 'installed %s -> %s\n' "$name" "$out"
}

dvm_npm_global() {
    local package="$1" version="$2" scripts="${3:-ignore-scripts}" home default_prefix prefix script_flag
    [ -n "$package" ] || dvm_recipe_die "${DVM_RECIPE:-npm}" "missing npm package name"
    [ -n "$version" ] || dvm_recipe_die "${DVM_RECIPE:-npm}" "missing pinned npm package version for $package"
    case "$scripts" in
        ignore-scripts) script_flag=--ignore-scripts ;;
        allow-scripts)
            script_flag=--foreground-scripts
            dvm_recipe_warn "${DVM_RECIPE:-npm}" "$package requires npm lifecycle scripts; running them as $DVM_USER"
            ;;
        *) dvm_recipe_die "${DVM_RECIPE:-npm}" "unknown npm script policy: $scripts" ;;
    esac
    home="$(dvm_user_home)"
    default_prefix="$home/.local/npm"
    prefix="${DVM_NPM_PREFIX:-$default_prefix}"
    sudo install -d -o "$DVM_USER" -g "$(dvm_user_group "$DVM_USER")" "$prefix"
    dvm_as_user npm install --global --prefix "$prefix" "$script_flag" "$package@$version"
    case "$prefix" in
        "$default_prefix")
            dvm_append_once "$home/.bashrc" 'export PATH="$HOME/.local/npm/bin:$PATH"'
            dvm_append_once "$home/.zshrc" 'export PATH="$HOME/.local/npm/bin:$PATH"'
            ;;
        *)
            dvm_recipe_warn "${DVM_RECIPE:-npm}" "custom DVM_NPM_PREFIX is not added to PATH automatically: $prefix"
            ;;
    esac
}
