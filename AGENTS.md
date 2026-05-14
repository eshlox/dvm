# Agent Instructions

This repository is intentionally small. DVM is one Bash script (`bin/dvm`)
that drives `limactl` and `ansible-playbook`. Guest configuration belongs in
the user's external Ansible repo, not here.

After every change:

- Update `README.md` when commands, config, or workflows change.
- Add a `CHANGELOG.md` entry under the current unreleased section for every
  user-visible change. State explicitly if a change is internal-only.
- Run `bash tests/smoke.sh` and confirm it passes.

Do not edit unrelated files or planning drafts.
