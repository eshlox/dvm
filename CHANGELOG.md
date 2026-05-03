# Changelog

## Unreleased

- Added the minimal Bash/Lima wrapper.
- Added the small `dvm` shell wrapper: `apply`, `apply --all`, `enter`, `ssh`,
  `logs`, `ssh-key`, `gpg-key`, `list`, and `rm`.
- Added existing-VM Lima port-forward updates during `dvm apply`.
- Added nested Git dirty checks before `dvm rm`; `--force` skips the check.
- Added VM-local SSH and GPG key helpers.
- Added bundled defaults under `share/dvm`: global config, Lima template, example VM
  configs, and reusable guest recipes.
- Added first-pass recipes for baseline tools, `dvm-agent`, Codex, Claude, OpenCode,
  Mistral, HTTPS chezmoi dotfiles, llama, cloudflared, Node, and Python.
- Expanded llama and cloudflared recipes with service options, model aliases/checksums,
  token-file handling, and default log units.
- Fixed config isolation for `dvm apply --all` and forwarded recipe variables
  generically instead of hardcoding each `DVM_*` variable.
- Changed `dvm logs` to use `sudo journalctl` inside the VM.
- Moved Node/Python out of `baseline` and into their explicit recipes.
- Fixed the Mistral recipe's `mistral` wrapper target and updated the Claude recipe to
  the current signed RPM repository.
- Hardened cloudflared token-log checking and expanded the `dvm-agent` ACL deny list.
- Updated install, checks, smoke tests, CI, README, and docs for the Bash-only
  implementation.
- Added focused docs for commands, config, Lima, AI, services, dotfiles, and
  security standards.
