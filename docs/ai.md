# AI

Run hosted AI CLIs inside a VM, sandboxed to the project tree. Nothing
installed on the host.

## Setup

In the VM config, list `agent-user` **before** any AI tool recipe:

```bash
DVM_RECIPES=(agent-user codex claude opencode mistral)
```

`agent-user` creates a non-login `dvm-agent` system account, installs
Bubblewrap, and grants shared ACL access to `DVM_CODE_DIR` for both the
primary user and `dvm-agent`. AI wrappers always re-exec the tool as
`dvm-agent` inside Bubblewrap — there is no non-sandboxed mode.

The Bubblewrap view contains:

- `/workspace` → `DVM_CODE_DIR` (read/write)
- `/home/dvm-agent` (read/write, holds tool login state)
- `/usr`, `/etc`, `/proc`, `/dev` (read-only system bits)
- `/tmp`, `/var/tmp` (tmpfs)

The primary user's home is **not** mounted into the sandbox. Network is
available because hosted AI tools need provider APIs. Guest root or bad
sudo policy can bypass this; Bubblewrap is not a separate VM.

## Tools

| Recipe | Install path | Notes |
|---|---|---|
| `codex` | `npm i -g @openai/codex` | starts in `--dangerously-bypass-approvals-and-sandbox`; opt out with `DVM_CODEX_YOLO=0` |
| `claude` | Anthropic RPM repo | sets `defaultMode: bypassPermissions`; opt out with `DVM_CLAUDE_BYPASS=0` |
| `opencode` | `npm i -g opencode-ai` | |
| `mistral` | `uv tool install mistral-vibe` | wrappers `vibe` and `mistral` |

Wrappers live in `/usr/local/bin`, clamp the host-side cwd to
`DVM_CODE_DIR`, and enter the sandbox at the matching path under
`/workspace`.

## Defaults

Codex and Claude run unattended by default. The VM + `dvm-agent`
Bubblewrap sandbox is the boundary; the tools edit code and run project
commands without per-action prompts. Override per VM:

```bash
DVM_CODEX_YOLO=0
DVM_CLAUDE_BYPASS=0
```

For a single Claude session, `claude --permission-mode plan` runs in
plan mode without changing the recipe default.

## Authentication

First time: `dvm sh app` then `codex` / `claude` / `opencode` and follow
the login flow. Login state persists in the sandbox under
`/home/dvm-agent`.

## Updates

Re-run the recipes:

```bash
dvm sync app
```

`codex` / `opencode` install `@latest` from npm each sync. `mistral`
runs `uv tool upgrade`. `claude` uses Anthropic's `latest` RPM channel
with `dnf5 --refresh upgrade`.

## Practice

- Keep provider tokens out of host shell history.
- Prefer repo-scoped keys over account-wide credentials.
- Treat AI output as untrusted code until reviewed.
