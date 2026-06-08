# Changelog

## Unreleased

- Added `dvm base`, a base-image workflow that bakes your tooling once so every
  `dvm sync` boots a ready VM instead of re-provisioning Fedora from scratch.
  `dvm base init` scaffolds `~/.config/dvm/base/Containerfile` (your tools,
  `FROM dvm-base`); `dvm base build` builds it into a qcow2 inside a throwaway
  Lima builder VM (`dvm-builder`) using Podman and bootc-image-builder, so the
  host stays Lima-only; `dvm base status` and `dvm base rm` manage the image and
  builder. When a base image exists, `dvm sync` boots from it; otherwise it
  falls back to `template:fedora` and the per-VM setup script. DVM owns a
  generated `dvm-base` plumbing layer (zram, the rootless-docker unit, binfmt
  mask); the developer user, SSH keys, and dotfiles are still created per VM at
  sync time. See the base image reference. The `dvm-builder` instance is hidden
  from `dvm ls` and `dvm stop --all`.
- Added `DVM_VM_TYPE`, passed through as `limactl start --vm-type`. Set `vz` on
  Apple Silicon for lighter overhead and friendlier host memory reclaim when
  running many VMs at once. Empty by default (Lima picks QEMU).
- Base-image hardening: the generated Lima template normalizes the host arch to
  Lima's canonical form (`arm64`/`amd64` to `aarch64`/`x86_64`) so base-image
  sync works on Apple Silicon; `base` and the builder instance name are reserved
  so VM commands cannot operate on the build infrastructure; `dvm base rm
  --image` removes the configured image by exact path (honoring a custom
  `DVM_BASE_IMAGE`) instead of clearing the cache dir; and a `sync` warning fires
  when a now-unused `~/.config/dvm/setup.sh` is still present. The upstream
  `DVM_BOOTC_BASE` and `DVM_BISC_IMAGE` images are pinned by digest in `bin/dvm`
  (dvm-owned, bumped on release, like the binary SHA256 pins), closing a
  supply-chain gap on the privileged image-builder; override only for a custom
  base. A weekly `Update pins` workflow runs `scripts/update-pins` and opens a
  pull request when a tracked digest changes, so the pins stay current.
- Bumped the version to `3.0.0-dev`.
- Config now inherits cleanly: `dvm new` writes a per-VM `config.sh` whose
  resource settings are commented out, so VMs inherit defaults and global
  config instead of each pinning its own copy. Set a value once globally and
  every VM follows it.
- `dvm new` scaffolds `~/.config/dvm/config.sh` (with `DVM_USER` and the
  resource defaults) the first time it runs, giving global settings one home.
- Removed the global setup script. Shared, identical-on-every-VM provisioning
  now belongs in the base image Containerfile (`dvm base init`), baked once
  instead of re-run on every sync. `~/.config/dvm/setup.sh` is no longer read,
  and the `DVM_GLOBAL_SETUP` config variable is gone. The per-VM
  `~/.config/dvm/vms/<vm>/setup.sh` still runs for VM-specific, stateful steps.
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
- Reframed the docs examples for the base image: shared tooling (packages,
  upstream binaries, AI CLIs) is now shown as Containerfile layers, and the
  examples index splits snippets into "base image (Containerfile)" and "per-VM
  (setup.sh)". Versions and checksums in the binary recipes are examples you pin
  and update yourself; DVM does not track them.
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
