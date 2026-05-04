# shellcheck shell=bash
# shellcheck disable=SC2034,SC2088
# Example project VM. Copy to ~/.config/dvm/vms/<name>.sh and edit.

DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=80GiB
DVM_CODE_DIR="~/code/$DVM_NAME"
DVM_PORTS="3000:3000 5173:5173"
DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"
# Optional overrides when you use non-default `dvm ssh-key` paths:
# DVM_CHEZMOI_SIGNING_KEY="~/.ssh/id_ed25519_dvm_signing.pub"
# DVM_CHEZMOI_DEPLOY_KEY="~/.ssh/id_ed25519_dvm.pub"

use node
use python
use agent-user
use codex
use claude
use chezmoi
