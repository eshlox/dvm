# DVM

Keep your friends close, your supply chain in a VM.

DVM is a tiny Bash wrapper around three existing tools:

- **Lima** owns the VM (create, start, shell, copy, log, delete).
- **Ansible** owns the guest configuration, from a separate user-owned repo.
- **chezmoi** owns your dotfiles, called by Ansible from a separate dotfiles
  repo.

DVM is the memory layer that turns "create my usual VM and configure it" into
one command. It does not ship roles, it does not manage dotfiles, it does not
handle secrets. It writes a non-secret vars file, picks the right Lima
template, and invokes `ansible-playbook` against Lima's generated inventory.

## Install

Requirements:

- Lima 2.0+ (`brew install lima` on macOS, `dnf install lima` on Fedora)
- `ansible-playbook` (`brew install ansible`, `dnf install ansible`, or pipx)
- `bash`, `git`, an `$EDITOR`
- a Unix host (macOS aarch64 or Linux aarch64/x86_64)

```bash
./install.sh
```

Writes one symlink: `~/.local/bin/dvm -> $REPO/bin/dvm`. `git pull` in this
repo is the update. Override the destination with
`PREFIX=/somewhere/else ./install.sh`.

## Quick start

You also need an Ansible repo. The minimum is `site.yml` plus one tagged
role. See [docs/ansible.md](docs/ansible.md) for the full contract and
[docs/ansible/examples/](docs/ansible/examples) for working roles.
For task recipes ("add packages", "recreate without losing keys",
"per-VM toolchains"), jump to [docs/howto.md](docs/howto.md).

```bash
# 1. point DVM at your Ansible repo
dvm config edit          # opens ~/.config/dvm/config.sh
# set DVM_ANSIBLE_REPO=$HOME/code/ansible

# 2. create a VM config
dvm new app              # writes ~/.config/dvm/vms/app.sh, opens $EDITOR

# 3. create + provision
dvm sync app             # limactl start template:fedora + ansible-playbook

# 4. live in it
dvm sh app               # interactive shell
dvm                      # alias for `dvm ls`
```

## Commands

```
dvm sync <vm> | --all       create/start the Lima VM and run ansible-playbook
dvm sh <vm>                 interactive limactl shell
dvm ssh <vm> -- cmd...      non-interactive shell command
dvm cp src dst              copy; one side may be vm:path
dvm log <vm> [-f]           guest journalctl
dvm ls [<vm>]               list configured/running VMs
dvm stop <vm> | --all       stop running VMs
dvm rm <vm> --yes           stop and delete the Lima instance
dvm new <vm>                write stub config, open $EDITOR
dvm edit <vm>               edit per-VM config
dvm config edit | show      edit/show global config
dvm base build | rm         build or delete the optional reusable base VM
dvm ansible <vm> -- args... run ansible-playbook with extra arguments
dvm doctor                  check Lima, Ansible, repo, playbook, inventory
```

`DVM_DRY_RUN=1 dvm sync <vm>` prints the limactl argv, the vars file, and
the ansible-playbook argv without touching Lima.

## Config

Global, sourced first (optional):

```bash
# ~/.config/dvm/config.sh
DVM_TEMPLATE="template:fedora"
DVM_CPUS=2
DVM_MEMORY=4
DVM_DISK=30
DVM_HOST_IP=127.0.0.1
DVM_USER=developer

DVM_ANSIBLE_REPO="$HOME/code/ansible"
DVM_ANSIBLE_PLAYBOOK="site.yml"
```

Per VM, sourced after global:

```bash
# ~/.config/dvm/vms/app.sh
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)

DVM_ANSIBLE_TAGS=(base agent-user codex node chezmoi)
DVM_ANSIBLE_EXTRA_VARS=(
  "dvm_profile=app"
  "chezmoi_repo=git@github.com:me/dotfiles.git"
)
```

Memory and disk are GiB integers (Lima's flags accept plain numbers).
DVM rejects extra-vars entries whose name contains `token`, `password`,
`secret`, or that look like `key=…`. Secrets belong in Ansible Vault or
env lookups inside the playbook, not in DVM config.

See [docs/config.md](docs/config.md) for the full table.

## What DVM hands to Ansible

For every `dvm sync <vm>`, DVM writes `~/.cache/dvm/<vm>.vars.yml` and
passes it as `-e @…`:

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

These are the only variables DVM contributes. Your roles consume them as
`{{ dvm_user }}`, `{{ dvm_code_dir }}`, etc.

DVM never mounts host code into the guest. Code lives at `dvm_code_dir`
and is cloned by the Ansible playbook (typically via `ansible.builtin.git`).
See [docs/security-standards.md](docs/security-standards.md) for the
isolation model.

## Layout

```
bin/dvm                       single-file bash program
install.sh                    symlink installer
share/dvm/config.sh.example   starter global config
docs/                         contract and example Ansible roles
tests/smoke.sh                end-to-end test with fake limactl + ansible-playbook
```

## Tests

```bash
bash tests/smoke.sh
```

Asserts the limactl argv (template, flags, port forwards), the generated
vars file, and the ansible-playbook argv (inventory, playbook, tags,
vars file) all look right. No real VM is touched.

## License

MIT. See `LICENSE`.
