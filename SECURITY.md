# Security Policy

## Supported Versions

Until DVM has tagged releases, only the current `main` branch is maintained.
After the first release, only the latest published release will be supported
for security fixes.

## Reporting A Vulnerability

Use GitHub private vulnerability reporting for this repository. Please do not
open a public issue with exploit details, secret material, or a working proof
of concept.

If private vulnerability reporting is not available, open a public issue
requesting a private disclosure channel and include no technical details.

## Security Model

DVM is a tiny wrapper around Lima plus Bash recipes. It does not provide
stronger isolation than Lima, QEMU, macOS virtualization, SSH, Linux
permissions, or the packages and scripts users run inside their VMs.

Defaults:

- host directories are not mounted into guests (`--mount-none`)
- code lives inside the guest at `/home/<user>/code/<vm>`
- DVM only configures Lima localhost-style `host_port:guest_port` forwards
- secrets are staged from env vars listed in `DVM_SECRETS`
- recipes are plain Bash and should be audited like any shell script

## Secret Staging

Names listed in `DVM_SECRETS` are read from the host process environment at
sync time and piped to the guest with one `limactl shell` call per secret.
The secret value flows through stdin; only the target filename appears in
argv. Recipes read from `/tmp/dvm-secret-<NAME>` via `dvm_secret <NAME>`.
DVM removes staged secret files before optional project clone/hooks run.

Do not put secrets in DVM config files.

## Agent User

The `agent-user` recipe creates `DVM_AGENT_USER` and installs `dvm-agent`.
When Bubblewrap works, `dvm-agent <cmd>` hides the main user home and exposes
only the project directory and the agent user's home. It also installs
`dvm-agent-shell` for an interactive restricted shell. If Bubblewrap cannot run,
it falls back to plain `sudo -u DVM_AGENT_USER`.

This is a guardrail, not a complete sandbox.

For normal VM-contained development, running AI tools directly as `DVM_USER` is
the most useful mode when the VM contains only project-scoped keys and local or
sandbox credentials. Do not forward broad host SSH/GPG agents or store
production credentials in those VMs.

User names used by DVM are validated before they are written into generated
guest scripts or sudoers snippets.

## Guest-Local Keys

The `ssh-keys` and `gpg-keys` recipes generate keys inside the VM. DVM does
not copy host private keys into guests and does not back up guest keys on
`dvm rm`. The generated GPG key has an empty passphrase for disposable
guest-local signing; do not reuse it outside that project VM.

## Removed Safeguards

`dvm rm <vm> --yes` deletes the Lima instance even if the VM config file is
already gone. DVM does not run a dirty-git check. Inspect the VM first if
uncommitted work matters.
