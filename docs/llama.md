# Llama

Use the built-in `llama.sh` recipe for one llama.cpp model served from one VM.

```bash
dvm init ai
dvm edit ai
```

`~/.config/dvm/vms/ai.sh`:

```bash
DVM_PORTS="8080:8080"
DVM_SETUP_SCRIPTS="llama.sh"
DVM_LLAMA_HOST="0.0.0.0"
DVM_LLAMA_MODELS="
qwen=https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf
"
DVM_LLAMA_DEFAULT_MODEL="qwen"
```

Create:

```bash
dvm create ai
```

Open:

```text
http://127.0.0.1:8080
```

From another DVM VM:

```bash
curl http://lima-dvm-ai.internal:8080
```

`DVM_LLAMA_HOST="0.0.0.0"` is required for VM-to-VM access. Without it, llama listens
only on loopback inside the `ai` VM.

## Models

The recipe uses Fedora's `llama-cpp` package and runs:

```bash
llama-server -m ~/models/current.gguf
```

DVM supports one active model. `DVM_LLAMA_MODELS` can list aliases, but only
`DVM_LLAMA_DEFAULT_MODEL` is downloaded and served.

Example catalog:

```bash
DVM_LLAMA_MODELS="
qwen=https://example.com/qwen.gguf
deepseek=https://example.com/deepseek.gguf
mistral=https://example.com/mistral.gguf
"
DVM_LLAMA_DEFAULT_MODEL="qwen"
```

Run setup:

```bash
dvm setup ai
```

The selected model is saved as `~/models/<alias>.gguf`, and `~/models/current.gguf`
points to it.

## Switching

Change the selected alias:

```bash
DVM_LLAMA_DEFAULT_MODEL="deepseek"
```

Then rerun:

```bash
dvm setup ai
```

That downloads the selected model if needed, updates `current.gguf`, and restarts the
service.

If you change the URL for an alias, `dvm setup ai` redownloads that model. To force a
redownload from the same URL, temporarily set:

```bash
DVM_LLAMA_REFRESH="1"
```

## Router Mode

llama.cpp router mode can load and switch models dynamically with
`llama-server --models-dir`, but Fedora 43 currently ships an older `llama-cpp` build
without that option. DVM does not build llama.cpp from source because that made the
recipe larger, slower, and less reliable on aarch64.

When Lima's Fedora template moves to a Fedora release with a new enough `llama-cpp`,
DVM can revisit router mode.

## Troubleshooting

If `dvm list` shows `PORTS` as `-`, the VM has no host port forward. Add
`DVM_PORTS="8080:8080"` to `~/.config/dvm/vms/ai.sh`, then rerun:

```bash
dvm setup ai
```

If the port exists but the page still does not load, check the service:

```bash
dvm ssh ai sudo systemctl status dvm-llama.service
dvm ssh ai sudo journalctl -u dvm-llama.service -f
```

If model download fails with HTTP 400/403, copy the printed URL and test it directly.
Some Hugging Face files move, become gated, or require a different GGUF filename:

```bash
dvm ssh ai curl -fL 'https://huggingface.co/.../resolve/main/model.gguf' -o /tmp/model.gguf
```
