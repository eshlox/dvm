dvm_pkg chezmoi git

if [ -n "${DVM_CHEZMOI_REPO:-}" ]; then
    home="$(dvm_user_home)"
    if [ ! -d "$home/.local/share/chezmoi" ]; then
        dvm_as_user chezmoi init "$DVM_CHEZMOI_REPO"
    fi
    dvm_as_user chezmoi apply
fi
