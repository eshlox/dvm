# DVM Plan: Minimal Lima Wrapper

This plan defines DVM as a personal, minimal Lima wrapper. The goal is one VM per
project, the same baseline tools in every VM, optional per-project setup, AI and
services inside VMs, and easy updates.

The test sentence for every design decision:

> DVM renders one Lima VM, starts it, sources one VM config on the host, and runs shell
> recipes inside the guest.

If a feature does not fit that sentence, it is probably out of scope.

## Goals

- Keep host setup small: Lima, DVM wrapper, config, and docs.
- Keep development tools inside project VMs: editors, Git helpers, language tools, AI
  CLIs, services, and credentials should run from the guest.
- Make every VM consistent through one implicit baseline recipe.
- Allow per-project differences through small host config files.
- Make reusable setup plain guest shell recipes.
- Keep code lines low; documentation can be larger than code.
- Make updates easy: edit recipes, then run `dvm apply --all`.

## Non-Goals

- General VM platform behavior.
- Typed config schema, catalog metadata, or explain topics.
- Terraform-style planning, reports, action tiers, or audit logs.
- Backup/restore as a core feature.
- Secret store abstraction.
- Recipe dependency graph, registry, metadata, validation, or versioning.
- Multi-platform support beyond the host currently used with Lima.

## File Layout

The implementation has only three important file kinds: wrapper, host config, and guest
recipes.

```text
bin/dvm

~/.config/dvm/
  config.sh
  lima.yaml.in
  recipes/
    baseline.sh
    node.sh
    python.sh
    agent-user.sh
    codex.sh
    claude.sh
    opencode.sh
    mistral.sh
    chezmoi.sh
    llama.sh
    cloudflared.sh
  vms/
    app.sh
    llama.sh
    cloudflared.sh
```

Optional project-local setup can live in the project repository inside the VM:

```text
~/code/app/.dvm/apply.sh
```

There is no separate `setup.sh`. The baseline setup is just
`recipes/baseline.sh`, and DVM runs it first unless disabled.

## Host And Guest Boundary

This boundary must stay simple and explicit.

- `config.sh` is sourced on the host before the VM config.
- `vms/<name>.sh` is sourced on the host.
- `use <recipe>` is a host function. It only appends `recipes/<recipe>.sh` to an
  ordered list. It does not run the recipe.
- After host config is sourced, DVM renders the Lima template if the VM is missing.
- DVM concatenates `baseline.sh`, each selected recipe, and a fixed guest-side check
  for `.dvm/apply.sh` inside the configured code directory.
- The concatenated shell is piped into `limactl shell <vm> env ... bash -s`.
- Recipes are guest scripts. They should not read host paths or call host tools.
- `~` in DVM variables always means the guest user's home. The wrapper does not expand
  it on the host.
- `mounts: []` means host code is not mounted into the guest. Code lives inside VMs and
  is fetched from Git remotes by hand or by recipes. Use `dvm enter` and guest tools to
  edit it.

This keeps the wrapper as the bridge and prevents a recipe system from growing inside
the project.

## Command Surface

DVM's main workflow is still small:

```bash
dvm apply app
dvm apply --all
dvm enter app
dvm ssh app -- command
dvm list
dvm rm app --yes
```

There are three practical helpers because they avoid repeated long `dvm ssh` commands
without changing the design:

```bash
dvm logs cloudflared
dvm ssh-key app
dvm gpg-key app
```

Command behavior:

- `dvm apply app`: create the VM if missing, start it, then run baseline and selected
  recipes. If the VM already exists, update Lima port forwards from `DVM_PORTS`.
- `dvm apply --all`: apply every `~/.config/dvm/vms/*.sh` config in alphabetical
  order, continue after failures, exit non-zero if any VM failed, and print a one-line
  summary at the end.
- `dvm enter app`: open an interactive shell in the configured code directory.
- `dvm ssh app -- command`: run one command inside the VM from the configured code
  directory.
- `dvm list`: show Lima's VM list filtered to `dvm-` instances.
- `dvm logs app [unit]`: show `journalctl` from inside the VM; infer llama or
  cloudflared units when exactly one known service recipe is configured.
- `dvm ssh-key app`: create or reuse a VM-local SSH key and print the public key.
- `dvm gpg-key app`: create or reuse a VM-local GPG signing key and print the public
  key plus fingerprint.
