# SSH And GPG

Keys are opt-in. VM creation does not create them.

Create or print a VM-local SSH key:

```bash
dvm ssh-key app
```

This also configures `~/.ssh/config` inside the VM so `github.com` uses
`~/.ssh/id_ed25519_dvm`.

## GitHub Access

For isolation, add the generated public key as a repository deploy key:

```text
Repository -> Settings -> Deploy keys -> Add deploy key
```

Recommended:

- use read-only deploy keys for clone/pull/test VMs
- enable write access only for VMs that must push
- use one deploy key per repo/VM when you want clean revocation
- delete that repo's deploy key if the VM is compromised

Avoid adding every VM key to your personal GitHub account if isolation matters.
Personal account SSH keys are account-scoped, so every VM key can access the same repos
your account can access. If one of many VM keys is compromised and you do not know
which VM leaked it, you usually need to revoke all of them.

Deploy-key tradeoff: a deploy key is repo-scoped. If one VM needs many private repos,
add deploy keys to each repo or use a machine user with limited repo access.

Create or print a VM-local GPG key:

```bash
dvm gpg-key app
```

These keys live inside the VM. They are not copied from the host.

The generated GPG key is passwordless. Do not export its secret key unless you are
comfortable losing the VM-only boundary.

## Git Signing Config

Do not hardcode `user.signingkey` in shared dotfiles when each VM has its own GPG key.
Split Git config into shared and local files.

Tracked `~/.gitconfig`:

```ini
[include]
	path = ~/.config/git/common.gitconfig
[include]
	path = ~/.config/git/local.gitconfig
```

Tracked `~/.config/git/common.gitconfig`:

```ini
[commit]
	gpgsign = true

[gpg]
	format = openpgp
```

Untracked `~/.config/git/local.gitconfig` inside each VM:

```ini
[user]
	name = Your Name
	email = you@example.com
	signingkey = ABCDEF1234567890
```

Get the VM fingerprint:

```bash
dvm gpg-key app
```

Then put that fingerprint in the VM-local `local.gitconfig`.

If you do not have a GPG key yet, leave the signing key out at first. Generate it
later, then rerun setup:

```bash
dvm gpg-key app
```

If you automate Git config from DVM, keep the value empty until then:

```bash
# ~/.config/dvm/config.sh or ~/.config/dvm/vms/app.sh
DVM_GIT_SIGNING_KEY=""
```

After `dvm gpg-key app` prints the fingerprint, set `DVM_GIT_SIGNING_KEY` and run:

```bash
dvm setup app
```

If each VM has a different GPG key, put `DVM_GIT_SIGNING_KEY` in that VM's config
instead of global `~/.config/dvm/config.sh`.

For bare-repo dotfiles, exclude the local file from the dotfiles repo:

```text
.config/git/local.gitconfig
```

## Generate Git Config From DVM

Use this when you do not use chezmoi templates for Git identity.

Put local values in global config or in one VM config:

```bash
# ~/.config/dvm/config.sh
DVM_GIT_NAME="Your Name"
DVM_GIT_EMAIL="you@example.com"
DVM_GIT_SIGNING_KEY=""
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS git-local.sh"
```

Create the recipe:

```bash
# ~/.config/dvm/recipes/git-local.sh
#!/usr/bin/env bash
set -euo pipefail

: "${DVM_GIT_NAME:?set DVM_GIT_NAME in ~/.config/dvm/config.sh}"
: "${DVM_GIT_EMAIL:?set DVM_GIT_EMAIL in ~/.config/dvm/config.sh}"
: "${DVM_GIT_SIGNING_KEY:=}"

mkdir -p "$HOME/.config/git"
{
	cat <<GITCONFIG
[user]
	name = $DVM_GIT_NAME
	email = $DVM_GIT_EMAIL
GITCONFIG
	if [ -n "$DVM_GIT_SIGNING_KEY" ]; then
		cat <<GITCONFIG
	signingkey = $DVM_GIT_SIGNING_KEY
GITCONFIG
	fi
} >"$HOME/.config/git/local.gitconfig"
chmod 600 "$HOME/.config/git/local.gitconfig"
```

Run it:

```bash
dvm setup app
```

If you use chezmoi, keep this logic in [Chezmoi](dotfiles/chezmoi.md) instead.
