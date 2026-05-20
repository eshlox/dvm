# Changelog

## Unreleased

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
- Added `dvm-agent-shell` for an interactive restricted agent environment and
  documented trusted-dev AI mode for running AI tools directly as `DVM_USER`
  inside project VMs with scoped keys.
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
