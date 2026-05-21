# Threat model

DVM reduces host exposure by keeping code and tools inside a Lima VM with no
host mount. It does not defend against VM escapes or malicious guest-root code.

## Assets

| Asset | Goal |
| --- | --- |
| host home | not mounted into DVM-created VMs |
| project code | kept inside the guest |
| project credentials | scoped to the VM or guest user that needs them |
| config files | current-user-owned, not writable by others |
| setup scripts | explicit, current-user-owned, reviewed before execution |

## Threats

| Threat | Mitigation |
| --- | --- |
| host file exposure | `--mount-none` on DVM-created instances |
| config tampering | owner/mode checks before sourcing |
| setup script tampering | owner/mode checks before execution |
| unclear provisioning | `DVM_DRY_RUN=1` prints setup script order |
| unmanaged `dvm-*` instance | `--only-config` for `ls` and `stop --all` |
| repo-controlled provisioning | no built-in project hooks |
| guest-root compromise | use separate or throwaway VMs for higher-risk work |
| package supply chain | user-reviewed setup scripts, pinning, checksums |
| Docker root access | documented as guest-root equivalent |

Residual risk: packages, npm lifecycle scripts, downloaded binaries, service
auth commands, and project code can still run malicious code inside the guest.
Treat VMs as disposable and keep credentials scoped.
