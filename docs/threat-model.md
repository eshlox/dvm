# Threat Model

DVM reduces host exposure by keeping code and tools inside a Lima VM with no
host mount. It does not defend against VM escapes or malicious guest-root code.

## Assets

| Asset | Goal |
| --- | --- |
| host home and agents | not mounted or forwarded by default |
| project credentials | scoped to one VM/project |
| staged secrets | short lifetime, private paths |
| config and user recipes | current-user-owned, not writable by others |
| built-ins | auditable Bash, no live unverified installers |

## Threats

| Threat | Mitigation |
| --- | --- |
| unmanaged `dvm-*` instance | `--only-config` for `ls` and `stop --all` |
| writable config tampering | owner/mode checks before sourcing |
| unclear provisioning | `DVM_DRY_RUN=1` prints generated script |
| secret disclosure | randomized `/run/dvm-secrets`, cleanup before clone/hooks |
| base rebuild race | base lock |
| project hook privilege | hooks disabled; privileged hooks require opt-in |
| agent Docker root access | Docker conflict plus explicit agent opt-in |
| installer drift | no `curl | sh`; pinned npm tools |

Residual risk: recipes, packages, npm lifecycle scripts, and verified binaries
can still run malicious code inside the guest. Treat VMs as disposable and keep
credentials project-scoped.
