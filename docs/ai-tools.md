# AI Tool Setup

This page shows examples for installing AI coding tools inside DVM guests. DVM does
not install hosted AI tools by default because each tool has its own update, auth, and
security model.

Put tool setup in `~/.config/dvm/setup.d/fedora.sh`. Keep `DVM_PACKAGES` for normal
Fedora packages; use setup scripts for third-party repositories, npm packages, and
tool-specific configuration.

Official docs:

- Claude Code setup: https://code.claude.com/docs/en/setup
- Claude Code sandboxing: https://code.claude.com/docs/en/sandboxing
- Codex CLI setup: https://developers.openai.com/codex/cli
- Codex sandboxing: https://developers.openai.com/codex/concepts/sandboxing

## Claude Code

Anthropic documents a signed Fedora/RHEL package repository. This keeps updates in the
normal package manager flow.

```bash
# ~/.config/dvm/setup.d/fedora.sh
if [ "$DVM_NAME" = "myapp" ] || [ "$DVM_NAME" = "ai" ]; then
  sudo tee /etc/yum.repos.d/claude-code.repo >/dev/null <<'EOF'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF

  sudo dnf5 install -y claude-code
fi
```

Use `stable` for the delayed stable channel. Replace both `stable` occurrences in the
repo URL with `latest` if you want the rolling channel. Anthropic documents the release
signing key fingerprint as `31DD DE24 DDFA B679 F42D 7BD2 BAA9 29FF 1A7E CACE`;
verify the key before trusting it.

After setup:

```bash
dvm myapp
claude
```

## Codex CLI

OpenAI documents npm as the Codex CLI install path. Install Node.js from Fedora, then
install Codex into the guest user's `~/.local` prefix.

```bash
# ~/.config/dvm/setup.d/fedora.sh
if [ "$DVM_NAME" = "myapp" ] || [ "$DVM_NAME" = "ai" ]; then
  sudo dnf5 install -y nodejs npm

  npm config set prefix "$HOME/.local"
  mkdir -p "$HOME/.local/bin"

  if ! grep -Fq 'DVM npm global bin' "$HOME/.bashrc" 2>/dev/null; then
    {
      printf '\n# DVM npm global bin\n'
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    } >>"$HOME/.bashrc"
  fi

  export PATH="$HOME/.local/bin:$PATH"
  npm install -g @openai/codex
fi
```

After setup:

```bash
dvm myapp
codex
```

The first run prompts for authentication. Authenticate separately in each VM if you want
each VM to have separate auth state.

## Secret Boundaries

DVM isolates projects from the host, but an AI tool running as the normal guest user can
read anything that user can read inside the VM. That includes per-VM SSH keys, GPG
subkeys, CLI auth files, shell history, and secret-manager config if those files are in
the same home directory.

For day-to-day AI coding, the practical target is:

- AI can read and write the project under `DVM_CODE_DIR`.
- AI can run installed project tools, tests, package managers, and debuggers.
- AI cannot read `~/.ssh`, `~/.gnupg`, provider auth directories, or secret-manager
  config.
- Human shells entered with `dvm enter <name>` keep the normal per-VM SSH and GPG
  workflow.

Install sandbox prerequisites for AI tools:

```bash
sudo dnf5 install -y bubblewrap socat
```

Claude Code has native sandbox settings. A restrictive project-level starting point is:

```json
{
  "sandbox": {
    "enabled": true,
    "allowUnsandboxedCommands": false,
    "filesystem": {
      "denyRead": ["~/"],
      "allowRead": ["."],
      "allowWrite": [".", "/tmp"]
    }
  }
}
```

Place that in the project at `.claude/settings.json`, then run `claude` from the project
directory. Expand `allowWrite` only for paths that specific tools need, such as a build
cache under `/tmp`.

Codex CLI also supports sandbox and approval modes. On Linux, install `bubblewrap` and
start with the default workspace-write permissions instead of full access. Use
`/permissions` inside Codex to inspect or change the active mode. Avoid
`danger-full-access` for routine project work.

## Authentication Choices

Per-VM login means running `claude` or `codex` inside each VM and letting that tool store
its own auth state in that VM. This is isolated at the filesystem level, but all sessions
may still belong to the same upstream account.

Per-VM API keys give better revocation and budget control when the provider supports it.
Create one key per VM or per project, give it a clear name, set a budget if available,
and revoke only that key if the VM is compromised.

Avoid sharing one mounted auth directory across all VMs. It is convenient, but any VM
that can read it can reuse the shared session.

## SSH And GPG

DVM's default is still separate SSH keys and separate GPG signing subkeys per VM. This is
more work than forwarding host agents, but it keeps revocation scoped to one VM.

Forwarding host `ssh-agent` or `gpg-agent` into a VM is possible in principle, but it is
less isolated. A compromised VM usually cannot extract the private key from an agent,
but it can ask the agent to authenticate or sign while the socket is available.

Short-lived secret injection has the same limitation. If an AI process can access an
environment variable, socket, or temporary file, it can use that capability while it
exists. Destroying it on exit limits duration, not access. The safer pattern is a
capability broker that prompts or enforces policy for each operation, which is
substantially more complex than the current DVM flow.
