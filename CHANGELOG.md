# Changelog

## Unreleased

- Fixed `dvm sync` on Bash versions that treat empty arrays as unset under
  nounset when a VM inherits default packages or recipes without defining its
  own list.
- `dvm_ensure_user` and the `agent-user` recipe now create guest users without
  allocating subordinate UID/GID ranges, avoiding sync failures on templates
  where no subordinate ID range is available.
- Shortened the README and docs around task-first workflows, and removed
  low-value code comments while keeping ShellCheck directives and non-obvious
  safety metadata.
- Normalized document headings to sentence case.
- Hardened project hooks: `.dvm/sync.sh` is now disabled by default,
  `DVM_PROJECT_HOOK=1` enables hooks as `DVM_USER`, and
  `DVM_PROJECT_HOOK_PRIVILEGED=1` is required for provisioning-privileged
  hooks with dry-run warning visibility. `DVM_PROJECT_HOOK_GIT_CONFIG=1`
  requires repo-local `git config dvm.hook true` before hooks run.
- Staged secrets now use randomized root-owned `/run/dvm-secrets` paths with
  guest-side cleanup traps and host-side cleanup, and service recipes now use
  `dvm_secret`/`dvm_has_secret` instead of predictable `/tmp` paths.
- Built-in npm recipes now install exact package versions under a user-owned
  npm prefix instead of root-global npm: Codex `0.132.0`, Claude Code
  `2.1.146`, and opencode `1.15.6`.
- Removed live `curl | sh` installers from built-in recipes. `ollama` and
  `mistral` now fail closed unless a pinned HTTPS URL and SHA-256 checksum are
  supplied, and `dvm_download_verified` rejects non-HTTPS URLs.
- Tightened `agent-user`: `dvm-agent` fails closed when Bubblewrap is missing
  unless `DVM_AGENT_ALLOW_UNSANDBOXED=1` is set, uses Bubblewrap's minimal
  `--dev /dev`, validates sudoers with `visudo`, and is documented as a
  guardrail.
- The Docker recipe no longer adds `DVM_AGENT_USER` to the Docker group unless
  `DVM_DOCKER_AGENT_ACCESS=1` is set, and recipe conflict metadata now rejects
  `docker` plus `agent-user` by default.
- Added recipe alias canonicalization, recipe de-duplication, and
  `DVM_ALLOW_RECIPE_CONFLICTS` for reviewed conflict overrides.
- DVM now rejects unsafe config and user recipe permissions before sourcing or
  including them, and blocks dangerous `DVM_ENV` names such as `PATH`,
  `BASH_ENV`, `LD_*`, and `GIT_*`.
- `dvm base build` and `dvm base rm` now use the base lock, and sync refuses to
  clone a missing VM from a base while that base is locked.
- `dvm edit` now validates VM names; `dvm rm` warns when a VM config remains
  and supports `--config`; `dvm ls` and `dvm stop --all` support
  `--only-config`; and `dvm doctor --probe <vm>` checks VM reachability.
- `dvm new` now writes a conservative starter recipe set, leaving AI/npm tools
  as commented examples, and primary docs now recommend creating VM-local SSH
  keys before manually cloning private repos instead of using automatic
  first-clone config on new private VMs.
- Tailscale now uses `--auth-key=file:<path>` and package `gpgcheck=1`.
- The `gpg-keys` recipe now configures Git signing repo-locally when a project
  repo exists instead of setting global Git signing.
- `scripts/check` and CI now ShellCheck the guest prelude and built-in recipes
  as Bash, fail on warnings/errors instead of intentional info notes, and CI
  now runs on `ubuntu-24.04` through the same local check entrypoint.
- Added [docs/threat-model.md](docs/threat-model.md) and
  [docs/release.md](docs/release.md) for the explicit threat model and signed
  release/checksum process.
- Added `security-plan.md` with strict security review findings and the
  hardening backlog for privileged hooks, recipe supply chain, agent isolation,
  secret staging, config permissions, base locking, environment passthrough,
  recipe ordering, release process, and validation gaps.
- DVM now ensures `DVM_USER` exists in the guest before staging secrets or
  creating the project directory.
- Added `DVM_ENV` for explicit non-secret variable passthrough into guest
  recipes, and automatically pass built-in recipe settings such as
  `DVM_CHEZMOI_REPO` and `DVM_TAILSCALE_HOSTNAME`.
- Staged secret files are now removed before optional project clone and
  `$DVM_CODE_DIR/.dvm/sync.sh` hooks run.
