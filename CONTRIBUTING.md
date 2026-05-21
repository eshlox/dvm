# Contributing

DVM is intentionally small. The host program is one Bash script (`bin/dvm`)
that conducts `limactl` and renders a small guest-side Bash script. Guest setup
behavior belongs in repo-owned or user-owned recipes, not in a large framework.

Good fits:

- small fixes to the wrapper commands
- improvements to Lima command construction or recipe execution
- focused built-in recipes for common development tools
- docs that explain the config, recipe, VM, and security model clearly
- shell tests for wrapper behavior

Avoid:

- adding role collections or bundled provisioning frameworks
- typed schemas, catalogs, planners, or metadata registries
- host code mounts by default
- broad secret-store abstractions inside DVM
- features better handled by a user recipe or `dvm ssh <name> -- ...`

Run the local check before handing work back:

```bash
bash scripts/check
```

For every user-facing change, update `README.md` and add an entry under the
current unreleased section in [CHANGELOG.md](CHANGELOG.md). If a change is
internal-only, say so in the final summary.
