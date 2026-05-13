# Config

DVM config is plain Bash sourced on the host. There are two files:

- `~/.config/dvm/config.sh` — global defaults (optional)
- `~/.config/dvm/vms/<vm>.sh` — one file per VM

Global is sourced first, then the per-VM file. A typo raises a Bash error
on the next `dvm sync`; re-open `$EDITOR` and fix.

## Three nouns

| Variable | What it is |
|---|---|
| `DVM_PACKAGES` | Distro package names. Installed via `dvm_pkg "${DVM_PACKAGES[@]}"` once per sync, before recipes run. |
| `DVM_RECIPES` | Recipe names. Each maps to a `<name>.sh` under `share/dvm/recipes/` (built-in) or `~/.config/dvm/recipes/` (user override). Array order = execution order. |
| `DVM_SECRETS` | Env-var names. For each name, the host process value is piped to `/tmp/dvm-secret-<NAME>` (mode 0600) inside the guest before recipes run. Recipes read via `dvm_secret <NAME>`. |

The per-VM `DVM_PACKAGES`/`DVM_RECIPES` arrays are **appended** to the
corresponding `DVM_DEFAULT_*` from global. Use the appended form to
inherit globals:

```bash
DVM_PACKAGES=("${DVM_DEFAULT_PACKAGES[@]}" bat fzf helix)
DVM_RECIPES=("${DVM_DEFAULT_RECIPES[@]}" node-corepack)
```

To replace instead of append, just don't expand the default.

## All variables

### Global (`~/.config/dvm/config.sh`)

| Variable | Default | Meaning |
|---|---|---|
| `DVM_CPUS` | `2` | Default vCPUs for new VMs |
| `DVM_MEMORY` | `"2GiB"` | Default memory (passed to Lima as-is) |
| `DVM_DISK` | `"10GiB"` | Default disk |
| `DVM_CODE_ROOT` | `"~/code"` | Guest-side root; per-VM `DVM_CODE_DIR` defaults to `$DVM_CODE_ROOT/$DVM_NAME` |
| `DVM_HOST_IP` | `127.0.0.1` | Bind IP for forwarded ports |
| `DVM_USER` | `developer` | Primary guest user |
| `DVM_AGENT_USER` | `dvm-agent` | Account used by the AI tool sandbox |
| `DVM_DEFAULT_PACKAGES` | `()` | Packages every VM gets |
| `DVM_DEFAULT_RECIPES` | `()` | Recipes every VM runs |

### Per VM (`~/.config/dvm/vms/<vm>.sh`)

| Variable | Default | Meaning |
|---|---|---|
| `DVM_CPUS` | (global) | Override CPUs for this VM |
| `DVM_MEMORY` | (global) | Override memory |
| `DVM_DISK` | (global) | Override disk |
| `DVM_USER` | (global) | Primary guest user |
| `DVM_CODE_DIR` | `$DVM_CODE_ROOT/$DVM_NAME` | Guest project path; `~` = guest user's home |
| `DVM_PORTS` | `()` | Two-part `host:guest` forwards; bind IP is `DVM_HOST_IP` |
| `DVM_PACKAGES` | `()` | Appended to globals |
| `DVM_RECIPES` | `()` | Appended to globals |
| `DVM_SECRETS` | `()` | Env-var names to stage |

VM names match `^[a-z][a-z0-9-]*$`.

## Tilde expansion

`~` in any DVM path means the **guest** user's home. The script rewrites
`~/foo` to `/home/$DVM_USER/foo` before passing it to the guest. Use `~`
or `$DVM_CODE_ROOT`, not `$HOME`, when referencing guest paths.

## Examples

Minimal app VM:

```bash
# ~/.config/dvm/vms/app.sh
DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=30GiB
DVM_PORTS=(3000:3000)
DVM_PACKAGES=(git tmux nodejs npm)
```

App VM that inherits a global toolset:

```bash
# ~/.config/dvm/config.sh
DVM_DEFAULT_PACKAGES=(git tmux helix bat fzf)
DVM_DEFAULT_RECIPES=(zsh-login-shell agent-user codex)

# ~/.config/dvm/vms/app.sh
DVM_PORTS=(3000:3000)
DVM_PACKAGES=("${DVM_DEFAULT_PACKAGES[@]}" nodejs npm)
DVM_RECIPES=("${DVM_DEFAULT_RECIPES[@]}" node-corepack)
```

Service VM with a secret:

```bash
# ~/.config/dvm/vms/cloud.sh
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_RECIPES=(cloudflared)
DVM_SECRETS=(DVM_CLOUDFLARED_TOKEN)
```

```bash
DVM_CLOUDFLARED_TOKEN="$(op read op://Personal/cf/token)" dvm sync cloud
```
