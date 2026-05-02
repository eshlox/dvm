# Extending DVM

DVM should stay a small Lima helper. New features should usually be documentation or a
recipe, not a core command.

## Decision Rules

Use documentation only when:

- the workflow is mostly commands the user can paste and modify
- the setup is specific to one language, framework, company, or project
- the feature needs secrets or account login
- the safe defaults are unclear
- the implementation would mostly wrap another CLI

Add a user recipe when:

- only one user/project needs it
- it installs project-specific packages
- it configures one VM in a way that is not generally useful

Add a built-in recipe when:

- the workflow is common for DVM users
- it can be implemented as one small Bash file
- it runs entirely inside the VM
- it is idempotent when `dvm setup <name>` runs again
- it does not require secrets in the repository
- it has clear security boundaries

Add a DVM config default when:

- the value affects core VM behavior
- most VMs should share the same default
- the default is safe when uncommented or left alone

Avoid adding defaults for tool-specific options unless a built-in recipe needs them.
Recipe-specific variables should be optional and read by that recipe, for example
`DVM_LLAMA_PORT` or `DVM_CLOUDFLARED_SERVICE`.

Add a core command only when:

- it manages VM lifecycle, setup, listing, keys, or deletion
- it cannot be expressed clearly as `dvm ssh <name> ...`
- it must coordinate host state with Lima state
- it is small enough to audit

## Recipe Rules

Recipes live in `recipes/` and are run inside the VM by `dvm setup`.
DVM prepends `recipes/_lib.sh` before each setup script, so built-in and user recipes
can use the `dvm_recipe_*` helper functions without copying boilerplate.

Good recipe shape:

```bash
#!/usr/bin/env bash
set -euo pipefail

port="${DVM_EXAMPLE_PORT:-8080}"

sudo dnf5 install -y example-package
```

Rules:

- use Bash with `set -euo pipefail`
- use `dnf5`, not `dnf`
- validate user-controlled values before writing system files
- make reruns safe
- keep credentials out of the recipe and docs examples
- prefer systemd services only for long-running daemons
- document every `DVM_*` variable the recipe reads
- use `dvm_recipe_die`, `dvm_recipe_warn`, and validation helpers when they fit

Do not use `curl | sh`. If a third-party install requires that pattern, document the
manual setup instead of shipping it as a built-in recipe.

## Docs Rules

Docs should be short and copy/paste oriented.

Prefer one page per topic:

- `docs/ai/llama.md`
- `docs/services/cloudflared.md`
- `docs/languages/node.md`
- `docs/languages/python.md`

For a new recipe, document:

- minimal VM config
- create/setup commands
- how to verify it works
- how to view logs, preferably with `dvm logs <name> <unit>`
- security notes if it handles tokens, keys, mounts, or public network access

## Examples

Good docs-only additions:

- Node project setup
- Python project setup
- framework-specific dev server setup

Good recipe additions:

- `llama.sh`: common local AI service, VM-contained, idempotent
- `ai.sh`: common hosted AI CLI setup, credentials stay under `dvm-agent`
- `cloudflared.sh`: common connector service, credentials stay in one VM
- future `tailscale.sh`: only if it stays small and documents login/token handling

Usually not core commands:

- `dvm node`
- `dvm python`
- `dvm cloudflared`
- `dvm tailscale`

Core commands should stay focused on VM operations.
