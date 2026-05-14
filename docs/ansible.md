# External Ansible repo contract

DVM owns VM lifecycle. The user owns VM contents. Everything that touches the
inside of the guest — packages, users, services, dotfiles, keys, secrets —
lives in a separate Ansible repository that you maintain.

DVM only needs to know enough config to:

1. start a Lima VM with `template:fedora` (or your override),
2. find Lima's generated `ansible-inventory.yaml`, and
3. invoke `ansible-playbook` against your playbook with the right tags and
   a non-secret vars file.

Set `DVM_ANSIBLE_REPO` and `DVM_ANSIBLE_PLAYBOOK` in `~/.config/dvm/config.sh`,
then point it at a repo shaped like:

```
ansible/
  ansible.cfg
  site.yml
  group_vars/
    all.yml
  roles/
    base/
    agent_user/
    chezmoi/
    keys/
    codex/
    claude/
    opencode/
    node/
    docker/
    tailscale/
    cloudflared/
    llama/
```

## Minimum viable repo

The smallest thing DVM will run against is two files plus one role.
`ansible.cfg` is optional — Ansible's defaults work fine — but a couple
of settings save time:

```ini
# ansible/ansible.cfg
[defaults]
host_key_checking = False
stdout_callback   = yaml
roles_path        = ./roles
```

```yaml
# ansible/site.yml
- name: Configure DVM guest
  hosts: all
  become: true
  roles:
    - { role: base, tags: [base] }
```

```yaml
# ansible/roles/base/tasks/main.yml
- name: Install common packages
  ansible.builtin.package:
    name: [git, tmux, helix]
    state: present
```

Point DVM at it:

```bash
# ~/.config/dvm/config.sh
DVM_ANSIBLE_REPO="$HOME/code/ansible"
DVM_ANSIBLE_PLAYBOOK="site.yml"
```

```bash
# ~/.config/dvm/vms/app.sh
DVM_ANSIBLE_TAGS=(base)
```

```bash
dvm sync app
```

## What Ansible can rely on from DVM and Lima

By the time your playbook starts, the following are already true:

- **Inventory**: Lima writes `~/.lima/dvm-<vm>/ansible-inventory.yaml` and
  DVM passes it as `-i`. You do not write inventory yourself; do not
  manage SSH config either. Lima embeds the right user, key, and host.
- **Connection user**: `dvm_user` (default `developer`) is the Lima
  primary user. Ansible connects as that user.
- **Sudo**: the primary user has passwordless sudo. `become: true` works
  out of the box; no `become_password`.
- **Python**: the Fedora templates ship Python 3, so Ansible runs
  without a bootstrap step.
- **Code directory**: `/home/<dvm_user>/code/<vm>` does **not** exist
  until your playbook creates it (your `base` role should). The host
  checkout is never mounted.
- **Network**: forwarded ports are bound on the host before Ansible
  runs; the guest sees them as ordinary listening sockets it can bind.
- **Idempotency contract**: `dvm sync` re-runs the full playbook on every
  call. Your tasks must be idempotent — prefer `package`, `file`,
  `template`, `service` over `command`/`shell` with no `creates:` or
  `changed_when:`.

## Variables DVM passes

For every `dvm sync <vm>`, DVM writes `~/.cache/dvm/<vm>.vars.yml` and
passes it with `-e @…`. Roles reference these as `{{ dvm_user }}`,
`{{ dvm_code_dir }}`, etc.

| Variable | Type | Example | Meaning |
|---|---|---|---|
| `dvm_name` | string | `app` | Short VM name (matches the per-VM config file) |
| `dvm_lima_name` | string | `dvm-app` | Lima instance name (the `dvm-` prefixed form) |
| `dvm_user` | string | `developer` | Primary guest user; the connection user |
| `dvm_code_dir` | string | `/home/developer/code/app` | Where your project should be cloned in the guest |
| `dvm_host_ip` | string | `127.0.0.1` | Bind IP on the host for forwarded ports |
| `dvm_ports` | list of `{host, guest}` | `[{host: 3000, guest: 3000}]` | Active port forwards |

These are the only DVM-managed variables. They contain no secrets.

`DVM_ANSIBLE_EXTRA_VARS` in the per-VM config is appended as additional
`-e key=value` arguments. Use it for non-secret profile flags such as
`dvm_profile=app` or `chezmoi_repo=git@github.com:me/dotfiles.git`. DVM
rejects entries whose name looks like a secret (`token`, `password`,
`secret`, or `key=…`).

## Common gotchas

- **`become_user` without `become: true`**: `become_user: "{{ dvm_user }}"`
  alone does nothing useful — pair it with `become: true` so Ansible
  goes through sudo. The pattern is "elevate to root, then drop to the
  user".
- **First-run timing**: occasionally `limactl start` returns before the
  guest is fully ready. Ansible's SSH probe handles this, but if you
  see `UNREACHABLE` once on a brand-new VM, re-run `dvm sync`.
- **Cloud-init clobber**: Lima images include `cloud-init`. Avoid
  rewriting `/etc/hostname`, `/etc/hosts`, or `/etc/cloud/` directly —
  Lima manages those.
