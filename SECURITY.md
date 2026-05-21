# Security policy

## Supported versions

Until tagged releases exist, only `main` is maintained.

## Report a vulnerability

Use GitHub private vulnerability reporting. Do not open public issues with
exploit details, secrets, or proof-of-concept code.

## Model

DVM is a Lima wrapper plus Bash recipes. It is not stronger than Lima, the
guest OS, Linux permissions, SSH, or the tools you run inside the VM.

Defaults:

- no host mounts
- code lives inside the guest
- localhost-style port forwards only
- secrets come from env vars listed in `DVM_SECRETS`
- project hooks are disabled
- recipes are Bash and should be reviewed

## Main boundaries

- Secrets stage under randomized root-owned `/run/dvm-secrets` paths and are
  cleaned before clone/hooks.
- Config and user recipes must be current-user-owned and not group/world
  writable.
- `DVM_ENV` rejects secrets and dangerous names such as `PATH`, `BASH_ENV`,
  `LD_*`, and `GIT_*`.
- Built-in npm tools are pinned and installed as `DVM_USER`.
- Direct binary recipes require HTTPS plus SHA-256.

## Hooks

Hooks are off unless `DVM_PROJECT_HOOK=1`. Enabled hooks run as `DVM_USER`.
Privileged hooks require `DVM_PROJECT_HOOK_PRIVILEGED=1`. Optional repo-local
opt-in uses `DVM_PROJECT_HOOK_GIT_CONFIG=1` plus:

```bash
git config dvm.hook true
```

## Agent user

`agent-user` installs `dvm-agent`, a Bubblewrap guardrail that hides the main
home and exposes the project directory plus the agent home. It refuses to run
without Bubblewrap unless `DVM_AGENT_ALLOW_UNSANDBOXED=1` is set.

Docker group access is root-equivalent in the guest. DVM does not add
`DVM_AGENT_USER` to Docker unless `DVM_DOCKER_AGENT_ACCESS=1` is set.

## Keys

`ssh-keys` and `gpg-keys` create VM-local keys. DVM does not copy host private
keys into guests or back up guest keys on `dvm rm`.
