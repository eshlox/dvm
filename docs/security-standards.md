# Security Standards

DVM is a convenience wrapper, not a security boundary beyond what Lima, the
guest OS, SSH, Linux permissions, and your recipes provide.

## Isolation Defaults

- host directories are not mounted into guests (`--mount-none`)
- code lives inside the VM at `/home/<user>/code/<vm>`
- DVM only configures Lima localhost-style `host_port:guest_port` forwards
- secrets are not stored in config files
- project hooks run as `DVM_USER` unless privileged hooks are explicitly enabled
- recipes are plain Bash and should be reviewed like any shell script

## Secrets

List secret env var names in `DVM_SECRETS`:

```bash
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY DVM_CLOUDFLARED_TOKEN)
```

At sync time, DVM reads those host env vars and pipes each value into the guest:

```text
/run/dvm-secrets/<random>/<random>-<NAME>
```

The per-sync directory is root-owned with mode `0700`; files are root-owned
with mode `0600`. The randomized path is exported to the guest script for the
listed secret name and is also cleaned by a guest-side trap plus host-side
cleanup. The secret value is not placed in the `limactl` argv by DVM.
Individual tools may still expose secrets inside the guest while
authenticating; review service recipes before use.

DVM removes staged secret files before it runs the optional `DVM_GIT_REPO`
clone or `$DVM_CODE_DIR/.dvm/sync.sh` project hook. Keep secrets in recipes,
not in project-controlled hooks.

## Project Hooks

Project hooks are project-controlled code. DVM runs
`$DVM_CODE_DIR/.dvm/sync.sh` as `DVM_USER` by default after recipe-time secrets
are cleaned. Set `DVM_PROJECT_HOOK=0` to disable hooks.

`DVM_PROJECT_HOOK_PRIVILEGED=1` is an explicit trust decision: the hook runs in
the same provisioning context as recipes and dry-run output includes a warning.
Use it only for repositories you fully trust. Set
`DVM_PROJECT_HOOK_GIT_CONFIG=1` to require repo-local
`git config dvm.hook true` before any hook runs.

## Config And Recipe Files

DVM config and user recipes are Bash code. Before sourcing config or including
a user recipe override, DVM rejects files or containing config directories that
are not owned by the current user or are group/world writable.

```bash
chmod go-w ~/.config/dvm ~/.config/dvm/config.sh ~/.config/dvm/vms/app.sh
```

`DVM_ENV` is also constrained: it rejects secrets and dangerous names such as
`PATH`, `BASH_ENV`, `LD_*`, and `GIT_*`.

## Recipe Supply Chain

Built-in npm recipes install exact versions into a user-owned npm prefix.
Codex uses `--ignore-scripts`; Claude Code and opencode currently require npm
lifecycle scripts, but those scripts run as `DVM_USER` rather than root.

The `ollama` and `mistral` recipes fail closed unless you provide a pinned
HTTPS URL and SHA-256 checksum. Built-in recipes are statically tested against
`curl | sh` and root-global npm installs.

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
- minimal `/dev`
- network access preserved by default

If Bubblewrap cannot run, the wrapper refuses to execute. Set
`DVM_AGENT_ALLOW_UNSANDBOXED=1` only when you intentionally want the weak
plain-`sudo` guardrail. Set `DVM_AGENT_NETWORK=0` for a no-network Bubblewrap
run.

Use `dvm-agent-shell` to debug or work inside that guardrail environment.
This is a guardrail, not a complete sandbox. Guest root, sudo mistakes, broad
filesystem permissions, or a VM escape can bypass it.

The Docker group is root-equivalent inside the guest. The Docker recipe adds
`DVM_USER`, but it does not add `DVM_AGENT_USER` unless
`DVM_DOCKER_AGENT_ACCESS=1` is set, and `docker` conflicts with `agent-user` by
default. Prefer rootless Podman or another narrower container path for agent
workloads that need containers.

## Guest-Local Keys

The `ssh-keys` and `gpg-keys` recipes generate keys inside the VM. DVM does
not copy host private keys into guests and does not back up guest keys on
`dvm rm`. The generated GPG key uses an empty passphrase for disposable VM
convenience; treat it as VM-local and do not reuse it outside the project VM.
When a project Git repo already exists, `gpg-keys` enables signing in that repo
only; otherwise it prints the public key and does not set global Git signing.

## Ports And Service Sharing

Lima's short `--port-forward host:guest` form is localhost-oriented. Prefer
Tailscale or Cloudflare Tunnel when teammates need access. For direct VM IP
access, configure Lima networking/YAML outside DVM.

## Deletion

`dvm rm <vm> --yes` deletes the Lima instance even if the VM config file is
already gone. DVM does not run a dirty-git check. Inspect the VM first if
uncommitted work matters.
