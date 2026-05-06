# shellcheck shell=bash
# shellcheck disable=SC2034,SC2088
# Project VM. Uncomment lines below to override defaults.

# Resources
# DVM_CPUS=2          # default 2 (host max: __DVM_HOST_MAX_CPUS__)
# DVM_MEMORY=2GiB     # default 2GiB (host max: __DVM_HOST_MAX_MEMORY__)
# DVM_DISK=10GiB      # default 10GiB

# Code directory inside the guest. ~ expands to the guest user home.
# DVM_CODE_DIR="~/code/$DVM_NAME"

# Forwarded host:guest ports, space-separated. Empty by default.
# DVM_PORTS="3000:3000 5173:5173"

# Public dotfiles repo for the chezmoi recipe.
# DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"

# Override SSH key paths only when ssh-key was created with custom names:
# DVM_CHEZMOI_SIGNING_KEY="~/.ssh/id_ed25519_dvm_signing.pub"
# DVM_CHEZMOI_DEPLOY_KEY="~/.ssh/id_ed25519_dvm.pub"

# Available recipes. Uncomment to enable.
__DVM_AVAILABLE_RECIPES__