- `dvm rm app --yes`: delete the Lima VM after a nested Git dirty check. The flag is
  required; `--force` skips the dirty check.

Commands intentionally omitted:

- `new`: `apply` creates missing VMs, so `new` is a separate mental step without much
  value.
- `backup`, `restore`, `recreate`: code should live in Git, AI auth is regenerable,
  Cloudflare tokens can be re-entered or optionally read from Keychain, and recipes
  should recreate VM state. Recreate is `dvm rm app --yes && dvm apply app`.
- `ports`: Lima already stores and displays port state; use `limactl list` or inspect
  the VM config directly if needed.
- `completion`: shell completion can be a documented one-liner until it becomes painful.
- `doctor`: if `limactl list` fails, the host is not ready.
- `plan`: apply is visible shell output and should be idempotent enough.

## Global Config

`~/.config/dvm/config.sh` should stay small:

```bash
DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=80GiB
DVM_ARCH=default
DVM_USER="${USER:-developer}"
DVM_CODE_ROOT="~/code"
DVM_HOST_IP="127.0.0.1"
DVM_AI_AGENT_USER="dvm-agent"
```

Avoid adding variables unless they are used by the wrapper for VM creation or shell
entry. Tool-specific options belong near the recipe that uses them.

`DVM_ARCH=default` is a wrapper convenience, not a Lima YAML value. Before rendering
the template, resolve it from the host architecture:

```bash
if [[ "$DVM_ARCH" = default ]]; then
  case "$(uname -m)" in
    arm64|aarch64) DVM_ARCH=aarch64 ;;
    x86_64|amd64) DVM_ARCH=x86_64 ;;
  esac
fi
```

## VM Config

`~/.config/dvm/vms/app.sh` is host-side config:

```bash
DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=80GiB
DVM_CODE_DIR="~/code/app"
DVM_PORTS="3000:3000 5173:5173"
DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"

use node
use python
use agent-user
use codex
use claude
use chezmoi
```

Order matters. Recipes run in the same order as `use` calls, after `baseline`. If
`$DVM_CODE_DIR/.dvm/apply.sh` exists inside the guest, DVM runs it after recipes.

Dedicated service VMs are normal VM configs:

```bash
# ~/.config/dvm/vms/llama.sh
DVM_CPUS=8
DVM_MEMORY=16GiB
DVM_DISK=120GiB
DVM_CODE_DIR="~/code/llama"
DVM_PORTS="8080:8080"
DVM_LLAMA_DEFAULT_MODEL="small"
DVM_LLAMA_MODELS="small=https://example.invalid/model.gguf"
DVM_LLAMA_MODELS_SHA256="small=..."

use llama
```

```bash
# ~/.config/dvm/vms/cloudflared.sh
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/cloudflared"
DVM_CLOUDFLARED_TOKEN="${CLOUDFLARED_TOKEN:-}"

use cloudflared
```

## Recipe Mechanism

The recipe mechanism should remain about this small:

```bash
DVM_RECIPES=()

use() {
  local name="$1"
  local path="$DVM_CONFIG/recipes/$name.sh"
  [[ -f "$path" ]] || { echo "dvm: no recipe: $name" >&2; exit 1; }
  DVM_RECIPES+=("$name")
}
```

`dvm apply` builds the guest script from host-readable recipe files, then appends a
guest-readable project hook check:

```bash
{
  [[ "${DVM_NO_BASELINE:-0}" = 1 ]] || cat "$DVM_CONFIG/recipes/baseline.sh"
  for recipe in "${DVM_RECIPES[@]}"; do
    cat "$DVM_CONFIG/recipes/$recipe.sh"
  done
  cat <<'DVM_PROJECT_HOOK'
dvm_code_dir="${DVM_CODE_DIR%/}"
case "$dvm_code_dir" in
  "~") dvm_code_dir="$HOME" ;;
  "~/"*) dvm_code_dir="$HOME/${dvm_code_dir#~/}" ;;
esac
if [[ -f "$dvm_code_dir/.dvm/apply.sh" ]]; then
  bash "$dvm_code_dir/.dvm/apply.sh"
fi
DVM_PROJECT_HOOK
} | limactl shell "$vm" env "${env_args[@]}" bash -s
```

