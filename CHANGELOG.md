# Changelog

## v3 (unreleased)

Greenfield rewrite. No migration path from v2. DVM is now a tiny Lima +
Ansible conductor; guest configuration moves entirely into the user's
external Ansible repo.

- New `bin/dvm` (single Bash file) drives Lima with `limactl start` flags
  (`--name`, `--cpus`, `--memory`, `--disk`, `--port-forward`) and a
  template (default `template:fedora`). No more YAML rendering, no
  `envsubst`, no `flock`.
- New three-noun config: `DVM_TEMPLATE`, resource flags, and
  `DVM_ANSIBLE_*` (repo, playbook, tags, extra-vars, extra-args).
  `DVM_PACKAGES`, `DVM_RECIPES`, `DVM_SECRETS` are gone.
- `dvm sync <vm>` writes a non-secret `~/.cache/dvm/<vm>.vars.yml`
  (containing `dvm_name`, `dvm_lima_name`, `dvm_user`, `dvm_code_dir`,
  `dvm_host_ip`, `dvm_ports`) and runs `ansible-playbook` against Lima's
  generated `ansible-inventory.yaml`.
- `DVM_ANSIBLE_EXTRA_VARS` entries are rejected if their name looks like
  a secret (`token`, `password`, `secret`, or `key=…`). DVM no longer
  stages secrets — Ansible Vault and env lookups belong in the playbook.
- New commands: `dvm base build`, `dvm base rm` (optional reusable base
  VM cloned via `limactl clone`); `dvm ansible <vm> -- args…` (extra args
  forwarded to `ansible-playbook`); `dvm doctor` (diagnostic check of
  Lima, Ansible, repo, playbook, inventory).
- Removed commands: `dvm ssh-key`, `dvm gpg-key`, `dvm recipes`. Identity
  belongs to the Ansible `keys` role; the recipe engine no longer exists.
- Removed: `share/dvm/lima.yaml.in`, `share/dvm/prelude.sh`,
  `share/dvm/recipes/*`. `docs/recipes.md`, `docs/ai.md`,
  `docs/services.md`, `docs/dotfiles.md`. Key backup/restore on `dvm rm`.
- Added: `docs/ansible.md` (external repo contract);
  `docs/ansible/examples/{base,agent_user,chezmoi,keys,codex,claude,tailscale,cloudflared,llama}.yml`
  as reference roles.
- Locking switched from `flock` to atomic `mkdir` with `trap` cleanup.
- Host dependencies: `bash`, `lima` 2.0+, `ansible-playbook`, `git`,
  `$EDITOR`. No more `envsubst`, `flock`, or `jq`.

## v2

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
