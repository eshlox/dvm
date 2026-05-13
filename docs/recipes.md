# Recipes

Recipes are guest-side Bash. Per-VM config files are host-side Bash.
Keep that boundary clear.

## How sync uses them

For each `dvm sync`:

1. The host prelude (defined in `bin/dvm`) is emitted first: helper
   functions, exported env, idempotent baseline.
2. `dvm_pkg "${DVM_PACKAGES[@]}"` runs once.
3. Each name in `DVM_RECIPES` is looked up (`user override`, else
   built-in) and its file is concatenated into the stream.
4. The whole stream is piped to `limactl shell dvm-<vm> sudo -u $DVM_USER
   bash -s`.

There is no topological sort. The array order **is** the execution order.
`agent-user` must come before `codex`/`claude`/`opencode`/`mistral`.

## Resolution

| Path | Wins over |
|---|---|
| `~/.config/dvm/recipes/<name>.sh` | built-in by the same name |
| `$DVM_SHARE/recipes/<name>.sh` | last resort |

Unknown name → `dvm sync` aborts with `unknown recipe: <name>`.

## Authoring rules

- Idempotent. The same recipe may run on every sync; assume the VM is
  already partly set up.
- Use `dvm_pkg` instead of `sudo dnf install -y` so a future Debian/Arch
  port keeps working.
- Use `dvm_secret <ENV>` to read a staged secret, not the raw env var.
- Use `dvm_recipe_die <recipe> "<msg>"` for fatal errors so the message
  carries the recipe name.
- Write a one-line description as the first line:
  `# Description: <one line>`. `dvm recipes` will show it.

## Helper prelude

These functions and variables are available to every recipe. Treat
anything not listed here as an implementation detail; do not rely on
private helpers between recipes (other than functions intentionally
defined by an earlier recipe — `dvm_agent_write_wrapper` from
`agent-user`, for example).

### Functions

| Helper | Purpose |
|---|---|
| `dvm_die <msg>` | print to stderr and exit 1 |
| `dvm_recipe_die <recipe> <msg>` | same, prefixed with recipe name |
| `dvm_recipe_warn <recipe> <msg>` | warn, do not exit |
| `dvm_pkg <pkg>...` | install packages with the guest package manager |
| `dvm_secret <ENV>` | print the staged guest temp file path for an env name |
| `dvm_recipe_bool <recipe> <name> <value>` | normalize 1/0/true/false |
| `dvm_recipe_require_agent_user <recipe>` | fail if agent-user did not run earlier |
| `dvm_recipe_validate_port <recipe> <port>` | int in 1..65535 |
| `dvm_recipe_validate_service <recipe> <unit>` | name ends in `.service`, safe chars |
| `dvm_recipe_validate_sha256 <recipe> <hex>` | 64-char hex digest |
| `dvm_recipe_arch <recipe>` | print `aarch64` or `x86_64` |
| `dvm_download_verified <url> <sha256> <out>` | curl, then `sha256sum -c` |
| `dvm_install_pinned <name> <arm_url> <arm_sha> <x86_url> <x86_sha> <tar\|zip> <bins...>` | full pinned-binary install |

### Environment

| Variable | Value |
|---|---|
| `DVM_VM` | VM name (no `dvm-` prefix) |
| `DVM_USER` | primary guest user |
| `DVM_AGENT_USER` | account used by the AI sandbox |
| `DVM_CODE_DIR` | guest code dir (already expanded) |
| `DVM_HOST_IP` | bind IP for forwarded ports |
| `DVM_PORTS` | comma-separated `host:guest` list |
| `DVM_RECIPE` | name of the currently executing recipe |

## Built-in recipes

Recipes earn their own file when they do behavior beyond `dnf install`.

| Recipe | Why it's a recipe |
|---|---|
| `agent-user` | creates a non-login agent account with Bubblewrap sandbox |
| `codex` / `claude` / `opencode` / `mistral` | install CLI + write sandbox wrapper |
| `llama` | systemd unit + optional model download |
| `cloudflared` | systemd unit + secret token wiring |
| `tailscale` | first-time auth, optional Funnel target |
| `docker` | repo + group membership + service enable |
| `lazygit` / `starship` / `zellij` / `yazi` | pinned-binary install with sha256 |
| `zsh-login-shell` | install zsh and `usermod --shell` |
| `node-corepack` | install nodejs/npm and pin corepack |
| `chezmoi` | install + clone + apply |

Plain `dnf install -y <pkg>` work goes in `DVM_PACKAGES`, not a recipe.

## Authoring a new recipe

`~/.config/dvm/recipes/my-tool.sh`:

```bash
# Description: my private toolchain
dvm_pkg ripgrep fd-find
curl -fsSL https://example.invalid/install.sh | sudo bash
```

Add it to a VM:

```bash
DVM_RECIPES=(my-tool)
```

If your recipe depends on `agent-user`, place it after `agent-user` in
`DVM_RECIPES` and call `dvm_recipe_require_agent_user my-tool` near the
top so the failure mode is obvious.

## Project hook

`<DVM_CODE_DIR>/.dvm/sync.sh` runs last on every sync, as the primary
user, with `cwd = $DVM_CODE_DIR`. Use it for repo-specific setup (run
migrations, prepare local dev data, etc.). The hook has the same helper
prelude available.
