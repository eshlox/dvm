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

Bundled recipes live in `share/dvm/recipes`. Local recipes in
`~/.config/dvm/recipes` override bundled recipes with the same name. Keep that directory
for your own custom recipes or intentional overrides; copied bundled recipes will go
stale and block future recipe updates.

Rules:

- Recipes should be idempotent enough to rerun.
- Prefer package-manager installs, `mkdir -p`, and overwriting systemd units.
- Do not read host paths.
- Use `DVM_CODE_DIR` for project code.
- Keep tool-specific config close to the recipe that uses it.
- Do not add recipe metadata, dependency graphs, registries, or versioning.

## Built-In Recipes

`baseline` installs required setup basics only: Git, curl, wget, tar, gzip, unzip, and
jq. Editors, shells, terminal tools, Git UIs, and language runtimes belong in user
recipes or project-specific VM configs.

Interactive tools are split into one recipe per tool: `zsh`, `git`, `helix`,
`lazygit`, `starship`, `fzf`, `git-delta`, `just`, `tmux`, and `yazi`. `zsh` installs
zsh and sets it as the guest user's default login shell with `usermod --shell`. The
DNF-backed recipes install from Fedora.
The upstream-backed recipes try Fedora first and otherwise use pinned official release
assets with sha256 verification.

`_helpers.sh` is an internal helper that DVM prepends before guest recipes. It provides
the shared verified-download functions used by pinned upstream recipes; do not select
it with `use`.

`agent-user` creates `dvm-agent` as a system account with a home directory, installs
Bubblewrap, grants ACL access to `DVM_CODE_DIR`, creates an agent scratch directory, and
installs the mandatory AI sandbox helper. AI tool wrappers run inside Bubblewrap with
project code mounted at `/workspace`, the agent home mounted read/write, and the main
user home left out of the sandbox.

`codex`, `claude`, `opencode`, and `mistral` install hosted AI tools for `dvm-agent`
and expose wrappers in `/usr/local/bin`. Put `use agent-user` before these recipes.

`node` installs Node.js/npm, installs the standalone Corepack npm package when Fedora's
Node package does not provide `corepack`, and enables Corepack shims for pnpm/yarn.
`python` installs Python, pip, and uv.

After applying `use node`, pin pnpm in each project rather than installing a global
pnpm:

```bash
corepack use pnpm@latest
pnpm install
```

Commit the resulting `packageManager` field in `package.json` so every VM uses the same
package manager version.

## Adding Packages

Use `baseline` only for required setup basics that should be present in every VM,
including service VMs. For app VMs, select the tools you want explicitly:

```bash
use zsh
use git
use helix
use lazygit
use starship
use fzf
use git-delta
use just
use tmux
use yazi
```

If you want a personal bundle, define it in `~/.config/dvm/config.sh`:

```bash
use_app_tools() {
	use zsh
	use git
	use helix
	use lazygit
	use starship
	use fzf
	use git-delta
	use just
	use tmux
	use yazi
}
```

Then call it from VM configs that should get that bundle:

```bash
use_app_tools
```

For a DNF package in one VM, prefer a small recipe:

```bash
$EDITOR ~/.config/dvm/recipes/my-package.sh
```

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y my-package
```

Then select it from one VM config:

```bash
use my-package
```

For a package or tool that does not exist in DNF, use the same split:

- every app VM: create a named recipe in `~/.config/dvm/recipes/<name>.sh` and add
  `use <name>` to those VM configs, or add it to your own helper function
- one VM: put the install commands in `~/.config/dvm/recipes/<name>.sh` and add
  `use <name>` to that VM config

For non-DNF tools, prefer the pattern used by `lazygit`, `starship`, and `yazi`:
download from an official HTTPS release URL, pin a version, verify sha256 before
installing, and avoid `curl | sh` installers. To update, bump the version, URL, and
sha256 in the recipe, then run `dvm apply <name>` or `dvm apply --all`.

Project-only setup that belongs in the project repository can also live in:

```text
$DVM_CODE_DIR/.dvm/apply.sh
```

That hook runs after baseline and selected recipes, inside the guest.

`chezmoi` applies public dotfiles over HTTPS:

```bash
DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"
use chezmoi
```

Shared chezmoi template data such as `DVM_CHEZMOI_ROLE`, `DVM_CHEZMOI_NAME`, and
`DVM_CHEZMOI_EMAIL` usually belongs in `~/.config/dvm/config.sh`; generated key data
uses the default paths from `dvm ssh-key <name>` unless overridden globally or per VM.

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
