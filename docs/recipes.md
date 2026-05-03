# Recipes

Recipes are guest-side Bash scripts. VM config files are host-side Bash files. Keep
that boundary clear.

## Host Config

Host config lives in `~/.config/dvm/vms/<name>.sh`:

```bash
DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=80GiB
DVM_CODE_DIR="~/code/app"
DVM_PORTS="3000:3000"

use node
use agent-user
use codex
```

`use <name>` only selects `recipes/<name>.sh`; it does not run the recipe on the host.

## Guest Recipes

Recipes run inside the VM through:

```bash
limactl shell dvm-app env ... bash -s
```

Rules:

- Recipes should be idempotent enough to rerun.
- Prefer package-manager installs, `mkdir -p`, and overwriting systemd units.
- Do not read host paths.
- Use `DVM_CODE_DIR` for project code.
- Keep tool-specific config close to the recipe that uses it.
- Do not add recipe metadata, dependency graphs, registries, or versioning.

## Built-In Recipes

`baseline` installs common shell tools: Git, Helix, lazygit, zsh, fzf, ripgrep, fd,
tmux, just, curl, wget, tar, gzip, unzip, and jq. Language runtimes live in their own
recipes.

`agent-user` creates `dvm-agent`, grants ACL access to `DVM_CODE_DIR`, creates an agent
scratch directory, and restricts common main-user secret paths. This is a
Unix-permissions guardrail, not a complete sandbox.

`codex`, `claude`, `opencode`, and `mistral` install hosted AI tools for `dvm-agent`
and expose wrappers in `/usr/local/bin`. Put `use agent-user` before these recipes.

`node` installs Node.js/npm and enables Corepack when available. `python` installs
Python, pip, and uv.

`chezmoi` applies public dotfiles over HTTPS:

```bash
DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"
use chezmoi
```

`llama` installs the llama service. Configure a dedicated VM:

```bash
DVM_CPUS=8
DVM_MEMORY=16GiB
DVM_DISK=120GiB
DVM_PORTS="8080:8080"
DVM_LLAMA_DEFAULT_MODEL="small"
DVM_LLAMA_MODELS="small=https://example.invalid/model.gguf"
DVM_LLAMA_MODELS_SHA256="small=..."

use llama
```

The recipe can manage several model URLs by alias, verifies checksums when provided,
and points the active model at `~/models/current.gguf`.

`cloudflared` installs Cloudflare Tunnel as a service. Configure a dedicated VM:

```bash
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB

use cloudflared
```

Apply with a token when configuring or recreating the VM:

```bash
CLOUDFLARED_TOKEN="..." dvm apply cloudflared
```

If you want host convenience, store the token in macOS Keychain yourself and pass it at
apply time:

```bash
security add-generic-password -a dvm -s cloudflared -w "$TOKEN"
CLOUDFLARED_TOKEN="$(security find-generic-password -a dvm -s cloudflared -w)" \
  dvm apply cloudflared
```

DVM does not provide a secret store command.

`dvm logs llama` and `dvm logs cloudflared` show the default service units for those
dedicated VMs.

## Project Hook

After selected recipes run, DVM checks for this guest file:

```text
$DVM_CODE_DIR/.dvm/apply.sh
```

If it exists, DVM runs it inside the VM. Use it for project-local setup that belongs in
the project repository.
