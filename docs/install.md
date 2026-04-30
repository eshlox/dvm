# Install

Install DVM by cloning the repository and running `install.sh`. The installer creates a
symlink to `bin/dvm`, so the checkout remains the DVM core.

## Requirements

```bash
brew install lima
```

Make sure the install prefix is on your `PATH`:

```bash
mkdir -p "$HOME/.local/bin"
```

## Stable Install

Use a signed release tag when installing for regular use:

```bash
git clone https://github.com/eshlox/dvm.git "$HOME/.local/share/dvm-core"
cd "$HOME/.local/share/dvm-core"
git fetch --tags --force
git tag -v vX.Y.Z
git checkout --detach vX.Y.Z
./install.sh --init
```

If tag verification fails, do not install that version.

## Development Install

Use `main` only for development or testing:

```bash
git clone https://github.com/eshlox/dvm.git "$HOME/.local/share/dvm-core"
cd "$HOME/.local/share/dvm-core"
./install.sh --init
```

This creates:

```text
~/.local/bin/dvm -> ~/.local/share/dvm-core/bin/dvm
```

## Custom Name Or Prefix

```bash
./install.sh --name dvm-dev --prefix "$HOME/bin" --init
```

## Verify

```bash
dvm help
dvm init
```

## Update DVM

For a signed release:

```bash
cd "$HOME/.local/share/dvm-core"
git fetch --tags --force
git tag -v vX.Y.Z
git checkout --detach vX.Y.Z
./install.sh
```

For a development checkout:

```bash
cd "$HOME/.local/share/dvm-core"
git pull --ff-only
./install.sh
```

DVM intentionally does not support remote install commands like `curl | sh`.
