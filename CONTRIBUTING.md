# Contributing

DVM is intentionally small. Contributions should keep the core easy to audit and avoid
turning the project into a general VM platform or package manager.

## Scope

Good fits:

- VM lifecycle helpers around Lima
- safe setup reruns across VMs
- SSH and GPG workflows for project VMs
- documentation that improves installation, release verification, or safe usage
- focused tests for shell behavior

Avoid:

- default language/toolchain installers
- remote install scripts or `curl | sh` patterns
- host directory mounts that weaken project isolation by default
- large framework dependencies
- features that are better handled by user setup scripts

## Development

Run checks before opening a pull request:

```bash
bash scripts/check.sh
```

Shell code should be Bash, pass `bash -n`, and pass ShellCheck when ShellCheck is
available. Keep behavior explicit and prefer small functions over broad abstractions.

## Security

Do not report vulnerabilities in public issues. Follow [SECURITY.md](SECURITY.md).

Changes that affect installation, updating, release verification, SSH, GPG, deletion
safety, or setup script execution should include tests or a clear explanation of the
remaining risk.
