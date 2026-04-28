# GPG Signing Subkeys

DVM can create a signing subkey on the host and install only that subkey into one VM.
If the VM is deleted or no longer trusted, revoke that VM's subkey without rotating the
primary key.

## Create

```bash
dvm gpg create myapp <primary-key-id> --expire 1y
```

Files are written under:

```text
~/.local/share/dvm/gpg/
```

The command writes:

- a public key export
- a secret-subkey export for the VM
- metadata with the primary fingerprint and subkey fingerprint

Depending on local GPG setup, this may open pinentry.

## Install

```bash
dvm gpg install myapp
```

This imports the VM's secret-subkey bundle into the VM and configures Git commit signing:

```bash
git config --global gpg.program gpg
git config --global user.signingkey '<subkey>!'
git config --global commit.gpgsign true
```

You can pass an explicit bundle or signing key:

```bash
dvm gpg install myapp ~/.local/share/dvm/gpg/myapp-secret-subkey.asc
dvm gpg install myapp --signing-key <fingerprint>
```

When installing the generated bundle recorded in DVM metadata, `dvm gpg install`
removes that host-side secret bundle after a successful import. Pass `--keep-secret`
if you need to retain the bundle temporarily:

```bash
dvm gpg install myapp --keep-secret
```

Forget a recorded generated bundle without installing it:

```bash
dvm gpg forget myapp
```

## Revoke

```bash
dvm gpg revoke myapp
```

Revocation updates the local GPG keyring and exports the updated public key. It does
not:

- update GitHub, GitLab, or other remote services
- remove old public keys from places where they were trusted
- change anything inside an already-deleted VM

Upload the updated public key wherever the old public key was trusted.
