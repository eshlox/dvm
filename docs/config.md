# Config

DVM config is Bash. Global config is sourced first, then per-VM config.

```text
~/.config/dvm/config.sh
~/.config/dvm/vms/<vm>.sh
~/.config/dvm/recipes/<name>.sh
```

## Global Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `DVM_TEMPLATE` | `template:fedora` | Lima template passed to `limactl start` |
| `DVM_CPUS` | `2` | default VM CPU count |
| `DVM_MEMORY` | `4` | default memory in GiB |
| `DVM_DISK` | `30` | default disk in GiB |
| `DVM_USER` | `developer` | primary guest user |
| `DVM_AGENT_USER` | `dvm-agent` | user created by the `agent-user` recipe |
| `DVM_DEFAULT_PACKAGES` | `()` | packages prepended to every VM |
| `DVM_DEFAULT_RECIPES` | `()` | recipes prepended to every VM |
| `DVM_ENV` | `()` | non-secret variable names exported into the guest script |
| `DVM_USE_BASE` | `0` | clone from the base VM when set to `1` |
| `DVM_BASE_NAME` | `base` | base Lima instance suffix |
| `DVM_BASE_PACKAGES` | `()` | packages installed by `dvm base build` |
| `DVM_BASE_RECIPES` | `()` | recipes run by `dvm base build` |
| `DVM_PROJECT_HOOK` | `1` | run `$DVM_CODE_DIR/.dvm/sync.sh` when present |
| `DVM_PROJECT_HOOK_PRIVILEGED` | `0` | run the project hook in the provisioning context |
| `DVM_PROJECT_HOOK_GIT_CONFIG` | `0` | require repo-local `git config dvm.hook true` before running hooks |
| `DVM_ALLOW_RECIPE_CONFLICTS` | `0` | allow recipes with declared conflicts |

DVM supports Lima's latest Fedora template and `dnf5` inside the guest only.
Changing `DVM_TEMPLATE` to another distro is unsupported unless your own
recipes also handle that distro.

`DVM_USER`, `DVM_AGENT_USER`, `DVM_BASE_NAME`, and VM names must start with a
lowercase letter and contain only lowercase letters, numbers, and hyphens.

## Per-VM Variables

| Variable | Meaning |
| --- | --- |
| `DVM_CPUS`, `DVM_MEMORY`, `DVM_DISK` | optional resource overrides |
| `DVM_PORTS` | `host_port:guest_port` forwards |
| `DVM_PACKAGES` | plain distro packages |
| `DVM_RECIPES` | built-in or user recipe names |
| `DVM_SECRETS` | host env var names staged into private guest runtime files |
| `DVM_ENV` | non-secret config/env var names exported into the guest script |
| `DVM_GIT_REPO` | optional repo cloned into `/home/<user>/code/<vm>` |
| `DVM_GIT_BRANCH` | optional branch for the first clone |
| `DVM_PROJECT_HOOK`, `DVM_PROJECT_HOOK_PRIVILEGED`, `DVM_PROJECT_HOOK_GIT_CONFIG` | optional project hook overrides |

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
DVM_RECIPES=(zsh fzf node codex)
DVM_GIT_REPO="git@github.com:me/app.git"
```

`dvm new` now starts with `DVM_RECIPES=(zsh fzf)`. AI/npm recipes are
commented examples because they install third-party tooling, even though the
built-ins are pinned and user-local.

## Guest Environment

DVM always exports core variables such as `DVM_NAME`, `DVM_USER`, and
`DVM_CODE_DIR` into the guest script. Some built-in recipe config is exported
automatically when set, including `DVM_CHEZMOI_REPO`, `DVM_TAILSCALE_HOSTNAME`,
the pinned npm version overrides, and verified installer URL/checksum settings.

For user recipes, list additional non-secret variable names in `DVM_ENV`:

```bash
MY_TOOL_CHANNEL=nightly
DVM_ENV=(MY_TOOL_CHANNEL)
```

Do not put tokens or passwords in `DVM_ENV`; DVM rejects names that are also
listed in `DVM_SECRETS`. DVM also rejects dangerous names and prefixes that can
change shell or tool execution, including `PATH`, `BASH_ENV`, `LD_*`, and
`GIT_*`. `DVM_ENV` is for simple recipe settings, not for secret paths or a
general environment import.

## Built-In Recipe Settings

Some built-in recipe variables are exported automatically when set on the host
or in config:

| Variable | Meaning |
| --- | --- |
| `DVM_CHEZMOI_REPO` | source repo for the `chezmoi` recipe |
| `DVM_TAILSCALE_HOSTNAME` | hostname passed to `tailscale up` |
| `DVM_DOCKER_AGENT_ACCESS` | add `DVM_AGENT_USER` to the Docker group when `1` |
| `DVM_CODEX_VERSION`, `DVM_CLAUDE_CODE_VERSION`, `DVM_OPENCODE_VERSION` | override pinned npm package versions |
| `DVM_NPM_PREFIX` | user-owned prefix for built-in npm recipes |
| `DVM_OLLAMA_URL`, `DVM_OLLAMA_SHA256` | verified Ollama binary source |
| `DVM_MISTRAL_URL`, `DVM_MISTRAL_SHA256` | verified Mistral CLI binary source |

## Project Hooks

DVM runs `$DVM_CODE_DIR/.dvm/sync.sh` after packages, recipes, secret cleanup,
and the optional first clone. The hook runs as `DVM_USER` by default:

```bash
DVM_PROJECT_HOOK=1
DVM_PROJECT_HOOK_PRIVILEGED=0
DVM_PROJECT_HOOK_GIT_CONFIG=0
```

Set `DVM_PROJECT_HOOK=0` to disable project hooks for a VM. Setting
`DVM_PROJECT_HOOK_PRIVILEGED=1` runs project-controlled code in the provisioning
context and prints a warning in dry-run output; use it only for repositories
you fully trust. Set `DVM_PROJECT_HOOK_GIT_CONFIG=1` to require the project
repo itself to opt in with:

```bash
git config dvm.hook true
```

## Secrets

Secrets are not stored in config. List env var names in `DVM_SECRETS` and pass
the values only when syncing:

```bash
DVM_RECIPES=(tailscale cloudflared)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY DVM_CLOUDFLARED_TOKEN)
```

```bash
DVM_TAILSCALE_AUTHKEY=tskey-... \
DVM_CLOUDFLARED_TOKEN=... \
dvm sync demo
```

Inside recipes, use `dvm_secret DVM_TAILSCALE_AUTHKEY` to get the randomized
staged file path. Secret names must match `[A-Za-z_][A-Za-z0-9_]*`.

Staged secret files are removed before DVM runs the optional project clone or
`$DVM_CODE_DIR/.dvm/sync.sh` hook.

## Config File Safety

DVM config is Bash code. Before sourcing global config, VM config, or user
recipe overrides, DVM requires the file and containing config directory to be
owned by the current user and not group/world writable. A typical repair is:

```bash
chmod go-w ~/.config/dvm ~/.config/dvm/config.sh ~/.config/dvm/vms/app.sh
```
