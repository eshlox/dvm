# Security Standards

DVM is a convenience wrapper, not a security boundary beyond what Lima, the
guest OS, SSH, Linux permissions, and your recipes provide.

## Isolation Defaults

- host directories are not mounted into guests (`--mount-none`)
- code lives inside the VM at `/home/<user>/code/<vm>`
- DVM only configures Lima localhost-style `host_port:guest_port` forwards
- secrets are not stored in config files
- recipes are plain Bash and should be reviewed like any shell script

## Secrets

List secret env var names in `DVM_SECRETS`:

```bash
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY DVM_CLOUDFLARED_TOKEN)
```

At sync time, DVM reads those host env vars and pipes each value into the guest:

```text
/tmp/dvm-secret-<NAME>
```

The file is mode `0600`, owned by `DVM_USER`, and removed after sync. The
secret value is not placed in the `limactl` argv by DVM. Individual tools may
still expose secrets inside the guest while authenticating; review service
recipes before use.

DVM removes staged secret files before it runs the optional `DVM_GIT_REPO`
clone or `$DVM_CODE_DIR/.dvm/sync.sh` project hook. Keep secrets in recipes,
not in project-controlled hooks.

Do not put tokens, passwords, private keys, or long-lived credentials directly
in `config.sh` or VM config files.

## Agent User

For normal VM-contained development, it is acceptable to run AI tools directly
as `DVM_USER` when the VM contains only project-scoped keys and local or sandbox
credentials. This gives the tool access to the same shells, runtimes, databases,
test setup, and editor state you use inside the VM. Do not forward host
SSH/GPG agents into that VM, and do not store broad personal or production keys
there.

The `agent-user` recipe creates `DVM_AGENT_USER` and installs `dvm-agent`.
When Bubblewrap works in the guest, `dvm-agent <cmd>` runs the command as the
agent user with:

- read-only root filesystem
- hidden `/home`
- writable project directory
- writable agent user home
- network access preserved

If Bubblewrap cannot run, the wrapper falls back to a plain `sudo -u
DVM_AGENT_USER` command. That fallback is less isolated.

Use `dvm-agent-shell` to debug or work inside that restricted environment.
This is a guardrail, not a complete sandbox. Guest root, sudo mistakes, broad
filesystem permissions, or a VM escape can bypass it.

## Guest-Local Keys

The `ssh-keys` and `gpg-keys` recipes generate keys inside the VM. DVM does
not copy host private keys into guests and does not back up guest keys on
`dvm rm`. The generated GPG key uses an empty passphrase for disposable VM
convenience; treat it as VM-local and do not reuse it outside the project VM.

## Ports And Service Sharing

Lima's short `--port-forward host:guest` form is localhost-oriented. Prefer
Tailscale or Cloudflare Tunnel when teammates need access. For direct VM IP
access, configure Lima networking/YAML outside DVM.

## Deletion

`dvm rm <vm> --yes` deletes the Lima instance even if the VM config file is
already gone. DVM does not run a dirty-git check. Inspect the VM first if
uncommitted work matters.
