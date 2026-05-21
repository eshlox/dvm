# Security policy

## Supported versions

Until tagged releases exist, only `main` is maintained.

## Report a vulnerability

Use GitHub private vulnerability reporting. Do not open public issues with
exploit details, secrets, or proof-of-concept code.

## Model

DVM is a Lima wrapper plus trusted user-owned setup scripts. It is not stronger
than Lima, the guest OS, Linux permissions, SSH, or the tools you run inside the
VM.

Defaults:

- no host mounts in the DVM create path
- code lives inside the guest
- localhost-style port forwards only
- only configured setup scripts run during sync
- setup scripts must be current-user-owned and not group/world writable

## Boundaries

- DVM protects the host primarily by using Lima with `--mount-none`.
- Guest root can read all files inside that guest.
- Setup scripts are trusted provisioning code and must be reviewed.
- DVM does not stage secrets or manage tool supply chains.

See [docs/security-standards.md](docs/security-standards.md) and
[docs/threat-model.md](docs/threat-model.md).
