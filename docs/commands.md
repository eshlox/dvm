# Commands

Running `dvm` with no args runs `dvm ls`.

```text
dvm sync <vm> | --all
dvm sh <vm>
dvm ssh <vm> -- cmd...
dvm cp src dst
dvm ls [--only-config] [<vm>]
dvm stop <vm> | --all [--only-config]
dvm rm <vm> --yes [--config]
dvm new <vm>
dvm version
```

## Main flow

`dvm sync <vm>` loads config, creates or starts `dvm-<vm>`, ensures `DVM_USER`
exists, creates `DVM_CODE_DIR`, then runs the configured setup scripts:

1. `DVM_GLOBAL_SETUP`
2. `DVM_SETUP`

```bash
DVM_DRY_RUN=1 dvm sync app
dvm sync app
dvm sh app
```

Dry-run prints the Lima argv and setup script order without contacting Lima.

`dvm sh <vm>` opens a shell as `DVM_USER`, starting in the project directory
when it exists.

`dvm ssh <vm> -- cmd...` runs one command as `DVM_USER`.

For logs, use `ssh`:

```bash
dvm ssh app -- sudo journalctl -f
```

## Files

```bash
dvm cp ./file app:/tmp/file
dvm cp app:/tmp/file ./file
```

One side must be `vm:path`. Use `./tmp:notes.txt` for local paths containing a
colon.

## Lifecycle

`dvm ls` and `dvm stop --all` operate on `dvm-*` Lima instances. Add
`--only-config` to limit them to instances with `~/.config/dvm/vms/*.sh`.

`dvm rm <vm> --yes` deletes the Lima instance. Add `--config` to also remove
the VM config and the starter setup script path created by `dvm new`.
