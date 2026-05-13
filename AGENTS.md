# Agent Instructions

This repository is intentionally small. The whole tool is one Bash script
(`bin/dvm`), one Lima YAML template, and a handful of shell recipes. Prefer
docs or recipes over `bin/dvm` changes unless the core change is clearly
justified.

After every change:

- Update `README.md` when commands, config, recipes, or workflows change.
- Add a `CHANGELOG.md` entry under `Unreleased` for every user-visible
  change. State explicitly if a change is internal-only.
- Run `bash tests/smoke.sh` and confirm it passes.

Do not edit unrelated files or planning drafts.
