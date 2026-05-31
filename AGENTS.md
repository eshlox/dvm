# Agent instructions

This repository is intentionally small and audit-friendly. DVM is a Bash + Lima
wrapper that runs trusted user-owned setup scripts. Keep core behavior focused;
prefer docs and examples over adding framework code unless the core change is
clearly justified.

Docs layout: top-level `README.md` is a short entry point that links to the
website. The documentation lives in the Astro + Starlight site under
`site/src/content/docs/docs/` (one topic per file: `reference/` for
commands/config/lima, `guides/` for security/troubleshooting, `examples/` for
setup snippets, `getting-started/` for install/quickstart). Published at
dvm.eshlox.net. `docs/release.md` stays in-repo as a maintainer process note.
Keep each fact in one place and link to it. When editing docs, update the files
under `site/` and use absolute `/docs/...` links between pages.

After every change:

- Update user-facing docs when behavior, commands, config, workflows, security
  guidance, or setup examples change.
- Update `CHANGELOG.md` under `Unreleased` for every user-visible change. If a
  change is internal-only, make that explicit in the final summary.
- Run `bash tests/smoke.sh` before handing work back when possible.

Do not edit unrelated files or generated local notes. In particular, leave
unrelated draft docs alone unless the user asks for them.

Package installation, tool setup, secrets, keys, services, and project cloning
belong in user-owned setup scripts and docs examples, not runtime framework
code.
