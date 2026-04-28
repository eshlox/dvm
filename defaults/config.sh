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

DVM_GPG_DIR="${DVM_GPG_DIR:-$DVM_STATE/gpg}"
