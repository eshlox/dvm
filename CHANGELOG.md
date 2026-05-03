# Changelog

## Unreleased

- Added the minimal Bash/Lima wrapper.
- Added the small `dvm` shell wrapper: `apply`, `apply --all`, `enter`, `ssh`,
  `logs`, `ssh-key`, `gpg-key`, `list`, `stop`, and `rm`.
- Added `dvm stop <name>`.
- Fixed `dvm rm` to stop a VM after the dirty check before deleting it.
- Added existing-VM Lima port-forward updates during `dvm apply`.
- Added nested Git dirty checks before `dvm rm`; `--force` skips the check.
- Added VM-local SSH and GPG key helpers.
- Added bundled defaults under `share/dvm`: global config, Lima template, example VM
  configs, and reusable guest recipes.
- Added first-pass recipes for setup basics, `dvm-agent`, Codex, Claude, OpenCode,
  Mistral, HTTPS chezmoi dotfiles, llama, cloudflared, Node, and Python.
- Expanded llama and cloudflared recipes with service options, model aliases/checksums,
  token-file handling, and default log units.
- Fixed config isolation for `dvm apply --all` and forwarded recipe variables
  generically instead of hardcoding each `DVM_*` variable.
- Changed `dvm logs` to use `sudo journalctl` inside the VM.
- Moved Node/Python out of `baseline` and into their explicit recipes.
- Reduced `baseline` to required setup basics only; editors, shells, terminal tools,
  Git UIs, and language runtimes are user-selected recipes.
- Fixed the Mistral recipe's `mistral` wrapper target and updated the Claude recipe to
  the current signed RPM repository.
- Hardened cloudflared token-log checking and expanded the `dvm-agent` ACL deny list.
- Changed `install.sh --init` to leave VM examples in `share/dvm/vms` instead of
  copying inactive examples into `~/.config/dvm`.
- Changed `install.sh --init` to use the bundled `share/dvm/lima.yaml.in` by default
  instead of copying a local Lima template.
- Documented how to add DNF and non-DNF tools globally or per VM.
- Added explicit docs for creating app, llama, and cloudflared VMs from repo examples.
- Documented that the bundled llama VM opens port 8080 for host and VM-to-VM access.
- Set bundled llama and cloudflared service VM examples to skip the setup baseline.
- Removed an unused Lima template param that current Lima rejects during VM creation.
- Removed Lima `param` usage from the template because current Lima rejects values that
  are only consumed through shell provision environment variables.
- Fixed Lima template temp-file creation on macOS.
- Updated install, checks, smoke tests, CI, README, and docs for the Bash-only
  implementation.
- Added focused docs for commands, config, Lima, AI, services, dotfiles, and
  security standards.
