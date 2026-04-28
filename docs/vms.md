# VM Lifecycle

DVM creates one Lima VM per project. The VM name is:

```text
$DVM_PREFIX-$name
```

With the default prefix, `dvm new myapp` creates `dvm-myapp`.

## Create

```bash
dvm new myapp
```

Creation does this:

- creates the Lima VM from `DVM_TEMPLATE`, defaulting to `template:fedora`
- disables host directory mounts by default
- starts the VM
- runs core setup
- runs user setup scripts
- creates a per-VM SSH key at `~/.ssh/id_ed25519_myapp` inside the VM
- prints the public SSH key

## Enter

```bash
dvm myapp
```

This is a shortcut for:

```bash
dvm enter myapp
```

The shell starts in `DVM_CODE_DIR`, which defaults to `~/code` in the guest.

Run a single command in the VM:

```bash
dvm ssh myapp uname -a
```

Print the VM's public GitHub SSH key:

```bash
dvm key myapp
```

## Setup

Rerun setup in one VM:

```bash
dvm setup myapp
```

Rerun setup in every DVM-managed VM:

```bash
dvm setup-all
```

This is the intended way to refresh packages, config, and dotfiles snapshots. DVM does
not remove packages automatically; removals should be explicit and manual.

## List

```bash
dvm list
```

`dvm list` shows VM names without the prefix.

## Delete

```bash
dvm rm myapp
```

Before deleting, DVM searches Git repositories under `DVM_CODE_DIR` in the VM. If any
repo has unstaged changes, staged changes, or untracked files, deletion is refused.

Force deletion:

```bash
dvm rm myapp --force
```

If a GPG signing subkey was created for the VM, `rm` prints the recorded subkey
fingerprint and the matching revoke command. Deleting a VM does not revoke GPG keys
automatically.

## Doctor And Completion

Check local requirements and paths:

```bash
dvm doctor
```

Enable zsh completion:

```bash
source <(dvm completion zsh)
```
