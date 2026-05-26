# Contributing

DVM is intentionally small and audit-friendly: a Bash wrapper around Lima that
runs trusted user-owned setup scripts. Keep core behavior focused; prefer docs
and examples over framework code.

Good changes:

- simplify the core command
- improve Lima lifecycle handling
- improve config or setup-script validation
- improve security docs and examples
- improve tests for the current command surface

Non-goals:

- package-manager abstractions
- plugin systems
- bundled tool installers
- default host mounts
- secret-management frameworks

Rule: add core behavior only when it preserves DVM's simple security story and
does not turn setup examples into runtime policy.

Run before handing work back:

```bash
bash scripts/check
```
