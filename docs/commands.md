# Commands

Running `dvm` with no args runs `dvm ls`.

```text
dvm sync <vm> | --all
dvm sh <vm>
dvm ssh <vm> -- cmd...
dvm cp src dst
dvm log <vm> [-f] [args]
dvm ls [--only-config] [<vm>]
dvm stop <vm> | --all [--only-config]
dvm rm <vm> --yes [--config]
dvm new <vm>
dvm edit <vm>
dvm config edit | show
dvm base build | rm
dvm recipes
dvm doctor [--probe <vm>]
dvm version
```

## Main Flow

`dvm sync <vm>` loads config, creates or starts `dvm-<vm>`, stages secrets,
runs packages and recipes, cleans secrets, optionally clones `DVM_GIT_REPO`,
and runs project hooks only when enabled.

```bash
DVM_DRY_RUN=1 dvm sync app
dvm sync app
dvm sh app
```

`dvm sh <vm>` opens a shell as `DVM_USER`, starting in the project directory
when it exists.

`dvm ssh <vm> -- cmd...` runs one command as `DVM_USER`.

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
the VM config.

## Base

`dvm base build` builds `dvm-<DVM_BASE_NAME>` from `DVM_BASE_PACKAGES` and
`DVM_BASE_RECIPES`. With `DVM_USE_BASE=1`, new VMs clone that base.

## Doctor

```bash
dvm doctor
dvm doctor --probe app
```

`--probe` checks that Lima can run a command inside the VM.
