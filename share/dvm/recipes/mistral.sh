dvm_pkg curl
if ! dvm_as_user bash -lc 'command -v mistral >/dev/null 2>&1'; then
    if [ -z "${DVM_MISTRAL_URL:-}" ] || [ -z "${DVM_MISTRAL_SHA256:-}" ]; then
        dvm_recipe_die "$DVM_RECIPE" "set DVM_MISTRAL_URL and DVM_MISTRAL_SHA256 for a pinned Mistral CLI binary"
    fi
    dvm_download_verified mistral "$DVM_MISTRAL_URL" "$DVM_MISTRAL_SHA256" /usr/local/bin/mistral
fi
