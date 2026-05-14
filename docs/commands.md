# Commands

DVM is a thin wrapper around `limactl` and `ansible-playbook`. Most commands
forward straight through. None of them mount host code or touch secrets.

```
dvm sync <vm> | --all       create/start the Lima VM and run ansible-playbook
dvm sh <vm>                 interactive limactl shell
dvm ssh <vm> -- cmd...      non-interactive shell command
dvm cp src dst              copy; one side may be vm:path
dvm log <vm> [-f] [args]    guest journalctl
dvm ls [<vm>]               list configured/running VMs
dvm stop <vm> | --all       stop running VMs
dvm rm <vm> --yes           stop and delete the Lima instance
dvm new <vm>                write stub config and open $EDITOR
dvm edit <vm>               edit per-VM config
dvm config edit | show      edit/show global config
dvm base build | rm         build or delete the optional reusable base VM
dvm ansible <vm> -- args... run ansible-playbook with extra arguments
dvm doctor                  check Lima, Ansible, repo, playbook, inventory
```

## `dvm sync`

1. Sources `~/.config/dvm/config.sh` and `~/.config/dvm/vms/<vm>.sh`.
2. Writes `~/.cache/dvm/<vm>.vars.yml` (non-secret only).
3. If the Lima instance does not exist, runs `limactl start --name dvm-<vm>
   --cpus N --memory N --disk N --port-forward …  $DVM_TEMPLATE`. When
   `DVM_USE_BASE=1`, runs `limactl clone dvm-base dvm-<vm>` instead.
4. Runs `limactl start dvm-<vm>` (no-op if already running).
5. Runs `ansible-playbook -i ~/.lima/dvm-<vm>/ansible-inventory.yaml
   $DVM_ANSIBLE_REPO/$DVM_ANSIBLE_PLAYBOOK --tags <DVM_ANSIBLE_TAGS>
   -e @<vars> [extra-vars] [extra-args]`.

A `mkdir`-based lock on `~/.cache/dvm/<vm>.lock` is held for the duration of
the sync; the lock dir is removed on exit. Concurrent calls on the same VM
fail fast with a `VM busy` message.

`DVM_DRY_RUN=1 dvm sync <vm>` prints the resolved config, the limactl argv,
the vars file contents, and the ansible-playbook argv without contacting
Lima or running Ansible.

`DVM_ANSIBLE_EXTRA_ARGS=(--check --diff) dvm sync <vm>` invokes Ansible's
own dry run.

`dvm sync --all` continues past per-VM failures and exits non-zero if any
VM failed.

## `dvm sh` / `ssh` / `cp` / `log`

Thin wrappers over `limactl`. `dvm sh` uses `exec`, so the dvm process is
replaced by `limactl shell`. `dvm ssh <vm> -- cmd` runs a non-interactive
command; the `--` is required to separate dvm flags from guest command args.

`dvm cp` rewrites `vm:path` arguments to `dvm-vm:path` and forwards to
`limactl copy`. Cross-VM copy is rejected. Paths must start with a valid
VM-name prefix to count as `vm:path`, so local paths containing `:` are not
misparsed.

`dvm log <vm> -f` follows the guest systemd journal. Extra args after the VM
name are passed straight to `journalctl`, so `dvm log app -u nginx -f` works.

## `dvm ls`

Pulls `limactl list --format '{{.Name}}\t{{.Status}}\t{{.CPUs}}\t{{.Memory}}'`,
filters to `dvm-*`, strips the prefix, and prints a four-column table.
`dvm ls <vm>` shows just that one row.

## `dvm rm`

`dvm rm <vm> --yes` stops the Lima instance (force if needed) and deletes
it. The per-VM config file in `~/.config/dvm/vms/` is left in place; remove
it by hand if you want. No backup logic — identity belongs to Ansible.

## `dvm new` / `edit` / `config`

- `dvm new <vm>` writes `~/.config/dvm/vms/<vm>.sh` from a stub and opens
  `$EDITOR`. Fails if the file already exists.
- `dvm edit <vm>` opens that file in `$EDITOR`.
- `dvm config edit` opens `~/.config/dvm/config.sh`, copying the example
  from `share/dvm/config.sh.example` if it does not exist yet.
- `dvm config show` prints the global config.

No validation framework. If you save invalid Bash, the next `dvm sync` fails
with a Bash line number; re-open the editor and fix.

## `dvm base build` / `dvm base rm`

Optional. When you create many similar VMs, building a base once and cloning
from it is much faster than running the full playbook from scratch.

- `dvm base build` starts `dvm-<DVM_BASE_NAME>` from `$DVM_TEMPLATE`, runs
  Ansible with `--tags <DVM_BASE_TAGS>`, then stops the VM.
- Set `DVM_USE_BASE=1` and subsequent `dvm sync <vm>` clones the base
  instead of starting fresh.
- `dvm base rm` deletes the base instance.

The base must contain no per-VM material: no SSH/GPG identity, no
tailscale/cloudflared auth, no per-project config.

## `dvm ansible`

Forwards extra arguments to `ansible-playbook` after the inventory, playbook,
tags, and vars file:

```
dvm ansible app -- --tags chezmoi --check
```

The base argv (inventory, playbook, vars file, tags from the VM config) is
always included. Use this for one-off runs with different tags or flags.

## `dvm doctor`

Reports whether `limactl` and `ansible-playbook` exist, whether
`$DVM_ANSIBLE_REPO/$DVM_ANSIBLE_PLAYBOOK` resolves, how many VM configs are
in `~/.config/dvm/vms/`, and whether each existing Lima instance has an
`ansible-inventory.yaml` next to it. Exit code is non-zero if anything is
missing. Diagnostic only — no auto-fixes.
