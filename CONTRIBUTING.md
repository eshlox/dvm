# Contributing

DVM is intentionally small. Contributions should keep the core easy to audit and avoid
turning the project into a general VM platform or package manager.

## Scope

Good fits:

- VM lifecycle helpers around Lima
- small, auditable recipe examples
- documentation that improves safe usage
- focused tests for shell behavior

Avoid:

- default language/toolchain installers
- remote install scripts or `curl | sh` patterns
- host directory mounts that weaken project isolation by default
- large framework dependencies
- features that are better handled by per-VM config or recipes

Before adding a feature, read [Extending DVM](docs/extending.md). Most additions should
be docs or recipes. Core commands need a stronger reason because they increase the
maintenance and security surface for every user.

## Development

Run checks before opening a pull request:

```bash
bash scripts/check.sh
```

Shell code should be Bash, pass `bash -n`, and pass ShellCheck when ShellCheck is
available. Keep behavior explicit and prefer small functions over broad abstractions.

## Security

Do not report vulnerabilities in public issues. Follow [SECURITY.md](SECURITY.md).

Changes that affect installation, VM creation/deletion, key helpers, dotfiles sync, or
setup execution should include tests or a clear explanation of the remaining risk.