- **Service restarts after a config change**: use a handler with
  `notify:`; don't `command: systemctl restart` unconditionally or
  `dvm sync` will restart the service every time.
- **`gather_facts: true` is slow on cold boot**. If a role does not need
  full facts, set `gather_facts: false` or `gather_subset: [min]` on
  that play.
- **Targeting one VM only**: there is no `--limit` plumbing because
  Lima's inventory has one host per instance. Tags are how you slice
  what runs.
- **Re-running a single tag**: `dvm ansible <vm> -- --tags chezmoi`
  reuses the same inventory + vars file with overridden tags.

## Tags select profiles

`DVM_ANSIBLE_TAGS` in the per-VM config becomes `--tags a,b,c`. Tag every role
in `site.yml` and pick the subset that fits each VM:

```yaml
- name: Configure DVM guest
  hosts: all
  become: true
  roles:
    - { role: base,        tags: [base] }
    - { role: agent_user,  tags: [agent-user, ai] }
    - { role: sandbox,     tags: [sandbox, ai] }
    - { role: chezmoi,     tags: [chezmoi] }
    - { role: codex,       tags: [codex, ai] }
    - { role: claude,      tags: [claude, ai] }
    - { role: opencode,    tags: [opencode, ai] }
    - { role: node,        tags: [node] }
    - { role: docker,      tags: [docker] }
    - { role: tailscale,   tags: [tailscale] }
    - { role: cloudflared, tags: [cloudflared] }
    - { role: llama,       tags: [llama] }
    - { role: keys,        tags: [keys, ai] }
```

## Code lives in the guest

DVM never mounts your host code into the VM. Each VM gets
`/home/<DVM_USER>/code/<vm>` (passed in as `dvm_code_dir`). Your Ansible
playbook is responsible for cloning the project repository into that path:

```yaml
- name: Clone project repository
  ansible.builtin.git:
    repo: "{{ project_repo }}"
    dest: "{{ dvm_code_dir }}"
    update: true
  become: true
  become_user: "{{ dvm_user }}"
```

This preserves DVM's isolation guarantee: a compromised guest or AI agent
cannot reach back into the host checkout.

## Secrets stay out of DVM

DVM does not stage secrets, does not read them from its config, and does not
pass them on command lines. Handle them inside the Ansible repo:

- **Ansible Vault** for long-lived material (signing keys, tokens with no
  expiry).
- `lookup('env', 'NAME')` for one-shot secrets you `export` before running
  `dvm sync`.
- `no_log: true` on any task that touches secret values.

```yaml
- name: Authenticate tailscale
  ansible.builtin.command:
    cmd: "tailscale up --auth-key {{ lookup('env', 'DVM_TAILSCALE_AUTHKEY') }}"
  no_log: true
```

DVM will refuse entries in `DVM_ANSIBLE_EXTRA_VARS` whose name contains
`token`, `password`, `secret`, or that look like `key=…`. That check is a
guard against accidents, not a security boundary — keep secrets out of all
DVM-visible config.

## SSH and GPG identity

Identity belongs to Ansible, not to DVM. Two patterns are documented:

- `dvm_keys_mode: generate` — the `keys` role creates VM-local ed25519
  SSH and GPG signing keys if missing, prints the public material, and
  configures git signing. Private keys never leave the VM.
- `dvm_keys_mode: vault` — the role restores encrypted private keys from
  Ansible Vault with strict file modes and `no_log: true`.

See [examples/keys.yml](ansible/examples/keys.yml) for both.

## Chezmoi for dotfiles

DVM does not know dotfile details. The Ansible `chezmoi` role installs
chezmoi and applies your dotfiles repo:

```yaml
- name: Install chezmoi
  ansible.builtin.package: { name: chezmoi, state: present }
  become: true

- name: Apply dotfiles
  ansible.builtin.command:
    cmd: "chezmoi init --apply {{ chezmoi_repo }}"
    creates: "/home/{{ dvm_user }}/.local/share/chezmoi"
  become: true
  become_user: "{{ dvm_user }}"
```

If the dotfiles repo is private, the `keys` role must run first so the guest
has an SSH key registered with your git host.

## Project-local vars (optional)

Two conventions, both optional:

- `~/.config/dvm/vms/<vm>.vars.yml` on the host — pass it explicitly via
  `DVM_ANSIBLE_EXTRA_ARGS=(-e @~/.config/dvm/vms/<vm>.vars.yml)`.
- `~/code/<vm>/.dvm/vars.yml` in the project repo — your Ansible role can
  load it with `include_vars` after cloning the project.

DVM intentionally does not inspect either file. Picking one and using it
consistently is up to your Ansible repo.

## Examples

See [examples/](ansible/examples/) for reference role sketches covering
codex, claude, chezmoi, tailscale, cloudflared, llama.cpp, and keys.
They show the intended shape but are not lint-tested against a real
distro — validate before adopting. See
[examples/README.md](ansible/examples/README.md) for the index.
