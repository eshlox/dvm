# DVM

Keep your friends close, your supply chain in a VM.

DVM is a small Bash script around Lima. It creates one Fedora VM per project,
runs a fixed list of shell recipes inside it, and gets out of the way.

The model has three nouns:

- **Packages** — distro package names listed in `DVM_PACKAGES`. Installed once
  per sync with the guest package manager.
- **Recipes** — shell behavior files under `share/dvm/recipes/`. Listed in
  `DVM_RECIPES` in the order they should run.
- **Secrets** — env-var names listed in `DVM_SECRETS`. Each value is staged
  through stdin into a mode-`0600` guest file (`/tmp/dvm-secret-<NAME>`)
  before recipes run; values never appear in argv or env.

## Install

Requirements:

- Lima 1.0+ (`brew install lima` on macOS, `dnf install lima` on Fedora)
- bash, flock, envsubst, sudo
- a Unix host (macOS aarch64 or Linux aarch64/x86_64)

```bash
./install.sh
```

This writes a single symlink: `~/.local/bin/dvm -> $REPO/bin/dvm`. There is
no copy. `git pull` in this repo is the update. Override the destination
with `PREFIX=/somewhere/else ./install.sh`.

## Quick start

```bash
dvm new app             # writes ~/.config/dvm/vms/app.sh, opens $EDITOR
dvm sync app            # create + start + provision the Lima instance
dvm sh app              # interactive shell
dvm                     # alias for `dvm ls`
```

## Commands

```text
dvm sync <vm> | --all   create/start the Lima instance and run recipes
dvm sh <vm>             interactive shell (exec limactl shell)
dvm ssh <vm> -- cmd...  non-interactive command
dvm cp src dst          copy; one side may be vm:path
dvm log <vm> [-f]       guest journalctl
dvm ls [<vm>]           list configured/running VMs (optional filter)
dvm rm <vm> --yes       stop and delete the Lima instance (backs up VM keys)
dvm stop <vm> | --all   stop running VMs
dvm ssh-key <vm>        generate guest SSH keys (access + signing)
dvm gpg-key <vm>        generate guest GPG signing key
dvm new <vm>            write stub config, open $EDITOR
dvm edit <vm>           edit per-VM config
dvm config edit|show    edit/print global config
dvm recipes             list available recipes
```

`DVM_DRY_RUN=1 dvm sync <vm>` prints the rendered guest script and exits
without contacting Lima.

## Config

Global, sourced first (optional):

```bash
# ~/.config/dvm/config.sh
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=10GiB
DVM_CODE_ROOT="~/code"        # guest path; ~ expands to the guest user's home
DVM_HOST_IP=127.0.0.1
DVM_USER=developer
DVM_AGENT_USER=dvm-agent
DVM_DEFAULT_PACKAGES=(git tmux)
DVM_DEFAULT_RECIPES=(zsh-login-shell agent-user codex)
```

Per VM, sourced after global:

```bash
# ~/.config/dvm/vms/app.sh
DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=30GiB
DVM_PORTS=(3000:3000 5173:5173)
DVM_PACKAGES=(bat fzf helix)             # appended to DVM_DEFAULT_PACKAGES
DVM_RECIPES=(node-corepack)              # appended to DVM_DEFAULT_RECIPES
# DVM_SECRETS=(DVM_CLOUDFLARED_TOKEN)
# DVM_CODE_DIR="~/code/app"              # default: $DVM_CODE_ROOT/$DVM_NAME
```

Validation is "bash sources the file"; a typo raises a bash error on the
next `dvm sync`. Re-open `$EDITOR` and try again. VM names match
`^[a-z][a-z0-9-]*$`. Memory and disk are passed to Lima verbatim, so any
size Lima accepts works.

## Recipes

A recipe is a `<name>.sh` shell snippet. User recipes at
`~/.config/dvm/recipes/<name>.sh` override built-ins of the same name.
`dvm sync` cats them into one bash stream, after a small helper prelude and
the `dvm_pkg` call for `DVM_PACKAGES`. The execution order is the order of
names in `DVM_RECIPES` — there is no topological sort, no `requires` field.
`agent-user` must precede `codex`, `claude`, `opencode`, `mistral`.

