# Security policy

## Supported versions

Until tagged releases exist, only `main` is maintained.

## Report a vulnerability

Use GitHub private vulnerability reporting. Do not open public issues with
exploit details, secrets, or proof-of-concept code.

## Model

DVM is a Lima wrapper plus trusted user-owned setup scripts. It is not stronger
than Lima, the guest OS, Linux permissions, SSH, or the tools you run inside the
VM. Host protection is `--mount-none` plus keeping code inside the guest.

Full model, defaults, trust boundaries, and threats:
[docs/security.md](docs/security.md).
