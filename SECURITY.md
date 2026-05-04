# Security Policy

## Supported Versions

Until DVM has tagged releases, only the current `main` branch is maintained. After the
first release, only the latest published release will be supported for security fixes.

## Reporting A Vulnerability

Use GitHub private vulnerability reporting for this repository. Please do not open a
public issue with exploit details, secret material, or a working proof of concept.

If private vulnerability reporting is not available, open a public issue requesting a
private disclosure channel and include no technical details.

## Security Model

DVM is a tiny wrapper around Lima. It does not provide stronger isolation than Lima,
QEMU, macOS virtualization, SSH, Linux permissions, or the packages and scripts users
run inside their VMs.

Defaults:

- host project directories are not mounted into guests
- `~` in DVM config means the guest user's home
- AI tools run inside the VM through `dvm-agent` when the recipe is used
- public dotfiles use HTTPS by default
- Cloudflare tokens are passed to apply explicitly, staged through a mode `0600` guest
  temp file, and written inside the VM
- forwarded ports bind to `127.0.0.1` unless config says otherwise
- `dvm rm --yes` checks nested Git repos before deleting unless `--force` is used

Most apply-time DVM environment values are visible to host process listings while
`limactl` runs. Do not put secrets in general `DVM_*` config. The bundled cloudflared
token handoff is special-cased so `CLOUDFLARED_TOKEN` and `DVM_CLOUDFLARED_TOKEN` are
not passed as `limactl shell env` arguments.

The `dvm-agent` recipe uses Unix ACLs to grant access to project code and restrict
common main-user secret paths, including SSH/GPG directories, token files, shell
histories, and common tool config directories. This is a guardrail, not a complete
sandbox. Guest root, sudo misconfiguration, broad filesystem permissions, known paths
outside the deny list, or VM compromise can bypass it.

The Claude recipe defaults to Claude Code `bypassPermissions` inside the mandatory
`dvm-agent` Bubblewrap sandbox. This is intended for unattended project work, but it
means Claude can write project code, run project commands, use the network, and access
the agent user's own home. Set `DVM_CLAUDE_BYPASS=0` for a VM when you want Claude's
permission prompts.

Do not put host private keys in recipes or VM configs. Generate VM-local keys with
`dvm ssh-key <name>` or `dvm gpg-key <name>` when needed. The GPG helper creates an
unencrypted one-year VM-local signing key for disposable VM use, not a long-lived
identity key.
