# Changelog

## Unreleased

- Added `dvm doctor [name]` for host and VM configuration checks.
- Added `dvm status <name>` for a single-VM summary.
- Added `dvm logs <name> [unit]` as a journalctl shortcut for VM services.
- Added `DVM_HOST_IP` for choosing the host bind address for forwarded ports.
- Added optional `DVM_LLAMA_MODELS_SHA256` checksum verification for llama models.
- Split the hosted AI recipe into smaller internal helpers and replaced generated AI
  wrapper logic with a fixed guest runner plus per-tool config files.
- Added a shared recipe helper prelude for validation, logging, quoting, and checksums.
- Added `dvm_recipe_record_ssh_host` for non-interactive SSH clone setup in recipes.
- Hardened chezmoi dotfiles docs so setup can recover from a failed first clone that
  left `~/.local/share/chezmoi` without a Git repository.
- Switched public dotfiles examples to HTTPS clone URLs and documented SSH clone setup
  only for private repositories.
- Added `scripts/release.sh` to promote changelog entries, create a release commit,
  tag the release, and optionally push both for CI-driven releases.
- Added repository agent/contributor guidance requiring docs and changelog updates for
  user-facing changes.
