# SSH, GPG, And Signing

Keys are opt-in. VM creation does not create them.

Recommended DVM model:

- Use one VM-local SSH key per project for GitHub auth.
- Use the same VM-local SSH key for daily commit signing.
- Keep personal long-lived SSH and GPG keys on the host or offline.
- Use GitHub Actions for releases and artifact attestations.
- Keep `dvm gpg-key` available only for users who explicitly want VM-local GPG.

## SSH Key

Create or print a VM-local SSH key:

```bash
dvm ssh-key app
```

This command creates `~/.ssh/id_ed25519_dvm` inside the VM and configures
`~/.ssh/config` so `github.com` uses it.

If `git` is installed in the VM, it also configures SSH commit signing in
`~/.config/git/config`:

```ini
[gpg]
	format = ssh
[user]
	signingkey = ~/.ssh/id_ed25519_dvm.pub
[commit]
	gpgsign = true
```

## GitHub Access

For isolation, add the generated public key as a repository deploy key:

```text
Repository -> Settings -> Deploy keys -> Add deploy key
```

Recommended:

- Use read-only deploy keys for clone, pull, and test VMs.
- Enable write access only for VMs that must push.
- Use one deploy key per repo/VM when you want clean revocation.
- Delete that repo's deploy key if the VM is compromised.

Avoid adding every VM key to your personal GitHub account if isolation matters.
Personal account SSH keys are account-scoped, so every VM key can access the same repos
your account can access.

Deploy-key tradeoff: a deploy key is repo-scoped. If one VM needs many private repos,
add deploy keys to each repo or use a machine user with limited repo access.

## SSH Commit Signing

Add the same public key to GitHub as a signing key:

```text
GitHub -> Settings -> SSH and GPG keys -> New SSH signing key
```

GitHub supports using an existing SSH authentication key as a signing key too, but it
must be added as a signing key for commit verification.

Daily workflow:

```bash
dvm ssh-key app
dvm app
git commit -m "change"
git push
```

What SSH signing gives you:

- Commit signatures are stored in Git commits, not only on GitHub.
- GitHub can show the commit as `Verified`.
- The key is per VM/project, so revocation is simple.
- No GPG agent or GPG private key is needed inside the VM.

Local verification is separate from GitHub's badge. To verify SSH signatures locally,
configure an allowed signers file:

```bash
mkdir -p ~/.config/git
printf 'you@example.com %s\n' "$(cat ~/.ssh/id_ed25519_dvm.pub)" >~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
git log --show-signature
```

## Verification And Revocation

Signed commits are a Git feature. GitHub's green `Verified` badge is GitHub's trust UI
for that signature.

GitHub stores persistent verification records. Once a commit signature is verified on
GitHub, it remains verified within that repository network even if the signing key is
later rotated, revoked, expired, or the contributor leaves the organization.

That means key revocation is not normally a reason to avoid per-project SSH signing.
Revocation stops future trust in that key. It does not rewrite old commits.

Still, do not treat the GitHub badge as a permanent security proof for releases. For
releases, prefer CI-built artifacts and attestations. See [Releases](releases.md).

## SSH vs GPG

Use SSH signing for daily DVM commits when:

- You want the simplest setup.
- You already need an SSH key for GitHub auth.
- You want one key per project/VM.
- You want easy repo-level revocation.

Use GPG when:

- Your organization requires it.
- You want a long-lived identity chain outside GitHub.
- You need OpenPGP-specific features such as expiration and revocation metadata.
- You are signing important release tags from a trusted non-project environment.

DVM prefers SSH signing for day-to-day VM work. GPG is optional.

## Optional VM-Local GPG

Create or print a VM-local GPG key:

```bash
dvm gpg-key app
```

These keys live inside the VM. They are not copied from the host.

The generated GPG key is passwordless. Do not export its secret key unless you are
comfortable losing the VM-only boundary.

If you use VM-local GPG signing, keep the signing key out of shared dotfiles.

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

## Git Identity Recipe

Use this when you want to generate VM-local Git identity from DVM config.

`~/.config/dvm/config.sh` or `~/.config/dvm/vms/app.sh`:

```bash
DVM_GIT_NAME="Your Name"
DVM_GIT_EMAIL="you@example.com"
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS git-local.sh"
```

`~/.config/dvm/recipes/git-local.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${DVM_GIT_NAME:?set DVM_GIT_NAME in DVM config}"
: "${DVM_GIT_EMAIL:?set DVM_GIT_EMAIL in DVM config}"

mkdir -p "$HOME/.config/git"
cat >"$HOME/.config/git/local.gitconfig" <<GITCONFIG
[user]
	name = $DVM_GIT_NAME
	email = $DVM_GIT_EMAIL
GITCONFIG
chmod 600 "$HOME/.config/git/local.gitconfig"
```

Run it:

```bash
dvm setup app
```

If you use chezmoi, keep this logic in [Chezmoi](dotfiles/chezmoi.md) instead.

References:

- https://docs.github.com/authentication/managing-commit-signature-verification/about-commit-signature-verification
- https://docs.github.com/authentication/managing-commit-signature-verification/signing-commits
- https://git-scm.com/docs/git-config
