# Config

DVM config is Bash.

```text
~/.config/dvm/config.sh
~/.config/dvm/vms/<vm>.sh
~/.config/dvm/recipes/<name>.sh
```

Global config loads first. VM config overrides it.

## Example

```bash
# ~/.config/dvm/config.sh
DVM_DEFAULT_PACKAGES=(git ripgrep fd-find)
DVM_DEFAULT_RECIPES=(zsh fzf starship)
```

```bash
# ~/.config/dvm/vms/app.sh
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
DVM_PACKAGES=(tmux postgresql)
DVM_RECIPES=(node codex claude)
```

Private repos usually need `ssh-keys` first, then a manual clone inside the VM.
Use `DVM_GIT_REPO` only when Git credentials already work or for public HTTPS
repos.

## Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `DVM_TEMPLATE` | `template:fedora` | Lima template |
| `DVM_CPUS` | `2` | CPUs |
| `DVM_MEMORY` | `4` | GiB memory |
| `DVM_DISK` | `30` | GiB disk |
| `DVM_USER` | `developer` | main guest user |
| `DVM_AGENT_USER` | `dvm-agent` | agent recipe user |
| `DVM_DEFAULT_PACKAGES` | `()` | packages prepended to every VM |
| `DVM_DEFAULT_RECIPES` | `()` | recipes prepended to every VM |
| `DVM_PORTS` | `()` | `host:guest` port forwards |
| `DVM_PACKAGES` | `()` | VM packages |
| `DVM_RECIPES` | `()` | VM recipes |
| `DVM_SECRETS` | `()` | host env var names staged for recipes |
| `DVM_ENV` | `()` | non-secret env names exported to recipes |
| `DVM_GIT_REPO` | empty | optional first clone URL |
| `DVM_GIT_BRANCH` | empty | optional first clone branch |
| `DVM_USE_BASE` | `0` | clone from base for new VMs |
| `DVM_BASE_NAME` | `base` | base VM suffix |
| `DVM_BASE_PACKAGES` | `()` | base packages |
| `DVM_BASE_RECIPES` | `()` | base recipes |
| `DVM_PROJECT_HOOK` | `0` | run `.dvm/sync.sh` |
| `DVM_PROJECT_HOOK_PRIVILEGED` | `0` | run hook with provisioning privileges |
| `DVM_PROJECT_HOOK_GIT_CONFIG` | `0` | require `git config dvm.hook true` |
| `DVM_ALLOW_RECIPE_CONFLICTS` | `0` | allow declared recipe conflicts |

Names for VMs, users, and base names must start with a lowercase letter and
contain only lowercase letters, numbers, and hyphens.

## Secrets

```bash
DVM_RECIPES=(tailscale cloudflared)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY DVM_CLOUDFLARED_TOKEN)
```

```bash
DVM_TAILSCALE_AUTHKEY=tskey-... \
DVM_CLOUDFLARED_TOKEN=... \
dvm sync app
```

Recipes read secrets with `dvm_secret NAME`. Secret files are randomized under
`/run/dvm-secrets` and cleaned before clone/hooks.

## Built-in recipe settings

| Variable | Meaning |
| --- | --- |
| `DVM_CHEZMOI_REPO` | repo for `chezmoi` |
| `DVM_CHEZMOI_ROLE` | initial chezmoi `data.role`; defaults to VM name |
| `DVM_TAILSCALE_HOSTNAME` | hostname for `tailscale up` |
| `DVM_DOCKER_AGENT_ACCESS` | add agent user to Docker group when `1` |
| `DVM_CODEX_VERSION` | Codex npm version |
| `DVM_CLAUDE_CODE_VERSION` | Claude Code npm version |
| `DVM_OPENCODE_VERSION` | opencode npm version |
| `DVM_NPM_PREFIX` | user-owned npm prefix |
| `DVM_OLLAMA_URL`, `DVM_OLLAMA_SHA256` | verified Ollama binary |
| `DVM_MISTRAL_URL`, `DVM_MISTRAL_SHA256` | verified Mistral binary |

## Safety

DVM refuses config and user recipe files that are not owned by the current user
or are group/world writable.

```bash
chmod go-w ~/.config/dvm ~/.config/dvm/config.sh ~/.config/dvm/vms/app.sh
```

`DVM_ENV` rejects secrets and dangerous names such as `PATH`, `BASH_ENV`,
`LD_*`, and `GIT_*`.
