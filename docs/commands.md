# Commands

Running `dvm` with no arguments is the same as `dvm ls`.

```text
dvm sync <vm> | --all       create/start VM and run packages + recipes
dvm sh <vm>                 interactive limactl shell
dvm ssh <vm> -- cmd...      non-interactive limactl shell command
dvm cp src dst              copy; one side may be vm:path
dvm log <vm> [-f] [args]    guest journalctl
dvm ls [<vm>]               list DVM Lima instances
dvm stop <vm> | --all       stop running VMs
dvm rm <vm> --yes           delete a Lima instance
dvm new <vm>                write stub config and open editor
dvm edit <vm>               edit per-VM config
dvm config edit | show      edit/show global config
dvm base build | rm         optional reusable base VM
dvm recipes                 list built-in and user recipes
dvm doctor                  check Lima and DVM paths
```

## `dvm sync`

`dvm sync <vm>`:

1. loads `~/.config/dvm/config.sh`
2. loads `~/.config/dvm/vms/<vm>.sh`
3. starts `dvm-<vm>` from `DVM_TEMPLATE`, or clones `dvm-<DVM_BASE_NAME>`
   when `DVM_USE_BASE=1`
4. stages any `DVM_SECRETS`
5. runs the guest script: packages, recipes, optional `DVM_GIT_REPO` clone,
   then `$DVM_CODE_DIR/.dvm/sync.sh` if present
6. removes staged secrets

`DVM_DRY_RUN=1 dvm sync <vm>` prints the Lima argv and generated guest script
without contacting Lima.

`dvm sync --all` syncs every `~/.config/dvm/vms/*.sh` config in filename
order and exits non-zero if any VM fails.

## Shell And Copy

`dvm sh <vm>` opens an interactive Lima shell.

`dvm ssh <vm> -- cmd...` runs a non-interactive command through
`limactl shell`. The name is kept for muscle memory; it is not raw `ssh`.

`dvm cp ./file app:/tmp/file` and `dvm cp app:/tmp/file ./file` copy between
host and guest. Cross-VM copy is not supported.

## Logs And Status

`dvm ls` lists DVM-created Lima instances by reading `limactl list`.

`dvm log <vm> [-f] [journalctl args...]` runs guest `journalctl`.

## Stop And Remove

`dvm stop <vm>` stops the Lima instance and exits successfully when the
instance is already missing. `dvm stop --all` stops every `dvm-*` instance and
continues after per-VM failures.

`dvm rm <vm> --yes` force-stops and deletes the Lima instance. It does not
need the VM config file to still exist.

## Config Editing

`dvm new <vm>` writes a starter config and opens `$VISUAL` or `$EDITOR`.

`dvm edit <vm>` opens one per-VM config.

`dvm config edit` creates the global config from `share/dvm/config.sh.example`
if needed and opens it. `dvm config show` prints it.

## Base VM

`dvm base build` starts `dvm-<DVM_BASE_NAME>`, runs `DVM_BASE_PACKAGES` and
`DVM_BASE_RECIPES`, then stops it. With `DVM_USE_BASE=1`, new VMs clone that
base with `limactl clone`.

Use this only for slow, stable setup. VM-specific recipes and secrets should
stay in the per-VM sync.

`DVM_DRY_RUN=1 dvm base build` prints the Lima argv and generated base guest
script without contacting Lima.

## Doctor

`dvm doctor` checks Lima availability and version, `$VISUAL`/`$EDITOR`, Git,
the built-in recipe directory, and VM config count. Missing Git is reported as
a warning because only `DVM_GIT_REPO` and some recipes need it.
