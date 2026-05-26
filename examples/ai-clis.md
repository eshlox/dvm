# AI CLIs

Install AI tools deliberately. Pin versions when the tool manager supports it.

## Pinned, user-local (recommended)

Installs into the dev user's home with no lifecycle scripts.

```bash
sudo dnf5 install -y nodejs npm

sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  npm install --global --prefix "$HOME/.local/npm" --ignore-scripts \
    @anthropic-ai/claude-code@latest \
    @openai/codex@latest
  line="export PATH=\"\$HOME/.local/npm/bin:\$PATH\""
  grep -Fqx "$line" ~/.bashrc || printf "%s\n" "$line" >>~/.bashrc
'
```

Drop `--ignore-scripts` only after reviewing the package and accepting that
install-time code runs as the dev user.

## Permissive mode (disposable VMs only)

These configs disable the CLI safety prompts and sandboxing. Use only in a
throwaway VM you would not mind being wiped.

```bash
sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  install -d -m 700 ~/.claude
  cat >~/.claude/settings.json <<JSON
{ "permissions": { "defaultMode": "bypassPermissions" } }
JSON
  chmod 600 ~/.claude/settings.json

  install -d -m 700 ~/.codex
  cat >~/.codex/config.toml <<TOML
approval_policy = "never"
sandbox_mode = "danger-full-access"
TOML
  chmod 600 ~/.codex/config.toml
'
```

Do not put API tokens in DVM config. Sign in inside the VM.
