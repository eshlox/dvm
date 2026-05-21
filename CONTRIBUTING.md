# Contributing

DVM is intentionally small and audit-friendly. It is a Bash wrapper around Lima
that runs trusted user-owned setup scripts.

Good changes:

- simplify the core command
- improve Lima lifecycle handling
- improve config or setup-script validation
- improve security documentation and examples
- improve tests for the current command surface

Avoid:

- package-manager abstractions
- plugin systems
- bundled tool installers
- default host mounts
- secret-management frameworks

Run before handing work back:

```bash
bash scripts/check
```
