# Commands

One-line summary per command. Hot path is `sync` / `sh` / `ssh`.

```text
dvm                       alias for `dvm ls`
dvm sync <vm>             create/start the Lima instance and run recipes
dvm sync --all            sync every config in ~/.config/dvm/vms/ alphabetically
dvm sh <vm>               exec `limactl shell dvm-<vm>` (interactive shell)
dvm ssh <vm> -- cmd...    run a command in the VM (non-interactive)
dvm cp src dst            copy; one side may be vm:path
dvm log <vm> [-f] [args]  guest journalctl
dvm ls [<vm>]             list configured + running VMs (optional name filter)
dvm rm <vm> --yes         stop and delete the Lima instance
dvm stop <vm>             stop one running VM
dvm stop --all            stop every running dvm-* instance
dvm ssh-key <vm>          create/show guest SSH keys (access + signing)
dvm gpg-key <vm>          create/show guest GPG signing key
dvm new <vm>              write stub config, open $EDITOR
dvm edit <vm>             open per-VM config in $EDITOR
dvm config edit           open ~/.config/dvm/config.sh in $EDITOR
dvm config show           print ~/.config/dvm/config.sh
dvm recipes               list available recipes (builtin + user)
```

## sync

`dvm sync <vm>` is the workhorse:

1. Source `~/.config/dvm/config.sh` then `~/.config/dvm/vms/<vm>.sh`.
2. Render `~/.cache/dvm/<vm>.yaml` from `share/dvm/lima.yaml.in`.
3. Run `limactl create --name dvm-<vm>` if missing, then `limactl start`.
4. For each `DVM_SECRETS` entry, pipe `${!name}` to `limactl shell <vm> sudo
   install -m 600 -o $DVM_USER /dev/stdin /tmp/dvm-secret-<name>`.
5. Stream the helper prelude + `dvm_pkg "${DVM_PACKAGES[@]}"` + each
   selected recipe + the project hook (if `$DVM_CODE_DIR/.dvm/sync.sh`
   exists) into `limactl shell dvm-<vm> sudo -u $DVM_USER bash -s`.

An exclusive `flock` on `~/.cache/dvm/<vm>.lock` is held for the whole
sync. Concurrent calls on the same VM fail with `VM busy`.

`DVM_DRY_RUN=1 dvm sync <vm>` prints the rendered guest script to stdout
and exits before contacting Lima.

`dvm sync --all` continues past per-VM failures and exits non-zero if any
VM failed.

## sh / ssh / cp / log

Thin wrappers over `limactl`. `dvm sh` uses `exec`, so the dvm process is
replaced by `limactl shell`. `dvm ssh <vm> -- cmd` runs a non-interactive
command; the `--` is required to separate dvm flags from guest command
args.

`dvm cp` rewrites `vm:path` arguments to `dvm-vm:path` and forwards to
`limactl copy`. Cross-VM copy is rejected.

`dvm log <vm> -f` follows the guest systemd journal. Extra args after the
VM name are passed straight to `journalctl`, so `dvm log app -u nginx -f`
works.

## ls

Pulls `limactl list --format '{{.Name}}\t{{.Status}}\t{{.CPUs}}\t{{.Memory}}'`,
filters to `dvm-*`, strips the prefix, and prints a four-column table.
`dvm ls <vm>` shows just that one row. There is no `dvm status`; this
replaces it.

## rm

`dvm rm <vm> --yes` stops the Lima instance (force if needed) and
deletes it. The per-VM config file in `~/.config/dvm/vms/` is left alone;
delete it by hand if you want. There is no dirty-git check — `--yes` is
the contract.

## stop

`dvm stop <vm>` stops one running VM. `dvm stop --all` iterates over
`limactl list -q`, filters to `dvm-*`, and stops each. There is no
`stop --inactive` activity probe.

## ssh-key / gpg-key

Both generate guest-local keys the first time and print the public key.
`ssh-key` creates `id_ed25519_dvm` (access) and `id_ed25519_dvm_signing`
(SSH commit signing), and configures `git config --global` to sign with
the signing key. `gpg-key` creates an Ed25519 GPG signing key labelled
`<vm> dvm <dvm-<vm>@local>` and prints the armored public key.

DVM never imports a host private key into a guest.

## new / edit / config

- `dvm new <vm>` writes `~/.config/dvm/vms/<vm>.sh` from a heredoc
  template, then opens `$EDITOR`. Fails if the file already exists.
- `dvm edit <vm>` opens that file in `$EDITOR`.
- `dvm config edit` opens `~/.config/dvm/config.sh`, copying the
  example from `share/dvm/config.sh.example` if it does not exist yet.
- `dvm config show` prints the global config.

No validation framework. If you save invalid Bash, the next `dvm sync`
fails with a Bash line number; re-open the editor and fix.
