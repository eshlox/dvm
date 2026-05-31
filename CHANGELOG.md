# Changelog

## Unreleased

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
