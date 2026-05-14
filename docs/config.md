# Config

DVM config is plain Bash sourced on the host. There are two files:

- `~/.config/dvm/config.sh` — global defaults (optional)
- `~/.config/dvm/vms/<vm>.sh` — one file per VM

Global is sourced first, then the per-VM file. A typo raises a Bash error
on the next `dvm sync`; re-open `$EDITOR` and fix.

## Global (`~/.config/dvm/config.sh`)

| Variable | Default | Meaning |
|---|---|---|
| `DVM_TEMPLATE` | `"template:fedora"` | Lima template name; pin a versioned template if reproducibility matters |
| `DVM_CPUS` | `2` | Default vCPUs |
| `DVM_MEMORY` | `4` | Default memory in GiB (integer) |
| `DVM_DISK` | `30` | Default disk in GiB (integer) |
| `DVM_HOST_IP` | `127.0.0.1` | Bind IP for forwarded ports |
| `DVM_USER` | `developer` | Primary guest user |
| `DVM_ANSIBLE_REPO` | _(required)_ | Absolute path to the external Ansible repo |
| `DVM_ANSIBLE_PLAYBOOK` | `"site.yml"` | Relative path of the playbook inside the repo |
| `DVM_ANSIBLE_EXTRA_ARGS` | `()` | Extra args appended to every `ansible-playbook` call |
| `DVM_USE_BASE` | `0` | Set to `1` to clone from `dvm-<DVM_BASE_NAME>` instead of starting a fresh template |
| `DVM_BASE_NAME` | `"dvm-base"` | Name of the optional base VM |
| `DVM_BASE_TAGS` | `(base)` | Ansible tags applied when running `dvm base build` |

## Per VM (`~/.config/dvm/vms/<vm>.sh`)

| Variable | Default | Meaning |
|---|---|---|
| `DVM_CPUS` / `DVM_MEMORY` / `DVM_DISK` | (global) | Per-VM overrides |
| `DVM_PORTS` | `()` | `host:guest` forwards; bind IP comes from global `DVM_HOST_IP` |
| `DVM_ANSIBLE_TAGS` | `()` | Tags selecting which roles in `site.yml` apply to this VM |
| `DVM_ANSIBLE_EXTRA_VARS` | `()` | Non-secret `key=value` strings passed as `-e key=value` to `ansible-playbook` |

VM names match `^[a-z][a-z0-9-]*$`. The Lima instance is `dvm-<name>`; the
guest code dir is hardcoded to `/home/$DVM_USER/code/<name>`.

## What ends up in the vars file

`dvm sync` writes `~/.cache/dvm/<vm>.vars.yml` and passes it to Ansible:

```yaml
dvm_name: app
dvm_lima_name: dvm-app
dvm_user: developer
dvm_code_dir: /home/developer/code/app
dvm_host_ip: 127.0.0.1
dvm_ports:
  - host: 3000
    guest: 3000
```

These are the only DVM-managed variables. They contain no secrets. See
[ansible.md](ansible.md) for how to consume them in roles.

## Examples

Minimal app VM:

```bash
# ~/.config/dvm/vms/app.sh
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
DVM_ANSIBLE_TAGS=(base agent-user node chezmoi)
```

App VM with non-secret profile vars:

```bash
DVM_CPUS=4
DVM_MEMORY=8
DVM_ANSIBLE_TAGS=(base agent-user codex node chezmoi)
DVM_ANSIBLE_EXTRA_VARS=(
  "dvm_profile=app"
  "chezmoi_repo=git@github.com:me/dotfiles.git"
)
```

Service VM (tailscale auth lives in the env, not the config):

```bash
DVM_CPUS=2
DVM_MEMORY=2
DVM_ANSIBLE_TAGS=(base tailscale)
```

```bash
DVM_TAILSCALE_AUTHKEY="tskey-..." dvm sync tailscale
```

The Ansible role reads `lookup('env', 'DVM_TAILSCALE_AUTHKEY')` with
`no_log: true`. DVM never sees the token.

## Secrets

DVM rejects `DVM_ANSIBLE_EXTRA_VARS` entries whose name contains `token`,
`password`, `secret`, or matches `key=…`. This is a guard against accidents.
The right home for secrets is Ansible Vault or env lookups inside the
playbook — see [ansible.md](ansible.md).
