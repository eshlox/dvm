dvm_pkg chezmoi git

if [ -n "${DVM_CHEZMOI_REPO:-}" ]; then
    home="$(dvm_user_home)"
    config_dir="$home/.config/chezmoi"
    config_file=
    for candidate in "$config_dir"/chezmoi.{json,jsonc,toml,yaml,yml}; do
        if [ -e "$candidate" ]; then
            config_file="$candidate"
            break
        fi
    done
    config_file="${config_file:-$config_dir/chezmoi.json}"
    role="${DVM_CHEZMOI_ROLE:-$DVM_NAME}"
    if [ ! -e "$config_file" ] && [ -n "$role" ]; then
        escaped="${role//\\/\\\\}"
        escaped="${escaped//\"/\\\"}"
        escaped="${escaped//$'\n'/\\n}"
        escaped="${escaped//$'\r'/\\r}"
        escaped="${escaped//$'\t'/\\t}"
        tmp="$(mktemp)"
        printf '{\n  "data": {\n    "role": "%s"\n  }\n}\n' "$escaped" >"$tmp"
        sudo install -d -o "$DVM_USER" -g "$(dvm_user_group "$DVM_USER")" -m 0700 "$config_dir"
        sudo install -o "$DVM_USER" -g "$(dvm_user_group "$DVM_USER")" -m 0600 "$tmp" "$config_file"
        rm -f "$tmp"
    fi
    if [ ! -d "$home/.local/share/chezmoi" ]; then
        dvm_as_user chezmoi init "$DVM_CHEZMOI_REPO"
    fi
    dvm_as_user chezmoi apply
fi
