# DVM user config.
#
# This file is shell code by design. Keep local VM configuration here, not in
# the repository core, so the core can be updated independently.

DVM_PREFIX="${DVM_PREFIX:-dvm}"
DVM_TEMPLATE="${DVM_TEMPLATE:-template:fedora}"
DVM_ARCH="${DVM_ARCH:-aarch64}"
DVM_CPUS="${DVM_CPUS:-4}"
DVM_MEMORY="${DVM_MEMORY:-8GiB}"
DVM_DISK="${DVM_DISK:-80GiB}"

DVM_GUEST_USER="${DVM_GUEST_USER:-$(id -un)}"
DVM_GUEST_HOME="${DVM_GUEST_HOME:-/home/$DVM_GUEST_USER}"
DVM_CODE_DIR="${DVM_CODE_DIR:-$DVM_GUEST_HOME/code}"

# Packages installed or refreshed by `dvm setup <name>` and `dvm setup-all`.
DVM_PACKAGES="${DVM_PACKAGES:-git openssh-clients gpg}"

# Space-separated host scripts. Each script is piped into the VM and runs as the
# guest user with DVM_NAME, DVM_VM_NAME, and DVM_CODE_DIR set.
DVM_SETUP_SCRIPTS="${DVM_SETUP_SCRIPTS:-$DVM_CONFIG/setup.d/fedora.sh}"

# Optional host dotfiles snapshot copied into the VM during `dvm setup`.
# Keep this opt-in. DVM copies a snapshot before user setup scripts run; it does
# not mount a live host directory into the VM.
# DVM_DOTFILES_DIR="${HOME}/.dotfiles"
DVM_DOTFILES_DIR="${DVM_DOTFILES_DIR:-}"
DVM_DOTFILES_TARGET="${DVM_DOTFILES_TARGET:-$DVM_GUEST_HOME/.dotfiles}"
DVM_DOTFILES_EXCLUDES="${DVM_DOTFILES_EXCLUDES:-.git .ssh .gnupg .env secrets}"

# Optional llama.cpp VM helper config. `dvm ai create` uses these values.
DVM_AI_NAME="${DVM_AI_NAME:-ai}"
DVM_AI_PACKAGES="${DVM_AI_PACKAGES:-llama-cpp curl}"
DVM_AI_SERVER_CMD="${DVM_AI_SERVER_CMD:-llama-server}"
DVM_AI_SERVICE_NAME="${DVM_AI_SERVICE_NAME:-dvm-llama.service}"
DVM_AI_HOST="${DVM_AI_HOST:-0.0.0.0}"
DVM_AI_PORT="${DVM_AI_PORT:-8080}"
DVM_AI_MODELS_DIR="${DVM_AI_MODELS_DIR:-$DVM_GUEST_HOME/models}"
DVM_AI_DEFAULT_MODEL="${DVM_AI_DEFAULT_MODEL:-}"
# Space-separated alias=url entries. Aliases become model filenames in the VM.
# DVM_AI_MODELS="qwen=https://example.com/qwen.gguf"
DVM_AI_MODELS="${DVM_AI_MODELS:-}"
DVM_AI_EXTRA_ARGS="${DVM_AI_EXTRA_ARGS:-}"

DVM_GPG_DIR="${DVM_GPG_DIR:-$DVM_STATE/gpg}"
