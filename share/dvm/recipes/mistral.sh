dvm_pkg curl
if ! dvm_as_user bash -lc 'command -v mistral >/dev/null 2>&1'; then
    dvm_as_user bash -lc 'curl -fsSL https://install.mistral.codes | sh'
fi
