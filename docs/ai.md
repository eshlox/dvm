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

`agent-user` creates `dvm-agent` as a system account with a home directory, installs
Bubblewrap, grants ACL access to `DVM_CODE_DIR`, creates `/home/dvm-agent/scratch`, and
installs the mandatory AI sandbox helper at `/usr/local/libexec/dvm-ai-bwrap`.

AI tools do not run directly. The wrappers always run the tool as `dvm-agent` inside
Bubblewrap. There is no non-Bubblewrap mode.

The Bubblewrap filesystem view is intentionally small:

- `/workspace`: the project code from `DVM_CODE_DIR`, read/write
- `/home/dvm-agent`: the agent user's home, read/write for login state and tool config
- `/usr`, `/etc`, `/proc`, `/dev`: runtime/system paths needed to execute tools
- `/tmp` and `/var/tmp`: sandbox-local temporary directories

The main user's home, such as `/home/eshlox`, is not mounted into the sandbox. The ACL
rules remain as defense in depth and to let `dvm-agent` bind the project directory.
Network access is retained because hosted AI tools need their provider APIs. Guest root
or bad sudo policy can still bypass this; Bubblewrap is not a separate VM.

## Tools

- `codex`: installs `@openai/codex` with npm under `dvm-agent`.
- `claude`: installs Claude Code from Anthropic's signed `latest` RPM repo. By default
  it sets `defaultMode` to `bypassPermissions` for the `dvm-agent` user; set
  `DVM_CLAUDE_BYPASS=0` in a VM config to leave Claude permission prompts enabled.
- `opencode`: installs `opencode-ai` with npm under `dvm-agent`.
- `mistral`: installs `mistral-vibe` with uv under `dvm-agent` and exposes `vibe` and
  `mistral` wrappers.

Wrappers are installed in `/usr/local/bin`, clamp the host-side working directory to
`DVM_CODE_DIR`, and enter the sandbox at `/workspace` or the matching subdirectory under
`/workspace`.

## Authentication

Authenticate inside the VM:

```bash
dvm enter app
codex
claude
opencode
```

Login state stays in the VM under the agent user's home, which is mounted into the
sandbox.

Claude starts in bypass-permissions mode by default because DVM's intended boundary is
the VM plus the `dvm-agent` Bubblewrap sandbox. In that mode Claude can edit project
code, run project commands, use the network, and write its own login/tool state under
the agent user's home without asking for each action. The main user's home, SSH keys,
GPG keys, and common token/config paths are not mounted into the sandbox.

Set this in a VM config when you want Claude permission prompts instead:

```bash
DVM_CLAUDE_BYPASS=0
```

To temporarily avoid unattended edits or commands for one session, start Claude with an
explicit mode such as:

```bash
claude --permission-mode plan
```

## Updates

Re-run recipes to update AI tools:

```bash
dvm apply app
dvm apply --all
```

`codex` and `opencode` install `@latest` from npm. `mistral` runs `uv tool upgrade`.
`claude` uses Anthropic's `latest` RPM channel and runs `dnf5 --refresh upgrade
claude-code`. If Claude reports a version before the RPM repository publishes it, wait
and re-run `dvm apply`.

## Security Practice

- Keep provider tokens out of host shell history.
- Keep project secrets out of dotfiles.
- Prefer repo-scoped keys or service tokens over account-wide credentials.
- Treat AI output as untrusted code until reviewed.
- Re-run `dvm apply app` after recipe changes.
