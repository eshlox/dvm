# Future development

Keep DVM small. Prefer docs or recipes over framework code.

Possible next safety work:

- outbound network policy per VM or recipe
- host-side secret broker instead of guest files
- ephemeral agent VM workflow
- sync/session logs
- documented VM roles: `dev`, `agent`, `service`
- direct Lima networking docs for users who need VM IP access

Non-goals:

- arbitrary guest distro support
- default host project mounts
- plugin/package-manager framework
- managing production secrets

Rule: add safety features only when they reduce exposure without making DVM
hard to audit.
