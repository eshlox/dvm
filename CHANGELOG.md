# Changelog

## Unreleased

- Config now inherits cleanly: `dvm new` writes a per-VM `config.sh` whose
  resource settings are commented out, so VMs inherit defaults and global
  config instead of each pinning its own copy. Set a value once globally and
  every VM follows it.
- `dvm new` scaffolds `~/.config/dvm/config.sh` (with `DVM_USER` and the
  resource defaults) the first time it runs, giving global settings one home.
- The global setup script is now convention-based at `~/.config/dvm/setup.sh`,
  matching the per-VM `setup.sh`. The `DVM_GLOBAL_SETUP` config variable is
  removed; create the file to enable the script, remove it to disable it.
- `DVM_CPUS` now defaults to the host CPU count minus a small reserve (1 core on
  hosts up to 4 cores, 2 beyond, floored at 2) instead of a fixed `2`. vCPUs are
  a time-shared ceiling, not pinned, so this lets a single busy VM use most of
  the host while idle VMs still cost nothing; the reserve keeps the host and
  `dvm`/`limactl` responsive under load. Pin `DVM_CPUS` globally or per VM to
  override. Existing VMs are unaffected; the value applies to VMs created after.
- Lowered the default `DVM_MEMORY` to `2` GiB. Defaults are now an auto-detected
  CPU count, 2 GiB memory, and a 30 GiB (thin-provisioned) disk: minimal but
  enough to run an editor, shell, AI CLIs, and a dev server in a disposable VM
  at once.
- `dvm sync` now creates the Lima instance with `limactl start --yes`, so the
  first sync no longer stops at Lima's interactive proceed/edit/exit prompt.
- `dvm sync` now shows a per-step spinner with `✓`/`✗` and captures the full
  output of Lima and setup scripts to per-VM logs under
  `${XDG_STATE_HOME:-~/.local/state}/dvm/<vm>/` (`lima.log`, `setup.log`)
  instead of printing it. On failure it reports the failing step, the log path,
  and the log's last lines. `DVM_VERBOSE=1` streams everything live; color and
  the spinner are disabled when stderr is not a terminal or `NO_COLOR` is set.
  Logs are configurable with `DVM_STATE_DIR`.
- Added a documentation website (Astro + Starlight) under `site/`, published at
  dvm.eshlox.net, with a landing page and the docs moved from `docs/` and
  `examples/`. The repo `README` now links to the site.
- Initial development version of DVM as a minimal Bash wrapper around Lima.
- Added VM lifecycle commands for sync, shell, command execution, copy, list,
  stop, remove, and starter config generation.
- Added global and conventional per-VM setup scripts with ownership and
  permission checks.
- Hardcoded Lima's Fedora template as the only supported guest template.
- `dvm sh` now opens `DVM_USER`'s configured login shell instead of forcing
  Bash.
- `dvm cp` now runs guest file reads/writes as `DVM_USER` and resolves relative
  VM paths under the VM project directory.
- Added `DVM_SUBUID_COUNT` and `DVM_SUBGID_COUNT` so VM users can be provisioned
  with subordinate id ranges required by rootless Docker and Podman. Both now
  default to `65536`.
- Added documentation for secure setup scripts, package installation, AI tools,
  verified downloads, VM-local keys, Docker risk, and Lima behavior.
- Updated VM-local SSH key examples to use VM-specific key comments such as
  `<vm-name>-dvm-git-deploy`.
- Updated rootless Docker examples to use Fedora package names available in
  Fedora 43.
- Removed redundant subordinate id settings from quick config examples and
  documented how to run rootless Docker and Podman.
- Documented Fedora with `dnf5` as the supported guest setup path.
- Restructured docs: trimmed README, merged the security guide and threat model
  into `docs/security.md`, renamed `errors-and-recovery.md` to
  `troubleshooting.md`, folded the roadmap into `CONTRIBUTING.md`, and split
  setup examples into one file per topic under `examples/`.
