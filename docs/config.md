# Config

DVM config is Bash because the wrapper sources it on the host. Keep it boring:
variables plus `use <recipe>`.

## Global Defaults

Global config lives at:

```text
~/.config/dvm/config.sh
```

Built-in defaults apply when a variable is unset:

| Variable             | Default                          |
| -------------------- | -------------------------------- |
| `DVM_CPUS`           | `2`                              |
| `DVM_MEMORY`         | `2GiB`                           |
| `DVM_DISK`           | `10GiB`                          |
| `DVM_ARCH`           | `default` (resolves to host arch)|
| `DVM_USER`           | `${USER:-developer}`             |
| `DVM_CODE_ROOT`      | `~/code`                         |
| `DVM_CODE_DIR`       | `${DVM_CODE_ROOT}/<name>`        |
| `DVM_PORTS`          | empty                            |
| `DVM_HOST_IP`        | `127.0.0.1`                      |
| `DVM_AI_AGENT_USER`  | `dvm-agent`                      |

`./install.sh --init` copies a fully commented `share/dvm/config.sh` to
`~/.config/dvm/config.sh`. Uncomment lines there to override the built-in defaults
globally. Per-VM config in `~/.config/dvm/vms/<name>.sh` overrides global config in
turn.

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
dvm sync myapp
```

`dvm init` writes a fully commented template that shows host CPU/memory limits and
calls `use_tools` (the helper defined in global config). Uncomment what you need:

```bash
# DVM_CPUS=4          # default 2 (host max: 14)
# DVM_MEMORY=8GiB     # default 2GiB (host max: 64GiB)
# DVM_DISK=80GiB      # default 10GiB
# DVM_CODE_DIR="~/code/$DVM_NAME"
# DVM_PORTS="3000:3000 5173:5173"

use_tools
```

## Toolsets via Helpers

`share/dvm/config.sh` ships a `use_tools` function with every general-purpose recipe
listed and commented out. Uncomment the recipes you want every app VM to install.
Define more helpers (`use_data_tools`, `use_ml_tools`, …) for groups of VMs and call
them from per-VM configs. Service recipes (`llama`, `cloudflared`) are not in
`use_tools`; they belong in their dedicated VM templates.

## Variables

- `DVM_CPUS`, `DVM_MEMORY`, `DVM_DISK`: Lima VM sizing. Default `2`, `2GiB`, `10GiB`.
- `DVM_ARCH`: `default`, `aarch64`, or `x86_64`.
- `DVM_USER`: primary guest user.
- `DVM_CODE_ROOT`: default parent for VM code directories.
- `DVM_CODE_DIR`: guest code directory for this VM.
- `DVM_PORTS`: space-separated `host_port:guest_port` or
  `host_ip:host_port:guest_port` entries.
- `DVM_HOST_IP`: default bind IP for two-part ports, normally `127.0.0.1`.
- `DVM_AI_AGENT_USER`: AI tool user, normally `dvm-agent`.
- `DVM_CODEX_YOLO`: `1` by default. The `codex` recipe starts Codex with
  `--dangerously-bypass-approvals-and-sandbox` for unattended work inside the
  `dvm-agent` Bubblewrap sandbox. Set `DVM_CODEX_YOLO=0` to leave Codex approval
  prompts and its own sandbox enabled.
- `DVM_CLAUDE_BYPASS`: `1` by default. The `claude` recipe configures Claude Code
  `bypassPermissions` for unattended work inside the `dvm-agent` Bubblewrap sandbox.
  Set `DVM_CLAUDE_BYPASS=0` to leave Claude permission prompts enabled.
- `DVM_COREPACK_VERSION`: Corepack npm package version for the `node` recipe, normally
  `0.34.0`.
- `DVM_CHEZMOI_REPO`: public HTTPS dotfiles repo. Required when any VM uses the
  `chezmoi` recipe. Usually set in global config; per-VM config can override.
- `DVM_CHEZMOI_ROLE`, `DVM_CHEZMOI_NAME`, `DVM_CHEZMOI_EMAIL`: optional shared chezmoi
  `[data]` values. Usually set in global config; per-VM config can override.
- `DVM_CHEZMOI_SIGNING_KEY`, `DVM_CHEZMOI_DEPLOY_KEY`: optional chezmoi `[data]` key
  path overrides. Usually set in global config when `dvm ssh-key` is configured with
  custom key names; per-VM config can override. When unset, generated chezmoi data
  uses `~/.ssh/id_ed25519_dvm_signing.pub` and `~/.ssh/id_ed25519_dvm.pub`.
- `DVM_CHEZMOI_CONFIG_TOML`: optional full chezmoi config written to
  `~/.config/chezmoi/chezmoi.toml`; when set, it takes over the generated chezmoi data
  config rather than merging with it.
- `DVM_LLAMA_PORT`, `DVM_LLAMA_HOST`, `DVM_LLAMA_SERVICE`: llama service settings.
- `DVM_LLAMA_MODELS_DIR`, `DVM_LLAMA_DEFAULT_MODEL`, `DVM_LLAMA_MODELS`,
  `DVM_LLAMA_MODELS_SHA256`, `DVM_LLAMA_REFRESH`: llama model settings.
- `DVM_CLOUDFLARED_SERVICE`, `DVM_CLOUDFLARED_TOKEN`: cloudflared service settings.
  The bundled cloudflared recipe receives the token through a mode `0600` guest temp
  file during `apply`, so it is not passed as a `limactl shell env` argument.
- `DVM_NO_BASELINE=1`: skip the implicit `baseline` recipe. Service VMs use this to
  avoid dev-tool setup; recipes selected by that VM must install their own dependencies
  such as `git`, `curl`, `jq`, `tar`, or `unzip`.

DVM validates VM config before rendering Lima YAML. `DVM_CPUS` must be a positive
integer; `DVM_MEMORY` and `DVM_DISK` must start with a number and contain only simple
size characters; `DVM_USER`, `DVM_AI_AGENT_USER`, `DVM_LIMA_NAME`, `DVM_HOST_IP`, and
ports must use safe characters. `DVM_CODE_DIR` cannot contain newlines, quotes,
backticks, dollar signs, or backslashes because it is rendered into guest setup scripts.

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
	use bat
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

`dvm sync <name>` prints the expanded recipe list before running guest scripts. If the
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

Changing `DVM_PORTS` and running `dvm sync <name>` updates the existing Lima VM's port
forwards. Lima may restart the VM when ports change.
