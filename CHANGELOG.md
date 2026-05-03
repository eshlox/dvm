# Changelog

## Unreleased

- Added the minimal Bash/Lima wrapper.
- Added the small `dvm` shell wrapper: `apply`, `apply --all`, `enter`, `ssh`,
  `logs`, `ssh-key`, `gpg-key`, `list`, `stop`, and `rm`.
- Added `dvm init <name> [template]` to create a VM config from a bundled example and
  open it in the user's editor.
- Changed `install.sh` to install a snapshotting launcher instead of a direct symlink,
  preventing long-running applies from reading a half-edited wrapper while the repo is
  being updated.
- Added `dvm stop <name>`.
- Fixed `dvm rm` to stop a VM after the dirty check before deleting it.
- Added existing-VM Lima port-forward updates during `dvm apply`.
- Fixed `dvm apply` to continue when Lima's existence check is stale and
  `limactl create` reports that the instance already exists.
- Changed `dvm list` to display public VM names without the internal `dvm-` Lima
  prefix and normalized accidental `dvm-` prefixes in command arguments.
- Fixed `dvm list` column alignment after stripping the internal Lima prefix.
- Fixed `dvm enter` on host terminals whose terminfo name is missing in the guest, such
  as Ghostty's `xterm-ghostty`.
- Fixed `dvm enter` to export the selected guest login shell as `SHELL`, and changed the
  `zsh` recipe to set the login shell with `usermod --shell`.
- Fixed guest-side `~` expansion so `DVM_CODE_DIR="~/code/app"` enters
  `/home/<user>/code/app` instead of creating `/home/<user>/~/code/app`.
- Changed `dvm apply` to set the guest hostname to the public VM name, while keeping the
  internal Lima name prefixed with `dvm-`.
- Added an `apply` recipe summary line so host-side helper expansion is visible.
- Added smoke coverage and docs for global host-side app tool bundles such as
  `use_app_tools`.
- Added nested Git dirty checks before `dvm rm`; `--force` skips the check.
- Added VM-local SSH and GPG key helpers.
- Added bundled defaults under `share/dvm`: global config, Lima template, example VM
  configs, and reusable guest recipes.
- Added first-pass recipes for setup basics, `dvm-agent`, Codex, Claude, OpenCode,
  Mistral, HTTPS chezmoi dotfiles, llama, cloudflared, Node, Python, zsh, Git, Helix,
  lazygit, Starship, fzf, Delta, just, tmux, and Yazi.
- Documented how to define local host-side recipe helper functions without adding a
  default personal tool bundle.
- Added sha256-verified pinned upstream fallbacks for lazygit, Starship, and Yazi when
  they are not available from Fedora repositories.
- Added a small internal recipe helper prelude for verified upstream downloads.
- Changed `dvm enter` to open the guest user's configured login shell instead of
  trusting `$SHELL`.
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
- Changed `agent-user` to create `dvm-agent` as a system account to avoid Fedora
  subordinate UID allocation failures.
- Changed AI wrappers to require Bubblewrap sandboxing: AI tools run as `dvm-agent`
  with project code mounted at `/workspace`, agent home mounted read/write, and the main
  user home omitted from the sandbox.
- Changed the Node recipe to install standalone Corepack from npm and enable Corepack
  shims when Fedora's Node package does not provide `corepack`.
- Added generic `DVM_CHEZMOI_CONFIG_TOML` support for dotfiles that need chezmoi
  template data.
- Changed `install.sh --init` to leave VM examples in `share/dvm/vms` instead of
  copying inactive examples into `~/.config/dvm`.
- Changed `install.sh --init` to leave bundled recipes in `share/dvm/recipes` instead
  of copying stale recipe overrides into `~/.config/dvm/recipes`.
- Changed `install.sh --init` to use the bundled `share/dvm/lima.yaml.in` by default
  instead of copying a local Lima template.
- Documented how to add DNF and non-DNF tools globally or per VM.
- Added explicit docs for creating app, llama, and cloudflared VMs from repo examples.
- Documented that the bundled llama VM opens port 8080 for host and VM-to-VM access.
- Removed `docs/plan.md` so implemented behavior lives only in maintained user docs.
- Set bundled llama and cloudflared service VM examples to skip the setup baseline.
- Removed an unused Lima template param that current Lima rejects during VM creation.
- Removed Lima `param` usage from the template because current Lima rejects values that
  are only consumed through shell provision environment variables.
- Fixed Lima template temp-file creation on macOS.
- Hardened Lima user provision so empty or host-looking `/Users/...` code directories
  do not fail cloud-init.
- Updated install, checks, smoke tests, CI, README, and docs for the Bash-only
  implementation.
- Added focused docs for commands, config, Lima, AI, services, dotfiles, and
  security standards.
