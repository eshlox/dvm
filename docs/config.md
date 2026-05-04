# Config

DVM config is Bash because the wrapper sources it on the host. Keep it boring:
variables plus `use <recipe>`.

## Global Defaults

Global config lives at:

```text
~/.config/dvm/config.sh
```

Defaults copied by `./install.sh --init`:

```bash
DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=80GiB
DVM_ARCH=default
DVM_USER="${USER:-developer}"
DVM_CODE_ROOT="~/code"
DVM_HOST_IP="127.0.0.1"
DVM_AI_AGENT_USER="dvm-agent"
# Optional for VMs that use the chezmoi recipe:
# DVM_CHEZMOI_ROLE="vm"
# DVM_CHEZMOI_NAME="Your Name"
# DVM_CHEZMOI_EMAIL="you@example.com"
```

`DVM_ARCH=default` resolves to `aarch64` on Apple Silicon and `x86_64` on Intel before
rendering the Lima YAML.

## VM Config

Active VMs live in:

```text
~/.config/dvm/vms/<name>.sh
```

Names must start with a lowercase letter and contain only lowercase letters, numbers,
and hyphens. Do not include the internal `dvm-` prefix in VM config filenames or DVM
commands.

Example VM configs live in the repo:

```text
share/dvm/vms
```

Run `dvm init <name> [template]` to copy one into `~/.config/dvm/vms` and open it in
your editor. The template defaults to `app`.

Create a new app VM:

```bash
dvm init myapp
dvm apply myapp
```

Example:

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

## Variables

- `DVM_CPUS`, `DVM_MEMORY`, `DVM_DISK`: Lima VM sizing.
- `DVM_ARCH`: `default`, `aarch64`, or `x86_64`.
- `DVM_USER`: primary guest user.
- `DVM_CODE_ROOT`: default parent for VM code directories.
- `DVM_CODE_DIR`: guest code directory for this VM.
- `DVM_PORTS`: space-separated `host_port:guest_port` or
  `host_ip:host_port:guest_port` entries.
- `DVM_HOST_IP`: default bind IP for two-part ports, normally `127.0.0.1`.
- `DVM_AI_AGENT_USER`: AI tool user, normally `dvm-agent`.
- `DVM_COREPACK_VERSION`: Corepack npm package version for the `node` recipe, normally
  `0.34.0`.
- `DVM_CHEZMOI_REPO`: public HTTPS dotfiles repo.
- `DVM_CHEZMOI_ROLE`, `DVM_CHEZMOI_NAME`, `DVM_CHEZMOI_EMAIL`: optional shared chezmoi
  `[data]` values.
- `DVM_CHEZMOI_SIGNING_KEY`, `DVM_CHEZMOI_DEPLOY_KEY`: optional per-VM chezmoi
  `[data]` key path overrides. When unset, generated chezmoi data uses
  `~/.ssh/id_ed25519_dvm_signing.pub` and `~/.ssh/id_ed25519_dvm.pub`.
- `DVM_CHEZMOI_CONFIG_TOML`: optional full chezmoi config written to
  `~/.config/chezmoi/chezmoi.toml`; when set, it takes over the generated chezmoi data
  config rather than merging with it.
- `DVM_LLAMA_PORT`, `DVM_LLAMA_HOST`, `DVM_LLAMA_SERVICE`: llama service settings.
- `DVM_LLAMA_MODELS_DIR`, `DVM_LLAMA_DEFAULT_MODEL`, `DVM_LLAMA_MODELS`,
  `DVM_LLAMA_MODELS_SHA256`, `DVM_LLAMA_REFRESH`: llama model settings.
- `DVM_CLOUDFLARED_SERVICE`, `DVM_CLOUDFLARED_TOKEN`: cloudflared service settings.
- `DVM_NO_BASELINE=1`: skip the implicit `baseline` recipe.

You can define host-side helper functions in `~/.config/dvm/config.sh` if you want a
personal bundle of recipes:

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

Then call the helper from each app VM that should get those tools:

```bash
use_app_tools
```

`dvm apply <name>` prints the expanded recipe list before running guest scripts. If the
summary does not include the helper's recipes, check that you are running the current
wrapper with `type dvm` and that `DVM_CONFIG` points at the config directory you edited.

Bundled recipes are not copied into `~/.config/dvm`. Put only your custom recipe
overrides in `~/.config/dvm/recipes`.

`~` in DVM variables always means the guest user's home. The wrapper does not expand it
on the host; guest-side scripts expand it to paths such as `/home/eshlox/code/app`.

## Ports

Use localhost by default:

```bash
DVM_PORTS="3000:3000"
```

Use an explicit bind address only when needed:

```bash
DVM_PORTS="127.0.0.1:3000:3000"
```

Avoid `0.0.0.0` unless you want the service reachable from your LAN.

Changing `DVM_PORTS` and running `dvm apply <name>` updates the existing Lima VM's port
forwards. Lima may restart the VM when ports change.
