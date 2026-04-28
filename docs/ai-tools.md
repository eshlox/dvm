# AI Tool Setup

Hosted AI coding tools should run through `dvm agent`, not from the normal VM user.
The normal VM user owns project SSH keys, GPG subkeys, dotfiles, and secret-manager
state. The agent user is separate and gets access to project code, system tools, and
its own home directory.

Official docs:

- Claude Code setup: https://code.claude.com/docs/en/setup
- Claude Code sandboxing: https://code.claude.com/docs/en/sandboxing
- Codex CLI setup: https://developers.openai.com/codex/cli
- Codex sandboxing: https://developers.openai.com/codex/concepts/sandboxing
- OpenCode setup: https://opencode.ai/docs/
- Mistral Vibe install: https://docs.mistral.ai/mistral-vibe/terminal/install
- Mistral Vibe quickstart: https://docs.mistral.ai/mistral-vibe/terminal/quickstart

## Workflow

Create a normal project VM:

```bash
dvm new myapp
```

Set up the restricted agent user:

```bash
dvm agent setup myapp
```

Install hosted AI tools for agent use:

```bash
dvm agent install myapp claude
dvm agent install myapp codex
dvm agent install myapp opencode
dvm agent install myapp mistral
```

Run tools only through `dvm agent`:

```bash
dvm agent myapp -- claude
dvm agent myapp -- codex
dvm agent myapp -- opencode
dvm agent myapp -- vibe
```

`dvm agent install myapp all` installs Claude Code, Codex CLI, OpenCode, and Mistral
Vibe.

## What Agent Setup Does

`dvm agent setup <name>` runs inside the VM and:

- installs `bubblewrap`, `acl`, and `shadow-utils`
- creates `DVM_AGENT_USER`, defaulting to `dvm-agent`
- creates `DVM_AGENT_HOME`, defaulting to `/home/dvm-agent`
- grants the agent user access to `DVM_CODE_DIR`
- grants only traversal access to the normal VM user's home
- configures Git safe directory access for repositories under `DVM_CODE_DIR`

When you run `dvm agent <name> -- <command>`, DVM starts the VM and runs the command as
`dvm-agent` through bubblewrap. The sandbox:

- exposes system tools from the VM read-only
- exposes `DVM_AGENT_HOME` read/write
- exposes `DVM_CODE_DIR` read/write
- provides private writable `/tmp` and `/var/tmp`
- hides the normal VM user's home and binds `DVM_CODE_DIR` back into place
- unshares PID, IPC, UTS, and cgroup namespaces
- does not unshare networking, so hosted AI tools and package managers still work

This means the agent can run project commands such as:

```bash
dvm agent myapp -- pnpm test
dvm agent myapp -- npm run lint
dvm agent myapp -- python -m pytest
dvm agent myapp -- bash -lc 'cd web && pnpm dev'
```

The agent can use packages installed in the VM, such as `node`, `pnpm`, `python`,
`gcc`, `ripgrep`, and project-local tools under `node_modules/.bin` or `.venv`. Caches
and tool auth live under `DVM_AGENT_HOME`, not the normal VM user's home.

## Installing Tools

Claude Code is installed from Anthropic's signed Fedora/RHEL package repository. The
default channel is `stable`; set `DVM_AGENT_CLAUDE_CHANNEL="latest"` in `config.sh` if
you want the rolling channel.

```bash
dvm agent install myapp claude
```

Codex CLI is installed with npm into the agent user's `~/.local` prefix:

```bash
dvm agent install myapp codex
```

OpenCode is installed with npm into the agent user's `~/.local` prefix:

```bash
dvm agent install myapp opencode
```

Mistral Vibe is installed with `uv tool install mistral-vibe` into the agent user's
home. The runtime command is `vibe`:

```bash
dvm agent install myapp mistral
```

Authentication happens inside the agent context:

```bash
dvm agent myapp -- claude
dvm agent myapp -- codex
dvm agent myapp -- opencode
dvm agent myapp -- vibe
```

That stores AI-tool auth in `/home/dvm-agent`, scoped to that VM filesystem.

## Secret Boundaries

DVM protects the host by putting project work in a VM. `dvm agent` adds another boundary
inside that VM so hosted AI tools do not run as the user that owns SSH keys, GPG keys,
dotfiles, and secret-manager config.

Use the normal shell for human operations that need VM credentials:

```bash
dvm myapp
git pull
git commit -S
```

Use the agent shell for AI operations:

```bash
dvm agent myapp -- codex
```

If a test suite needs production secrets, the agent should not receive those secrets by
default. Prefer local test credentials, mocks, or a future explicit broker that can
prompt and enforce policy for each secret operation.

## Limits

`dvm agent` is a practical isolation layer, not a perfect sandbox. The agent can still
read and modify project code, run networked commands, consume API credits, and execute
any system tool available in the VM. It should not be given access to host mounts,
shared auth directories, SSH agent sockets, GPG agent sockets, or secret-manager config
unless you are intentionally weakening the boundary.
