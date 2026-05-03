# Example project VM. Copy to ~/.config/dvm/vms/<name>.sh and edit.

DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=80GiB
DVM_CODE_DIR="~/code/$DVM_NAME"
DVM_PORTS="3000:3000 5173:5173"
DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"

use node
use python
use agent-user
use codex
use claude
use chezmoi
