# Contributing

DVM is intentionally small. The entire host program is one Bash script
(`bin/dvm`). Put setup behavior in recipes (`share/dvm/recipes/`), not in
`bin/dvm`, unless the wrapper truly has to bridge host config to Lima.

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

Run the smoke test before handing work back:

```bash
bash tests/smoke.sh
```

For every user-facing change, update `README.md` and add an entry under
`Unreleased` in [CHANGELOG.md](CHANGELOG.md). If a change is internal-only,
say so in the final summary.