`env_args` must include the guest-facing values recipes need, including `DVM_NAME`,
`DVM_CODE_DIR`, and any intentionally passed recipe secrets such as
`CLOUDFLARED_TOKEN`. Do not add recipe metadata, dependency resolution, registration
functions, validation layers, or a catalog. The user controls order by ordering `use`
calls.

## Lima Template

`~/.config/dvm/lima.yaml.in` uses simple placeholder substitution. No `jq`, `yq`, or
generated schema is needed. The real template file is the source of truth; the plan
only pins the decisions:

- Fedora image template.
- `vmType: vz`.
- `DVM_ARCH` resolved to `aarch64` or `x86_64` before rendering.
- `cpus`, `memory`, and `disk` from host config.
- `mounts: []` so code and credentials live inside the VM.
- containerd disabled by default.
- user starts as `/bin/bash`; if `baseline.sh` installs zsh and changes the login
  shell, later `dvm enter` sessions can use zsh.
- `user-v2` networking for VM-to-VM names.
- `portForwards` rendered from normalized `DVM_PORTS`.
- guest port `5355` ignored to avoid Fedora LLMNR forwarding noise.
- minimal provision installs only bootstrap tools such as `sudo`, `shadow-utils`, `tar`,
  `gzip`, and `git`, then creates the configured code directory.

Port forwards are rendered from `DVM_PORTS`. The normalized form is
`host_ip:host_port:guest_port`; the two-number shorthand uses `DVM_HOST_IP`:

```bash
DVM_PORTS="3000:3000 5173:5173"
```

The default host bind is `DVM_HOST_IP`, normally `127.0.0.1`. The wrapper should
normalize ports immediately after loading config so the rest of the code handles one
shape. On existing VMs, `dvm apply` should compare configured ports against Lima's YAML
and use `limactl edit --set` to update only when the set changed.

## Baseline Recipe

`recipes/baseline.sh` installs the shell tools that every VM should have, such as Git,
Helix, lazygit, zsh, fzf, ripgrep, fd, tmux, just, curl, wget, tar, gzip, unzip, and
jq. The actual recipe file is the source of truth. Keep it practical: if a tool is
truly used in every VM, put it here; if it is project-specific, make a separate recipe.

Baseline re-runs on every `dvm apply`. Package managers are fast when packages are
already installed, but a broad baseline can still add a few seconds to each apply.

## AI Recipes

Hosted AI tools are normal recipes. They run through a separate `dvm-agent` guest user
with ACL access to the configured code directory. That keeps AI login state and tool
execution inside the VM while preventing the agent user from casually reading the main
guest user's private-key and token paths.

`recipes/agent-user.sh` should:

- install `acl`, `shadow-utils`, and `sudo` if needed
- create `dvm-agent` without adding it to sudo or wheel groups
- create the configured code directory when missing
- create a dedicated agent scratch directory, such as `/home/dvm-agent/scratch`
- make the main guest home traversal-only for `dvm-agent` where ACLs allow it
- grant `dvm-agent` `rwx` ACL access to `DVM_CODE_DIR`
- add restrictive ACL entries for common private-key and token paths such as `.ssh`,
  `.gnupg`, `.npmrc`, `.gitconfig`, `.config/gh`, and `.config/op`
- install small wrapper helpers if that keeps the per-tool recipes simple

This is a Unix-permissions guardrail, not a complete sandbox. Do not add nftables egress
rules unless real daily use shows the extra complexity is needed.

AI recipes should install one tool for `dvm-agent`, expose a wrapper usable from the
main VM shell, and leave authentication to the user inside the VM. Codex and OpenCode
use npm under `dvm-agent`, Mistral uses uv/Python tooling, and Claude uses the known
Claude RPM repository URL. The intended readable/writable areas for AI tools are
`DVM_CODE_DIR`, the agent user's own home, and the dedicated scratch directory.

Authentication happens inside the VM by running the tool there.

## Dotfiles Recipe

`recipes/chezmoi.sh` should apply public dotfiles over HTTPS by default. That avoids
host private-key copying and avoids VM-local deploy-key setup for public repositories.

Expected inputs:

```bash
DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"
```

The recipe should install `chezmoi`, initialize or update from `DVM_CHEZMOI_REPO`, and
apply inside the VM as the main guest user. SSH transport can be a later recipe only if
HTTPS becomes insufficient.

