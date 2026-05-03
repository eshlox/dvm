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
