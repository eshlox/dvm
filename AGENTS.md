# Agent Instructions

This repository is intentionally small and audit-friendly. Keep changes focused and
prefer docs or recipes over core behavior unless the core change is clearly justified.

After every change:

- Update user-facing docs when behavior, commands, config, recipes, workflows, or setup
  examples change.
- Update `CHANGELOG.md` under `Unreleased` for every user-visible change. If a change is
  internal-only, make that explicit in the final summary.
- Run `bash scripts/check.sh` before handing work back when possible.

Do not edit unrelated files or generated local notes. In particular, leave unrelated
draft docs alone unless the user asks for them.
