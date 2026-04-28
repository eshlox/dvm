# DVM

Keep your friends close, your supply chain in a VM.

DVM, short for dev VM, is a small open source command-line wrapper around Lima for
current Fedora project VMs.

The repository contains the reusable core. User-specific VM behavior lives outside the
repo in `~/.config/dvm`, so local configuration can be kept in a separate dotfiles or
project configuration repository.

DVM is intentionally small. It creates similar Lima VMs, reruns user setup scripts,
manages per-VM SSH keys, helps with GPG signing subkeys, and refuses to delete a VM
when repositories have uncommitted changes.

## Install

Requirements:

- macOS
- Bash
- Lima
- GPG for `dvm gpg ...`

Guest support target:

- Lima `template:fedora`
- `dnf5` available in the guest

For stable installations, use a signed release tag:

```bash
git clone https://github.com/eshlox/dvm.git ~/.local/share/dvm-core
cd ~/.local/share/dvm-core
git fetch --tags --force
git tag -v vX.Y.Z
git checkout --detach vX.Y.Z
./install.sh --init
```

Replace `vX.Y.Z` with the release version to install. The `main` branch is for
development and testing.

This symlinks:

```text
~/.local/bin/dvm -> <repo>/bin/dvm
```

The scripts are written in Bash (`#!/usr/bin/env bash`). This is independent of your
interactive shell; using Zsh as the default macOS shell is fine.

Update the core by moving to a newer signed release tag:

```bash
cd ~/.local/share/dvm-core
git fetch --tags --force
git tag -v vX.Y.Z
git checkout --detach vX.Y.Z
./install.sh
```

Development checkouts may track `main` and update with `git pull --ff-only`.

## Config

`dvm init` creates:

```text
~/.config/dvm/config.sh
~/.config/dvm/setup.d/fedora.sh
~/.local/share/dvm/
```

User configuration is shell code by design and is the extension point.
The core targets Lima `template:fedora` and assumes `dnf5` inside the guest.

Common config:

```bash
DVM_PREFIX="dvm"
DVM_CPUS="4"
DVM_MEMORY="8GiB"
DVM_DISK="80GiB"

DVM_PACKAGES="git openssh-clients gpg helix ripgrep fd-find jq"
DVM_SETUP_SCRIPTS="$DVM_CONFIG/setup.d/fedora.sh"
DVM_DOTFILES_DIR="$HOME/.dotfiles"
```

Put package-independent setup, shell config, and tool config in `setup.d/fedora.sh`.
If `DVM_DOTFILES_DIR` is set, DVM copies a snapshot of that host directory into the VM
before user setup scripts run. It does not mount the host directory live. User setup
scripts run inside the VM as the guest user with:

```text
DVM_NAME
DVM_VM_NAME
DVM_CODE_DIR
DVM_DOTFILES_TARGET
```

Dotfiles sync is opt-in. By default DVM excludes `.git`, `.ssh`, `.gnupg`, `.env`, and
`secrets`, refuses dangerous source paths such as `/`, `$HOME`, `~/.ssh`, and
`~/.gnupg`, and keeps the target under the guest home directory.

The default workflow keeps source code inside the VM under `~/code`. No host project
directory is mounted.

## Commands

```text
dvm init
dvm new <name>
dvm setup <name>
dvm setup-all
dvm enter <name>
dvm ssh <name> [command...]
dvm key <name>
dvm list
dvm rm <name> [--force]
dvm ai create|setup|pull|models|use|status|host ...
dvm gpg create <name> <primary-key> [--expire 1y]
dvm gpg install <name> [secret-subkey.asc] [--signing-key fpr]
dvm gpg revoke <name>
dvm doctor
dvm completion zsh
```

`dvm <name>` is a shortcut for `dvm enter <name>`.

## Create A VM

```bash
dvm new myapp
```

This creates `dvm-myapp`, starts it, runs core setup, runs user setup scripts, creates
`~/.ssh/id_ed25519_myapp` inside the VM, and prints the public key.

Enter it:

```bash
dvm myapp
git clone git@github.com:example/myapp.git ~/code/myapp
```

