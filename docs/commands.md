# Commands

DVM keeps the command surface small. Most day-to-day work should still be `sync`,
`sh`, and `ssh`; the extra helpers cover logs and VM-local keys.

Use public project names in DVM commands: `app`, `eshlox-net`, `llama`. The `dvm-`
prefix is reserved for internal Lima instance names.

## Zsh Completion

DVM ships an opt-in zsh completion file in the repo:

```zsh
# ~/.zshrc
fpath=(/path/to/dvm/share/dvm/completions $fpath)
autoload -Uz compinit
compinit
```

Zsh loads completion functions from directories in `fpath`, so the path points to the
`completions` directory, not directly to `_dvm`. If your `~/.zshrc` already runs
`compinit`, add only the `fpath=...` line above the existing `compinit` call.

The completion includes DVM commands, command options, VM names from
`$DVM_CONFIG/vms/*.sh`, DVM Lima instances from `limactl list`, and bundled `init`
templates.

## Init

```bash
dvm init app
dvm init llama llama
dvm init cloudflared cloudflared
```

`init` copies a bundled VM config template from `share/dvm/vms/<template>.sh` to
`~/.config/dvm/vms/<name>.sh` and opens it in `$EDITOR`, falling back to `$VISUAL` and
then `vi`. The template defaults to `app`. Existing configs are not overwritten.

## Sync

```bash
dvm sync app
dvm sync --all
```

`sync` creates the VM if missing, starts it, runs `baseline`, runs recipes selected in
`~/.config/dvm/vms/app.sh`, then runs `$DVM_CODE_DIR/.dvm/sync.sh` inside the guest if
present. Before running guest scripts, DVM prints the expanded recipe list so helper
functions such as `use_app_tools` are easy to verify.

If the VM already exists, `sync` updates Lima port forwards from `DVM_PORTS` without
recreating the VM. Lima may restart the instance when ports change.

`sync --all` syncs every active VM config in `~/.config/dvm/vms/*.sh`, continues
after failures, and exits non-zero if any VM failed. Use it after recipe changes or to
update recipe-managed tools across all VMs.

## Shell

```bash
dvm sh app
```

Starts the VM and opens an interactive shell in `DVM_CODE_DIR`. DVM reads the guest
user's login shell from `/etc/passwd`, so recipes can switch it with `usermod --shell`;
the `zsh` recipe sets it to zsh. DVM also exports `SHELL` to that login shell before
starting it, so tools see the same shell that `sh` launches. If the host terminal
advertises a terminfo name that the guest does not know, such as `xterm-ghostty`, DVM
falls back to `xterm-256color` for the guest shell.

`~` at the start of `DVM_CODE_DIR` expands inside the guest, so
`DVM_CODE_DIR="~/code/app"` enters `/home/<user>/code/app`.

## SSH

```bash
dvm ssh app -- pwd
dvm ssh cloudflared -- journalctl -u dvm-cloudflared.service -f
```

Runs one command inside the VM from `DVM_CODE_DIR`.

## Copy

```bash
dvm cp ./plan.md app:.
dvm cp -r ./docs app:docs
dvm cp app:output/report.md ./report.md
dvm cp app:/tmp/log.txt ./log.txt
```

Copies files between the host and a VM using Lima's `limactl copy`. Guest paths use the
public DVM name followed by `:`. Relative guest paths resolve under `DVM_CODE_DIR`, so
`app:.` means the app VM's code directory and `app:docs/plan.md` means
`$DVM_CODE_DIR/docs/plan.md`. Absolute guest paths stay absolute.

The command starts the VM first and creates `DVM_CODE_DIR` if needed. When copying
host files into `DVM_CODE_DIR`, DVM refreshes `dvm-agent` ACLs on the copied paths so
the AI wrappers can read and write them. It supports `-r`/`--recursive`,
`-v`/`--verbose`, and `--backend auto|scp|rsync`.

## Log

```bash
dvm log cloudflared
dvm log cloudflared -f
dvm log app nginx.service -f
```

Shows `journalctl` output from inside the VM. When the VM config uses exactly one known
service recipe, DVM picks the unit automatically:

- `use cloudflared`: `dvm-cloudflared.service`
- `use llama`: `dvm-llama.service`
- `use tailscale`: `tailscaled.service`

Otherwise pass the unit explicitly. With no journal arguments DVM uses
`--no-pager -n 100`; when DVM can infer the unit, journal arguments can follow the VM
name directly. All remaining arguments are passed to `journalctl`, including filters
such as `--since` and `--until`.

## VM-Local Keys

```bash
dvm ssh-key app
dvm gpg-key app
```

`ssh-key` creates or reuses two VM-local SSH keys:

- `~/.ssh/id_ed25519_dvm`: GitHub access key. Use this as a repo deploy key or an
  account authentication key.
- `~/.ssh/id_ed25519_dvm_signing`: Git commit signing key. Add this to your GitHub
  account as an SSH signing key.

The same GitHub SSH key cannot be both a repo deploy key and an account signing key, so
DVM keeps those identities separate. The command also adds a GitHub SSH config entry for
the access key and configures Git SSH signing with the signing key. Missing or empty
public key files are regenerated through a temporary file and moved into place.

`gpg-key` creates or reuses a one-year VM-local signing key and prints the public key
plus fingerprint. Neither command copies host private keys into the VM.

## List

```bash
dvm ls
```

Shows DVM-managed Lima VMs. The displayed names are the DVM public names without the
internal `dvm-` prefix and are aligned for terminal output.

## Stop

```bash
dvm stop app
dvm stop --all
dvm stop --all --inactive
dvm stop --inactive
dvm stop --inactive --force
```

`stop <name>` stops one Lima VM.

`stop --all` stops every DVM-managed Lima instance listed with the internal `dvm-`
prefix, including instances whose DVM config was later removed. It releases VM memory
without deleting disks or config.

`stop --inactive` is shorthand for `stop --all --inactive`. It probes each running
DVM VM and stops only VMs without a detected interactive shell, `tmux` process,
`zellij` process, or active known DVM service unit (`dvm-cloudflared.service`,
`dvm-llama.service`, `tailscaled.service`). This is intentionally conservative; it
does not prove that arbitrary background jobs or dev servers are idle unless they are
inside one of those detected sessions or services.

Bulk stop commands skip already stopped instances, report failures, and exit non-zero
if any VM failed to stop. With `--inactive`, active instances are skipped too, and
`--force` stops a VM when the activity probe fails; VMs that are successfully detected
as active are still skipped. To stop active VMs too, use plain `dvm stop --all`.

## Remove

```bash
dvm rm app --yes
dvm rm app --yes --force
```

Deletes the Lima VM. `--yes` is required. Before deleting, DVM starts the VM and scans
nested Git repos under `DVM_CODE_DIR`; dirty repos stop deletion. `--force` skips that
scan. If the Lima VM exists but the DVM config file is missing, DVM warns that it is
deleting an orphan and skips the dirty check because it does not know `DVM_CODE_DIR`.
Recreate is intentionally `dvm rm app --yes` followed by `dvm sync app`.
