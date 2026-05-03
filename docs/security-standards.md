# Security Standards

These are the operating rules for DVM. They are short because the implementation is
small, but they are the bar for changes.

## Isolation

- One project gets one VM.
- Host project directories are not mounted into guests.
- Code lives in the VM and is cloned from Git or created there.
- `~` in DVM config means guest home, never host home.
- Recreate by deleting the VM and applying recipes again.

## Secrets

- Do not put secrets in DVM config, public dotfiles, recipes, or project setup scripts.
- Do not copy host SSH/GPG private keys into VMs.
- Generate VM-local keys when a VM needs Git or signing access:
  `dvm ssh-key <name>` and `dvm gpg-key <name>`.
- The VM-local GPG helper creates an unencrypted, one-year signing key for disposable
  VM use; do not treat it as a long-lived identity key.
- Prefer repo-scoped deploy keys and service-scoped tokens.
- Pass Cloudflare tokens only when applying the cloudflared VM, or fetch them from
  macOS Keychain in your shell before apply.
- Apply-time environment values are visible to host process listings while `limactl`
  runs; use them for short-lived setup tokens only.

## AI

- Run hosted AI tools through `dvm-agent`.
- Grant AI tools access to project code, the agent home, and agent scratch only.
- Treat ACLs as guardrails, not a sandbox. The recipe denies common secret paths
  (`.ssh`, `.gnupg`, token files, shell histories, and common tool config), but it does
  not make every known path in the main user's home unreadable.
- Review AI-generated changes before committing or running them.

## Networking

- Bind forwarded ports to `127.0.0.1` by default.
- Use `0.0.0.0` only when you intentionally want LAN exposure.
- Re-run `dvm apply <name>` after editing `DVM_PORTS`; DVM updates existing Lima port
  forwards without recreating the VM.
- Put shared services such as llama and cloudflared in dedicated VMs.
- Use Lima internal names for VM-to-VM traffic.

## Deletion

- `dvm rm <name> --yes` checks nested Git repos under `DVM_CODE_DIR` before deleting.
- Use `--force` only when you have intentionally accepted losing uncommitted VM-local
  work.

## Recipes

- Recipes must be readable shell.
- Recipes must be safe to rerun.
- Recipes must not read host paths.
- Recipes should install one concept and avoid hidden dependency systems.
- Remote downloads should come from package managers or pinned URLs with checksums
  when practical.

## Host

- Keep the host dependency set small: Lima, Bash, DVM config.
- Install DVM from a reviewed checkout or signed release.
- Run `bash scripts/check.sh` before committing changes.
