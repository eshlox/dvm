# DVM

Keep your friends close, your supply chain in a VM.

DVM, short for dev VM, is a small Bash wrapper around Lima for Fedora project VMs. It
keeps project code off the host, creates per-VM SSH keys, supports per-VM GPG signing
subkeys, syncs opt-in host dotfiles as snapshots, and provides an isolated `dvm-agent`
user for hosted AI coding tools.

## Requirements

- macOS
- Bash
- Lima
- GPG for `dvm gpg ...`

Guest support target:

- Lima `template:fedora`
- `dnf5` available in the guest

## Install

For stable installations, use a signed release tag:

```bash
git clone https://github.com/eshlox/dvm.git ~/.local/share/dvm-core
cd ~/.local/share/dvm-core
git fetch --tags --force
git tag -v vX.Y.Z
git checkout --detach vX.Y.Z
./install.sh --init
```

This symlinks:

```text
~/.local/bin/dvm -> <repo>/bin/dvm
```

Update the core by moving to a newer signed release tag:

```bash
cd ~/.local/share/dvm-core
git fetch --tags --force
git tag -v vX.Y.Z
git checkout --detach vX.Y.Z
./install.sh
```

Development checkouts may track `main` and update with `git pull --ff-only`.

## Quick Start

```bash
dvm init
dvm new myapp
dvm myapp
git clone git@github.com:example/myapp.git ~/code/myapp
```

Rerun setup in one VM or every VM:

```bash
dvm setup myapp
dvm setup-all
```

Run hosted AI tools through the restricted agent user:

```bash
dvm agent setup myapp
dvm agent install myapp codex # or claude, opencode, mistral, all
dvm agent myapp -- codex
```

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
dvm agent setup|install|<name> ...
dvm gpg create|install|forget|revoke ...
dvm doctor
dvm completion zsh
```

`dvm <name>` is a shortcut for `dvm enter <name>`. `dvm <name> <command...>` runs a
single command in that VM, like `dvm ssh <name> <command...>`.

## Docs

- [Docs index](docs/README.md)
- [VM lifecycle](docs/vms.md)
- [Config and dotfiles](docs/config.md)
- [GPG signing subkeys](docs/gpg.md)
- [Local llama.cpp AI VM](docs/ai-vm.md)
- [Hosted AI tools through `dvm agent`](docs/ai-tools.md)
- [Security policy and model](SECURITY.md)
- [Contributing](CONTRIBUTING.md)
- [Maintainer release process](docs/release.md)
- [GitHub security settings](docs/github-security.md)

## Security

Read [SECURITY.md](SECURITY.md) before installing DVM for stable use. Short version:

- install and update from signed release tags
- keep `main` for development and testing
- do not run remote install scripts directly
- keep setup scripts in user-controlled config or dotfiles
- run hosted AI tools through `dvm agent`, not the normal VM user

## License

DVM is released under the [MIT License](LICENSE).
