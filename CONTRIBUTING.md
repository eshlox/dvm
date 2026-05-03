# Contributing

DVM is intentionally small. Keep the wrapper boring and put setup behavior in recipes
or docs unless the wrapper truly has to bridge host config to Lima.

Good fits:

- small fixes to the wrapper commands
- guest recipes that are plain, idempotent shell
- docs that explain how to use or modify recipes
- shell tests for wrapper behavior

Avoid:

- typed schemas, catalogs, planners, reports, or metadata registries
- recipe dependency systems
- host code mounts by default
- secret-store abstractions
- features better handled by `dvm ssh <name> -- ...`

Run checks before handing work back:

```bash
bash scripts/check.sh
```

For every user-facing change, update the relevant docs and add an entry under
`Unreleased` in [CHANGELOG.md](CHANGELOG.md). If a change is internal-only, say that in
the final summary.
