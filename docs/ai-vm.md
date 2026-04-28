# Local llama.cpp AI VM

`dvm ai` manages an opinionated llama.cpp VM. It still uses a normal DVM VM under the
hood, named `ai` by default, but adds package install, model download, model switching,
and a managed `llama-server` systemd service.

Hosted AI coding tools such as Claude Code and Codex CLI are separate. Run those
through [`dvm agent`](ai-tools.md).

## Config

Defaults:

```bash
DVM_AI_NAME="ai"
DVM_AI_PORT="8080"
DVM_AI_DEFAULT_MODEL="qwen25-coder-7b-q4"
DVM_AI_MODELS="qwen25-coder-7b-q4=https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf?download=true"
```

Other useful knobs:

```bash
DVM_AI_PACKAGES="llama-cpp curl"
DVM_AI_SERVER_CMD="llama-server"
DVM_AI_SERVICE_NAME="dvm-llama.service"
DVM_AI_HOST="0.0.0.0"
DVM_AI_MODELS_DIR="$DVM_GUEST_HOME/models"
DVM_AI_EXTRA_ARGS=""
```

Model entries are space-separated `alias=url` pairs. Aliases become filenames in the
VM, so `qwen=https://...` is saved as `qwen.gguf`.

## Create

```bash
dvm ai create
```

This creates `dvm-ai`, installs Fedora's `llama-cpp` package, writes a systemd service
for `llama-server`, downloads configured models, points `current.gguf` at
`DVM_AI_DEFAULT_MODEL`, and restarts the service.

Use a non-default VM name:

```bash
dvm ai create lab
```

## Manage Models

```bash
dvm ai models
dvm ai pull qwen25-coder-7b-q4
dvm ai use qwen25-coder-7b-q4
```

For a non-default AI VM:

```bash
dvm ai use --vm lab qwen25-coder-7b-q4
```

The active model is the `current.gguf` symlink under `DVM_AI_MODELS_DIR`.

## Service And Host

Check status:

```bash
dvm ai status
```

Print host URLs:

```bash
dvm ai host
```

Reapply service configuration:

```bash
dvm ai setup
```
