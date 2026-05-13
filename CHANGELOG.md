# Changelog

## v2 (unreleased)

Greenfield rewrite. No migration path from v1.

- Single Bash program (`bin/dvm`) replaces v1's Bash launcher + `share/dvm/lib`
  helper tree. Symlink install (`install.sh` writes one symlink and exits);
  `git pull` is the update mechanism.
- Config is plain Bash sourced from `~/.config/dvm/config.sh` (global) and
  `~/.config/dvm/vms/<name>.sh` (per VM). No TOML, no parser, no validator
  framework — invalid config raises a Bash error on the next `dvm sync`.
- Three nouns: `DVM_PACKAGES` (distro package names), `DVM_RECIPES` (shell
  behavior files in declared order, no `requires` / topo sort), `DVM_SECRETS`
  (env-var names staged through stdin into `/tmp/dvm-secret-<NAME>`).
- Lima YAML rendered from one `envsubst` template (`share/dvm/lima.yaml.in`).
  Lima `vmType` and `arch` are auto-detected. First-boot baseline (packages,
  sudoers, user, code_dir) lives in the Lima `provision` block; idempotent
  per-sync work lives in the guest prelude.
- New built-in recipes: `lazygit`, `starship`, `zellij`, `yazi` (pinned binary
  installs with sha256 verification), `zsh-login-shell`, `node-corepack`.
  Removed: per-recipe one-line installs (now `DVM_PACKAGES` entries).
- Commands kept: `sync` (`--all`), `sh`, `ssh`, `cp`, `log`, `ls` (optional
  VM filter replaces v1 `status`), `rm`, `stop` (`--all`), `ssh-key`,
  `gpg-key`, `new`, `edit`, `config edit|show`, `recipes`.
- Commands dropped: `dvm stop --inactive`, dirty git-check on `dvm rm`,
  per-port host IP overrides (the 3-part `host:port:guest` syntax — bind IP
  is global `DVM_HOST_IP` only), `DVM_NO_BASELINE` flag.

### Post-review fixes

- Fixed: `dvm` launched through an absolute-target symlink (the default
  install path) prefixed the link's directory to the absolute target and
  failed at startup. Symlink resolution now handles absolute and relative
  targets separately.
- Fixed: the project hook check (`<DVM_CODE_DIR>/.dvm/sync.sh`) was run on
  the host, never the guest, so the hook never executed. The check is now
  emitted verbatim into the guest script.
- Hardened: `DVM_SECRETS` entries must match `[A-Za-z_][A-Za-z0-9_]*`
  before indirect expansion or use in the staged filename.
- Hardened: `dvm cp` requires the VM side to match a real VM-name pattern
  before treating a path as `vm:path`, so local paths containing `:` are
  not misparsed. Cross-VM copies are rejected explicitly.
- Improved: `dvm stop --all` aggregates per-VM failures and exits non-zero
  when any stop failed.
- Moved: the guest helper prelude now lives in `share/dvm/prelude.sh` and
  is `cat`-ed at sync time. `bin/dvm` shrinks from 477 to 410 LOC; the
  prelude is easier to read and shellcheck independently.
- Improved: `envsubst` and `flock` are checked only inside the commands
  that need them (`sync`, `rm`), so `help`, `recipes`, `ls`, `config show`,
  and `config edit` work without them on `PATH`.
- Added: `dvm rm <vm> --yes` backs up the VM's `id_ed25519_dvm*` SSH keys
  and GPG signing key (armored) to `~/.config/dvm/backups/<vm>/` before
  deleting. `dvm sync <vm>` restores them when the in-VM file is missing,
  so recreated VMs keep the same identity without re-adding keys to the
  Git host. Pass `--no-backup` to skip. Trust model: keys now live on the
  host disk (mode `0600`); document discusses the implications.
- Fixed shellcheck warnings SC2088/2015/2089/2090 with intent-documenting
  inline disables and one `if`/`then` rewrite.
