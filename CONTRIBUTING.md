# Contributing

DVM is intentionally small. The entire host program is one Bash script
(`bin/dvm`) that conducts `limactl` and `ansible-playbook`. Guest setup
behavior belongs in the user's external Ansible repo, not here.

Good fits:

- small fixes to the wrapper commands
- improvements to Lima command construction or Ansible invocation
- docs that explain the external Ansible repo contract more clearly
- shell tests for wrapper behavior

Avoid:

- adding runtime recipes, role collections, or bundled provisioning
- typed schemas, catalogs, planners, or metadata registries
- host code mounts by default
- secret-store abstractions inside DVM
- features better handled by the user's Ansible playbook or `dvm ssh <name>`

Run the smoke test before handing work back:

```bash
bash tests/smoke.sh
```

For every user-facing change, update `README.md` and add an entry under the
current unreleased section in [CHANGELOG.md](CHANGELOG.md). If a change is
internal-only, say so in the final summary.
