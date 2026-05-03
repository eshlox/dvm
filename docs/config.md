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
```

`DVM_ARCH=default` resolves to `aarch64` on Apple Silicon and `x86_64` on Intel before
rendering the Lima YAML.

## VM Config

Active VMs live in:

```text
~/.config/dvm/vms/<name>.sh
```

Names must start with a lowercase letter and contain only lowercase letters, numbers,
and hyphens.

Example VM configs live in the repo:

```text
share/dvm/vms
```

Copy one into `~/.config/dvm/vms` when you want it to become active.

Create a new app VM:

```bash
mkdir -p ~/.config/dvm/vms
cp share/dvm/vms/app.sh ~/.config/dvm/vms/myapp.sh
$EDITOR ~/.config/dvm/vms/myapp.sh
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
- `DVM_CHEZMOI_REPO`: public HTTPS dotfiles repo.
- `DVM_LLAMA_PORT`, `DVM_LLAMA_HOST`, `DVM_LLAMA_SERVICE`: llama service settings.
- `DVM_LLAMA_MODELS_DIR`, `DVM_LLAMA_DEFAULT_MODEL`, `DVM_LLAMA_MODELS`,
  `DVM_LLAMA_MODELS_SHA256`, `DVM_LLAMA_REFRESH`: llama model settings.
- `DVM_CLOUDFLARED_SERVICE`, `DVM_CLOUDFLARED_TOKEN`: cloudflared service settings.
- `DVM_NO_BASELINE=1`: skip the implicit `baseline` recipe.

You can define host-side helper functions in `~/.config/dvm/config.sh` if you want a
personal bundle of recipes.

`~` in DVM variables always means the guest user's home. The wrapper does not expand it
on the host.

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
