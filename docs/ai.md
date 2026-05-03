# AI

AI tools run inside VMs. Nothing needs to be installed on the host.

## Agent User

Use `agent-user` before hosted AI recipes:

```bash
use agent-user
use codex
use claude
use opencode
use mistral
```

`agent-user` creates `dvm-agent`, grants ACL access to `DVM_CODE_DIR`, creates
`/home/dvm-agent/scratch`, and restricts common main-user secret paths such as `.ssh`,
`.gnupg`, `.npmrc`, `.gitconfig`, shell histories, `.config/git`, `.config/gh`, and
`.config/op`.

This is a Unix-permissions guardrail, not a sandbox. Guest root or bad sudo policy can
bypass it.

## Tools

- `codex`: installs `@openai/codex` with npm under `dvm-agent`.
- `claude`: installs Claude Code from the vendor RPM repo.
- `opencode`: installs `opencode-ai` with npm under `dvm-agent`.
- `mistral`: installs `mistral-vibe` with uv under `dvm-agent` and exposes `vibe` and
  `mistral` wrappers.

Wrappers are installed in `/usr/local/bin` and clamp the working directory to
`DVM_CODE_DIR`.

## Authentication

Authenticate inside the VM:

```bash
dvm enter app
codex
claude
opencode
```

Login state stays in the VM, normally under the agent user's home.

## Security Practice

- Keep provider tokens out of host shell history.
- Keep project secrets out of dotfiles.
- Prefer repo-scoped keys or service tokens over account-wide credentials.
- Treat AI output as untrusted code until reviewed.
- Re-run `dvm apply app` after recipe changes.
