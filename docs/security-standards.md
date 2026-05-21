# Security standards

DVM is not a sandbox beyond Lima, the guest OS, Linux permissions, and the code
you run inside the VM.

## Defaults

- no host mounts
- project code lives inside the guest
- only localhost-style Lima port forwards
- secrets come from env vars, not config files
- project hooks are disabled
- recipes are Bash and should be reviewed

## Secrets

List secret names:

```bash
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY)
```

Run sync with values in the host environment:

```bash
DVM_TAILSCALE_AUTHKEY=tskey-... dvm sync app
```

DVM stages each secret under randomized root-owned `/run/dvm-secrets` paths,
exports only the path, and cleans secrets before clone/hooks. Tool-specific
auth commands may still expose secrets inside the guest.

## Project hooks

Hooks are off by default:

```bash
DVM_PROJECT_HOOK=0
```

When enabled, `.dvm/sync.sh` runs as `DVM_USER`. Privileged hooks require:

```bash
DVM_PROJECT_HOOK_PRIVILEGED=1
```

Require repo-local opt-in with:

```bash
DVM_PROJECT_HOOK_GIT_CONFIG=1
git config dvm.hook true
```

## Config

Config and user recipes are Bash code. DVM rejects files or config directories
that are not owned by the current user or are group/world writable.

```bash
chmod go-w ~/.config/dvm ~/.config/dvm/config.sh ~/.config/dvm/vms/app.sh
```

`DVM_ENV` rejects secrets and dangerous names such as `PATH`, `BASH_ENV`,
`LD_*`, and `GIT_*`.

## Recipes

- npm tools are pinned and installed as `DVM_USER`
- `curl | sh` is rejected in built-ins
- direct binary recipes require HTTPS plus SHA-256
- Fedora packages track configured Fedora repos

## Agent user

`agent-user` installs `dvm-agent`. With Bubblewrap, it hides the main home,
binds the project directory and agent home, uses minimal `/dev`, and preserves
network by default.

If Bubblewrap is missing, `dvm-agent` refuses to run unless:

```bash
DVM_AGENT_ALLOW_UNSANDBOXED=1
```

Disable network for one run:

```bash
DVM_AGENT_NETWORK=0 dvm-agent codex
```

This is a guardrail, not a complete sandbox.

Docker group access is root-equivalent inside the guest. `docker` conflicts
with `agent-user`, and the agent user is not added to Docker unless:

```bash
DVM_DOCKER_AGENT_ACCESS=1
```

## Guest keys

`ssh-keys` and `gpg-keys` create VM-local keys. DVM does not copy host private
keys into guests. `gpg-keys` configures signing repo-locally only when a Git
repo already exists.
