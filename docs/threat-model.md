# Threat Model

DVM reduces host exposure by keeping project code and tooling inside a Lima VM
with no host mount by default. It does not defend against a Lima/QEMU/guest
kernel escape, malicious code you intentionally run with guest root privileges,
or credentials you copy into the guest.

## Assets

| Asset | Protection Goal |
| --- | --- |
| Host home and SSH/GPG agents | not mounted or forwarded by default |
| Project VM code and credentials | isolated per VM and scoped to the project |
| Staged recipe secrets | short lifetime, private paths, cleaned before hooks |
| DVM config and user recipes | owned by the current user, not writable by others |
| Built-in recipes | auditable Bash, no live unverified installers by default |

## STRIDE Matrix

| Threat | Example | Mitigation |
| --- | --- | --- |
| Spoofing | unmanaged Lima instance named `dvm-app` | `dvm-*` documented as reserved; `ls`/`stop --all` support `--only-config` |
| Tampering | group-writable `~/.config/dvm/config.sh` changes provisioning | ownership and permission checks before sourcing config or user recipes |
| Repudiation | unclear generated provisioning actions | `DVM_DRY_RUN=1` prints Lima argv, guest script, hook privilege mode, and secret cleanup |
| Information disclosure | recipe secrets left in predictable `/tmp` paths | randomized root-owned `/run/dvm-secrets` paths, guest trap, host cleanup, cleanup before clone/hooks |
| Denial of service | concurrent base rebuild while cloning from base | base build/rm lock and sync refusal when a missing VM would clone from a locked base |
| Elevation of privilege | project hook runs with provisioning privileges | hooks run as `DVM_USER` by default; privileged hooks require explicit opt-in; repo-local hook allow-list is available |
| Elevation of privilege | agent user gets Docker socket access | Docker conflicts with `agent-user`; `DVM_DOCKER_AGENT_ACCESS=1` required for agent Docker group access |
| Supply chain | live installer changes between syncs | built-ins reject `curl | sh`; npm tools are exact-version, user-local installs |

## Residual Risk

Recipes still run in a sudo-capable provisioning context. Fedora packages,
npm lifecycle scripts for packages that require them, and user-provided
verified binary URLs can still execute malicious code inside the guest. The
`agent-user` recipe is a guardrail, not a sandbox strong enough for hostile
code. Treat the VM as disposable and keep credentials project-scoped.
