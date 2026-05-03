# shellcheck shell=bash
# shellcheck disable=SC2034,SC2088
# Dedicated llama VM.

DVM_CPUS=8
DVM_MEMORY=16GiB
DVM_DISK=120GiB
DVM_CODE_DIR="~/code/llama"
DVM_PORTS="8080:8080"
DVM_LLAMA_HOST="0.0.0.0"
DVM_LLAMA_PORT=8080

# Optional model downloads:
# DVM_LLAMA_DEFAULT_MODEL="small"
# DVM_LLAMA_MODELS="small=https://example.invalid/model.gguf"
# DVM_LLAMA_MODELS_SHA256="small=..."

use llama
