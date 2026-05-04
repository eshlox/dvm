# shellcheck shell=bash
# shellcheck disable=SC2034,SC2088
# Global DVM defaults. Copy to ~/.config/dvm/config.sh and edit there.

DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=80GiB
DVM_ARCH=default
DVM_USER="${USER:-developer}"
DVM_CODE_ROOT="~/code"
DVM_HOST_IP="127.0.0.1"
DVM_AI_AGENT_USER="dvm-agent"
# Claude defaults to unattended bypass mode inside the dvm-agent Bubblewrap sandbox.
# Set to 0 in a VM config when you want Claude permission prompts.
# DVM_CLAUDE_BYPASS=1

# Optional chezmoi [data] values for VMs that use the chezmoi recipe:
# DVM_CHEZMOI_ROLE="vm"
# DVM_CHEZMOI_NAME="Your Name"
# DVM_CHEZMOI_EMAIL="you@example.com"
