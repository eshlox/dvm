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
[user]
	name = Your Name
	email = you@example.com

[commit]
	gpgsign = true

[gpg]
	format = openpgp
```

Untracked `~/.config/git/local.gitconfig` inside each VM:

```ini
[user]
	signingkey = ABCDEF1234567890
```

Get the VM fingerprint:

```bash
dvm gpg-key app
```

Then put that fingerprint in the VM-local `local.gitconfig`.

For bare-repo dotfiles, exclude the local file from the dotfiles repo:

```text
.config/git/local.gitconfig
```

To automate this from DVM, put private host values in `~/.config/dvm/private.sh`, put
the writer script in `~/.config/dvm/recipes/git-local.sh`, and activate it with
`DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS git-local.sh"`.

See [Dotfiles](dotfiles.md#private-git-config-recipe) for the exact files and commands.