## Service Recipes

Llama and cloudflared are recipes used by dedicated VM configs.

`recipes/llama.sh` should:

- install runtime dependencies
- install or build the llama server
- create `~/models`
- support model aliases from `DVM_LLAMA_MODELS`
- verify configured model checksums when provided
- download a configured model only when missing or when refresh is requested
- install a systemd service
- expose the configured port through `DVM_PORTS`

`recipes/cloudflared.sh` should:

- install cloudflared from the vendor package repo
- create `/etc/cloudflared`
- write a systemd service
- read `DVM_CLOUDFLARED_TOKEN` or `CLOUDFLARED_TOKEN` from the guest environment when
  present
- skip token writing when the variable is absent and print a clear message

The wrapper should not know service internals. It may know the default llama and
cloudflared unit names only so `dvm logs <name>` can avoid a repeated journalctl
command for dedicated service VMs.

## Secrets

There is no `dvm secret` command.

Default behavior:

- AI login state is created inside the VM by running the AI tool inside the VM.
- Cloudflare tokens can be passed for one apply:

  ```bash
  CLOUDFLARED_TOKEN="..." dvm apply cloudflared
  ```

- If strict "nothing on host" is desired, do not store the token on the host; paste it
  only when recreating or configuring the cloudflared VM.

Optional convenience:

```bash
security add-generic-password -a dvm -s cloudflared -w "$TOKEN"
CLOUDFLARED_TOKEN="$(security find-generic-password -a dvm -s cloudflared -w)" \
  dvm apply cloudflared
```

This Keychain pattern is documentation only. It should not become a DVM abstraction
unless repeated use proves it is needed.

## Updating

The normal update flow:

```bash
$EDITOR ~/.config/dvm/recipes/baseline.sh
dvm apply --all
```

For one project:

```bash
$EDITOR ~/.config/dvm/vms/app.sh
dvm apply app
```

For project-local setup, edit inside the VM because host code is not mounted:

```bash
dvm enter app
$EDITOR ~/code/app/.dvm/apply.sh
dvm apply app
```

Recipes should be idempotent enough to rerun. Prefer package-manager installs,
`mkdir -p`, overwrite systemd unit files, and skip downloads when files already exist.

## Recreate Workflow

Recreate is intentionally not a core command:

```bash
dvm rm app --yes
dvm apply app
```

Expected recovery:

- code comes from Git remotes
- baseline tools come from `baseline.sh`
- project tools come from recipes and `.dvm/apply.sh`
- AI auth can be repeated in the VM as `dvm-agent`
- Cloudflare token can be passed again or read through the optional Keychain pattern
- llama models can be re-downloaded or cached by the recipe if still present

If a VM contains unique state that cannot be recreated from config, move that state into
Git, a managed service, or an explicit recipe. Do not add backup until repeated real use
shows this is painful.

## Line Budget

Target:

```text
bin/dvm                         500-650 lines with practical helpers
lima.yaml.in                     40-70 lines
recipes/baseline.sh              40-80 lines
recipes/*.sh                     content, not framework
vms/*.sh                         5-20 lines each
```

The wrapper target was intentionally low before the practical helpers were restored.
With dirty-delete checks, existing-VM port mutation, logs, and key helpers, a wrapper
in the 500-650 line range is acceptable. If it grows beyond that, move behavior back
into recipes or guest scripts before adding new commands. Most new lines should install
or configure real tools in recipes, not move metadata through a framework.

## Documentation

Keep documentation larger than code, but make it operational. The active docs should
cover commands, config, Lima, recipes, AI, services, dotfiles, and security standards.

Do not document future platform features as if they are planned. Put only observed pain
in a short "Maybe Later" section.

## Maybe Later

Only consider these after using DVM for a while:

- shell completion if typing VM names is genuinely annoying.
- `dvm recreate NAME` if `rm && apply` is too error-prone.
- backup if real, non-recreatable VM state appears repeatedly.
- nftables egress rules if hosted AI tools need network guardrails beyond the
  `dvm-agent` Unix-permissions model.
- recipe dependencies only if recipes are shared beyond one user and manual ordering
  becomes a real failure mode.

Each future feature should be judged against the test sentence and rejected if it
creates a new product layer.
