# How-to

Short answers to the common questions. Each section is one task, one
snippet. Deeper context lives in [ansible.md](ansible.md),
[config.md](config.md), [commands.md](commands.md), and
[security-standards.md](security-standards.md).

## Set up your first Ansible repo

DVM expects an external repo with at minimum an `ansible.cfg`, a
`site.yml`, and one tagged role. Smallest working version:

```bash
mkdir -p ~/code/ansible/roles/base/tasks && cd ~/code/ansible
```

```ini
# ansible.cfg
[defaults]
host_key_checking = False
stdout_callback   = yaml
roles_path        = ./roles
```

```yaml
# site.yml
- name: Configure DVM guest
  hosts: all
  become: true
  roles:
    - { role: base, tags: [base] }
```

```yaml
# roles/base/tasks/main.yml
- ansible.builtin.package:
    name: [git, tmux, helix]
    state: present
```

Point DVM at it and sync:

```bash
# in ~/.config/dvm/config.sh
DVM_ANSIBLE_REPO="$HOME/code/ansible"
DVM_ANSIBLE_PLAYBOOK="site.yml"
```

```bash
dvm new app             # set DVM_ANSIBLE_TAGS=(base) in the editor
dvm sync app
```

What DVM hands the playbook automatically: a Lima-managed inventory,
the `dvm_*` vars (`dvm_user`, `dvm_code_dir`, …), passwordless sudo for
the primary user, and Python on the guest. See
[ansible.md](ansible.md#what-ansible-can-rely-on-from-dvm-and-lima) for
the full contract.

## Create and configure a new VM

```bash
dvm new app             # writes ~/.config/dvm/vms/app.sh, opens $EDITOR
dvm sync app            # starts Lima + runs ansible-playbook
dvm sh app              # shell into it
```

Edit the stub to pick tags and resources:

```bash
DVM_CPUS=4 DVM_MEMORY=8 DVM_DISK=60
DVM_PORTS=(3000:3000)
DVM_ANSIBLE_TAGS=(base agent-user node chezmoi)
```

## Add or change packages

Packages live in your Ansible repo, not in DVM config. Edit your `base`
role (or any tagged role):

```yaml
# roles/base/tasks/main.yml
- ansible.builtin.package:
    name: [git, tmux, helix, ripgrep, fd-find]
    state: present
  become: true
```

```bash
dvm sync app            # re-run, picks up the new packages
```

No recreate needed for package additions. See
[ansible/examples/base.yml](ansible/examples/base.yml).

## Different packages per VM

Make one role per package set; pick tags per VM.

```yaml
# site.yml in your Ansible repo
- hosts: all
  become: true
  roles:
    - { role: base,   tags: [base] }
    - { role: node,   tags: [node] }
    - { role: python, tags: [python] }
    - { role: rust,   tags: [rust] }
```

```bash
# ~/.config/dvm/vms/web.sh
DVM_ANSIBLE_TAGS=(base node)

# ~/.config/dvm/vms/ml.sh
DVM_ANSIBLE_TAGS=(base python)
```

For one-off extras without a whole role, pass a list via extra-vars and
consume it in `base`:

```bash
DVM_ANSIBLE_EXTRA_VARS=("extra_packages=['nodejs','npm']")
```

```yaml
- ansible.builtin.package:
    name: "{{ extra_packages | default([]) }}"
    state: present
```

## Update ports, CPU, memory, or template

Lima does not reload these on a running instance. Edit and recreate:

```bash
dvm edit app            # change DVM_PORTS / DVM_CPUS / …
dvm rm app --yes && dvm sync app
```

With `DVM_USE_BASE=1` the recreate is fast — it clones the base VM
instead of starting from a fresh template. For pure Ansible changes
(new packages, new role behavior), plain `dvm sync app` is enough.

## Generate SSH/GPG signing keys (in Ansible)

Use the `keys` role with `dvm_keys_mode=generate`. The role creates
`id_ed25519_dvm` (access) and `id_ed25519_dvm_signing` inside the VM and
wires `git config --global` for SSH commit signing. Private keys never
leave the VM; public keys are printed for you to paste into your git
host.

```bash
# ~/.config/dvm/vms/app.sh
DVM_ANSIBLE_TAGS=(base agent-user keys chezmoi)
DVM_ANSIBLE_EXTRA_VARS=("dvm_keys_mode=generate")
```

Full role: [ansible/examples/keys.yml](ansible/examples/keys.yml).

## Recreate a VM without losing identity

DVM does not back up keys. Pick one of:

**1. Vault (same identity survives recreate).** Switch the `keys` role to
`dvm_keys_mode=vault` and store the encrypted private key material in
`group_vars/all.yml` via `ansible-vault encrypt_string`. Every
`dvm sync` restores the same key into a fresh VM.

```bash
DVM_ANSIBLE_EXTRA_VARS=("dvm_keys_mode=vault")
```

```bash
dvm rm app --yes && dvm sync app     # same SSH/GPG identity comes back
```

**2. Generate + re-register.** Keep `dvm_keys_mode=generate` and accept
that recreate = new key + one paste into GitHub. Cheap for short-lived
per-project VMs.

There is no host-side key stash. See
[ansible/examples/keys.yml](ansible/examples/keys.yml) for both modes.

## Stand up a service VM (llama / tailscale / cloudflared)

One per-VM config per service. The role lives in your Ansible repo;
secrets come from your shell environment, not DVM config.

```bash
# ~/.config/dvm/vms/llama.sh
DVM_CPUS=4 DVM_MEMORY=16 DVM_DISK=80
DVM_PORTS=(8080:8080)
DVM_ANSIBLE_TAGS=(base llama)
DVM_ANSIBLE_EXTRA_VARS=(
  "llama_model_url=https://…/model.gguf"
  "llama_model_sha256=…"
)
```

```bash
# ~/.config/dvm/vms/tail.sh
DVM_ANSIBLE_TAGS=(base tailscale)
```

```bash
DVM_TAILSCALE_AUTHKEY="tskey-…" dvm sync tail
DVM_CLOUDFLARED_TOKEN="…"        dvm sync cloud
```

The role reads `lookup('env', 'DVM_TAILSCALE_AUTHKEY')` with
`no_log: true`. DVM never sees the token. Example roles:
[llama.yml](ansible/examples/llama.yml),
[tailscale.yml](ansible/examples/tailscale.yml),
[cloudflared.yml](ansible/examples/cloudflared.yml).

## Pass a secret to Ansible

DVM rejects secret-looking entries in `DVM_ANSIBLE_EXTRA_VARS`. Use one
of these inside the playbook instead:

- **Ansible Vault** for long-lived material:
  ```bash
  ansible-vault encrypt_string 'tskey-…' --name tailscale_authkey
  ```
- **`lookup('env', 'NAME')`** for one-shot secrets — export them before
  `dvm sync`:
  ```bash
  export DVM_TAILSCALE_AUTHKEY="tskey-…"
  dvm sync tail
  ```
- Mark any task that touches a secret with `no_log: true`.

Avoid shell history leaks: lead the command with a space (and set
`HISTCONTROL=ignorespace`), or pull from Keychain / 1Password.

## Speed up VM creation with a base VM

```bash
# in ~/.config/dvm/config.sh
DVM_USE_BASE=1
DVM_BASE_TAGS=(base)
```

```bash
dvm base build          # builds dvm-dvm-base, runs --tags base, stops it
dvm sync app            # clones from base instead of fresh template
```

The base must hold no per-VM material: no identity, no service auth, no
project config. Just packages and shared baseline.

## Dry-run and debug

Show the limactl argv, vars file, and ansible-playbook argv without
touching Lima:

```bash
DVM_DRY_RUN=1 dvm sync app
```

Run Ansible's own dry run:

```bash
DVM_ANSIBLE_EXTRA_ARGS=(--check --diff) dvm sync app
```

One-off ansible-playbook with extra args (e.g. limit to one tag):

```bash
dvm ansible app -- --tags chezmoi --check --diff
```

Diagnose setup:

```bash
dvm doctor              # checks limactl, ansible-playbook, repo, inventory
```