Rerun setup in one or all VMs:

```bash
dvm setup myapp
dvm setup-all
```

This is the intended way to add packages everywhere or refresh dotfiles snapshots. The
script does not try to remove packages automatically; removals should be explicit and
manual.

## Delete Safety

```bash
dvm rm myapp
```

Before deleting, DVM searches Git repositories under `~/code` in the VM. If any repo
has unstaged changes, staged changes, or untracked files, deletion is refused.

Force deletion:

```bash
dvm rm myapp --force
```

If a GPG signing subkey was created for the VM, `rm` prints the recorded subkey
fingerprint and the revoke command. Deleting a VM does not revoke GPG keys
automatically.

## GPG

Create a signing subkey on the host and export a secret-subkey bundle:

```bash
dvm gpg create myapp <primary-key-id> --expire 1y
```

Files are written under:

```text
~/.local/share/dvm/gpg/
```

Install the subkey into the VM and configure Git commit signing:

```bash
dvm gpg install myapp
```

Revoke the VM subkey on the host:

```bash
dvm gpg revoke myapp
```

Revocation only updates the local GPG keyring and exports the updated public key. It
does not update GitHub/GitLab, remove old public keys from remote services, delete the
secret bundle from disk, or change anything inside an already-deleted VM. Upload the
updated public key wherever the old public key was trusted. Depending on the local GPG
setup, revoke/create commands may open pinentry.

## Doctor

Check local requirements and paths:

```bash
dvm doctor
```

## Completion

Zsh:

```bash
source <(dvm completion zsh)
```

Add that line to a shell startup file to enable completion automatically.

## Security

Read [SECURITY.md](SECURITY.md) before installing DVM for stable use. The short
version:

- install and update from signed release tags
- keep `main` for development and testing
- do not run remote install scripts directly
- keep VM setup scripts in user-controlled config or dotfiles
- review setup scripts before running `dvm setup` or `dvm setup-all`

Repository maintainer settings are documented in
[docs/github-security.md](docs/github-security.md).

## License

DVM is released under the [MIT License](LICENSE).

## Contributing

Contributions are welcome when they keep the project small, auditable, and focused on
VM lifecycle, SSH, GPG, and user-controlled setup. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## Maintainer Release Process

Maintainer checklist:

```bash
bash scripts/check.sh
git tag -s vX.Y.Z -m "dvm vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

Create the GitHub release from the signed `v*` tag. Published releases and tags should
not be moved or replaced; publish a new fixed release instead.

## AI VM

`dvm ai` manages an opinionated llama.cpp VM. It still uses a normal DVM VM under the
hood, named `ai` by default, but adds package install, model download, model switching,
and a managed `llama-server` systemd service.

For hosted AI coding tools such as Claude Code and Codex CLI, see
[docs/ai-tools.md](docs/ai-tools.md). Those tools are best installed from user setup
scripts because they have separate package repositories, npm packages, authentication,
and sandbox settings.

Example config:

```bash
DVM_AI_NAME="ai"
DVM_AI_PORT="8080"
DVM_AI_DEFAULT_MODEL="qwen25-coder-7b-q4"
DVM_AI_MODELS="qwen25-coder-7b-q4=https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf?download=true"
```

Create and configure the VM:

```bash
dvm ai create
```

This creates `dvm-ai`, installs Fedora's `llama-cpp` package, writes a systemd service
for `llama-server`, downloads configured models, points `current.gguf` at
`DVM_AI_DEFAULT_MODEL`, and restarts the service.

Common operations:

```bash
dvm ai models
dvm ai use qwen25-coder-7b-q4
dvm ai status
dvm ai host
dvm ai pull qwen25-coder-7b-q4
```

For a non-default AI VM name, use:

```bash
dvm ai create lab
dvm ai use --vm lab qwen25-coder-7b-q4
```

Models are stored in `DVM_AI_MODELS_DIR`, which defaults to `~/models` in the guest.
Configured model aliases become filenames, so `qwen=https://...` is saved as
`qwen.gguf`. The active model is the `current.gguf` symlink.