- Tailscale and Cloudflared recipes now fail the sync when a staged auth secret
  is used but service authentication fails.
- Commands that contact Lima now fail clearly when `limactl` is missing instead
  of treating the instance list as empty.
- `dvm sh` and `dvm ssh` now run as `DVM_USER` and prefer the project directory,
  making the normal in-VM AI workflow use the same user state as development.
- Added `dvm-agent-shell` for an interactive guardrail agent environment and
  documented trusted-dev AI mode for running AI tools directly as `DVM_USER`
  inside project VMs with scoped keys.
- Added `dvm version` for scripts and agent tooling.
- Updated the Docker recipe to use the guarded `dvm_pkg` helper and removed
  redundant project-directory creation from the `agent-user` recipe.
- Documented guest recipe helpers in `AGENTS.md` and clarified that generated
  GPG keys are empty-passphrase, VM-local convenience keys.
- Added `scripts/check` as a local development entrypoint for smoke tests and
  optional ShellCheck.
- Removed Ansible from the default architecture. DVM is again a small Bash
  wrapper around Lima plus repo-owned Bash recipes.
- `dvm sync <vm>` now starts or clones the Lima VM, stages optional secrets,
  installs `DVM_PACKAGES`, runs `DVM_RECIPES`, optionally clones
  `DVM_GIT_REPO`, and then runs the guest project hook
  `$DVM_CODE_DIR/.dvm/sync.sh` when present.
- Added built-in recipes for common VM tools and services: `age`,
  `agent-user`, `bat`, `chezmoi`, `claude`, `cloudflared`, `codex`,
  `delta`, `docker`, `fzf`, `gpg-keys`, `helix`, `just`, `lazygit`,
  `mistral`, `node`, `ollama`, `opencode`, `python`, `sops`, `ssh-keys`,
  `starship`, `tailscale`, `yazi`, `zellij`, and `zsh`.
- Added recipe aliases: `ai-user` and `ai-agent` for `agent-user`,
  `cloudflare` and `cloudflare-tunnel` for `cloudflared`, plus singular
  `ssh-key` and `gpg-key` aliases.
- Added optional `DVM_GIT_REPO` and `DVM_GIT_BRANCH` per-VM settings for a
  first clone into `/home/<DVM_USER>/code/<DVM_NAME>`.
- Kept Lima simplifications from the previous plan: `limactl start` flags,
  `template:fedora`, optional `limactl clone` base VM reuse, and `mkdir`
  locks. DVM no longer renders Lima YAML.
- DVM now passes `--mount-none` when creating/cloning instances so Lima does
  not mount the host home by default.
- Removed the old `DVM_HOST_IP` idea. DVM uses Lima's documented
  `--port-forward host:guest` CLI shape; use Tailscale, Cloudflare Tunnel, or
  direct Lima networking for team access.
- `dvm rm <vm> --yes` no longer needs the VM config file to exist.
- Made stateful service/key recipes more idempotent: Tailscale and
  Cloudflared skip already-authenticated/installed services, Chezmoi init
  runs once, and SSH/GPG public keys print only when created.
- Validated `DVM_USER`, `DVM_AGENT_USER`, and `DVM_BASE_NAME` before they are
  used in generated guest scripts or sudoers snippets.
- Expanded `dvm doctor` to check `$VISUAL`/`$EDITOR`, Git, and Lima 2.0+
  instead of only printing the Lima version.
- Added `DVM_DRY_RUN=1 dvm base build`, recipe alias output, and clearer
  `dvm rm` output when the Lima instance is missing.
- Added [docs/errors-and-recovery.md](docs/errors-and-recovery.md) for stale
  locks, partial syncs, dry-run, and re-running failed recipes.
- Added [docs/future-development.md](docs/future-development.md) with the
  safety roadmap: network policy, secret broker, ephemeral agent mode, session
  logs, trust tiers, and stricter service exposure.
- Narrowed guest support to Lima's latest Fedora template with `dnf5` only,
  removing the unused `dnf`/`apt` package-manager compatibility branches.
- Removed user-facing Ansible docs and examples. Documentation now describes
  packages, recipes, service sharing, secrets, and project hooks.

## v2

- Single Bash program (`bin/dvm`) replaced the original Bash launcher plus
  `share/dvm/lib` helper tree.
- Config moved to plain Bash sourced from `~/.config/dvm/config.sh` and
  `~/.config/dvm/vms/<name>.sh`.
- Introduced package, recipe, and secret nouns: `DVM_PACKAGES`,
  `DVM_RECIPES`, and `DVM_SECRETS`.