Built-in recipes (the ones that earn their own file):

- AI tooling: `agent-user`, `codex`, `claude`, `opencode`, `mistral`
- Services: `llama`, `cloudflared`, `tailscale`, `docker`
- Pinned binaries: `lazygit`, `starship`, `zellij`, `yazi`
- Other behavior: `chezmoi`, `zsh-login-shell`, `node-corepack`

Everything else (`bat`, `fzf`, `git`, `git-delta`, `helix`, `just`,
`python3`, `tmux`, etc.) is just a package name in `DVM_PACKAGES`. No file
needed.

### Helper prelude

Recipes can use these helpers, defined in the prelude `bin/dvm` generates:

- `dvm_die <msg>` / `dvm_recipe_die <recipe> <msg>` / `dvm_recipe_warn ...`
- `dvm_pkg <pkgs...>` — invokes dnf5 / dnf / apt-get under sudo
- `dvm_secret <ENV_VAR>` — prints the staged guest file path
- `dvm_recipe_bool <recipe> <name> <value>` — normalises 1/0/true/false
- `dvm_recipe_require_agent_user <recipe>` — fails if agent-user didn't run
- `dvm_recipe_validate_port` / `validate_service` / `validate_sha256`
- `dvm_recipe_arch` — prints `aarch64` or `x86_64`
- `dvm_download_verified <url> <sha256> <out>` — curl + sha256sum -c
- `dvm_install_pinned <name> <arm_url> <arm_sha> <x86_url> <x86_sha> <tar|zip> <bins...>`

Exported variables: `DVM_VM`, `DVM_USER`, `DVM_AGENT_USER`, `DVM_CODE_DIR`,
`DVM_HOST_IP`, `DVM_PORTS` (comma-separated), `DVM_RECIPE` (current recipe
name).

### Project hook

If `<DVM_CODE_DIR>/.dvm/sync.sh` exists, it runs last, after all recipes,
in the directory `DVM_CODE_DIR` as the primary user.

## Service VMs

**llama** — dedicated llama.cpp server. Set the model URL + sha256 in the
per-VM config:

```bash
DVM_RECIPES=(llama)
DVM_PORTS=(8080:8080)
DVM_LLAMA_MODEL_URL="https://example.invalid/model.gguf"
DVM_LLAMA_MODEL_SHA256="0000...64hex"
# Optional: DVM_LLAMA_HOST=127.0.0.1, DVM_LLAMA_PORT=8080
```

**cloudflared** — tunnel runner. Stage the token through `DVM_SECRETS`:

```bash
DVM_RECIPES=(cloudflared)
DVM_SECRETS=(DVM_CLOUDFLARED_TOKEN)
# At sync time:
DVM_CLOUDFLARED_TOKEN="..." dvm sync cloud
```

**tailscale** — tailnet membership and optional Funnel. First-time auth
needs `DVM_TAILSCALE_AUTHKEY`:

```bash
DVM_RECIPES=(tailscale)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY)
# Optional: DVM_TAILSCALE_HOSTNAME, DVM_TAILSCALE_FUNNEL_TARGET=https://...
DVM_TAILSCALE_AUTHKEY="tskey-..." dvm sync tailscale
```

## Layout

```
bin/dvm                       single-file bash program
install.sh                    symlink installer
share/dvm/lima.yaml.in        Lima YAML template (envsubst placeholders)
share/dvm/config.sh.example   starter global config
share/dvm/recipes/*.sh        built-in recipes
share/dvm/prelude.sh          helper prelude embedded into each guest script
tests/smoke.sh                end-to-end test with a fake limactl
```

## Tests

```bash
bash tests/smoke.sh
```

Runs the full command surface against a fake `limactl` shim and asserts
that argv, rendered YAML, and the piped guest script all look right. No
real VM is touched.

## License

MIT. See `LICENSE`.
