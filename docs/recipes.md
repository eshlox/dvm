# Recipes

Recipes are Bash snippets run inside the guest after `DVM_PACKAGES`. Built-ins
live in `share/dvm/recipes`; user overrides live in `~/.config/dvm/recipes`.

Order matters. Repeated recipes are de-duplicated after aliases are resolved.

## Built-ins

| Recipe | Purpose |
| --- | --- |
| `age` | age |
| `agent-user` | `dvm-agent` and `dvm-agent-shell` |
| `bat` | bat |
| `chezmoi` | chezmoi plus optional `DVM_CHEZMOI_REPO` apply |
| `claude` | pinned Claude Code, user-local npm |
| `cloudflared` | Cloudflare Tunnel |
| `codex` | pinned Codex, user-local npm |
| `delta` | git-delta defaults |
| `docker` | Docker engine and compose |
| `fzf` | fzf |
| `gpg-keys` | VM-local signing key |
| `helix` | Helix |
| `just` | just |
| `lazygit` | lazygit |
| `mistral` | verified Mistral binary |
| `node` | Node.js, npm, corepack |
| `ollama` | verified Ollama binary |
| `opencode` | pinned opencode, user-local npm |
| `python` | Python, pip, virtualenv, pipx |
| `sops` | sops |
| `ssh-keys` | VM-local SSH key |
| `starship` | Starship shell init |
| `tailscale` | Tailscale |
| `yazi` | yazi |
| `zellij` | zellij |
| `zsh` | zsh |

Aliases: `ai-user`/`ai-agent` -> `agent-user`, `cloudflare` ->
`cloudflared`, `ssh-key` -> `ssh-keys`, `gpg-key` -> `gpg-keys`.

## Supply chain

npm recipes install exact versions under `~/.local/npm` as `DVM_USER`.

| Recipe | Default |
| --- | --- |
| `codex` | `0.132.0` |
| `claude` | `2.1.146` |
| `opencode` | `1.15.6` |

Override with `DVM_CODEX_VERSION`, `DVM_CLAUDE_CODE_VERSION`, or
`DVM_OPENCODE_VERSION`.

`ollama` and `mistral` require an HTTPS URL plus SHA-256:

```bash
DVM_OLLAMA_URL="https://example.invalid/ollama"
DVM_OLLAMA_SHA256="..."
```

Distro packages intentionally track configured Fedora repos.

## Conflicts

Recipes can declare conflicts with:

```bash
# dvm-conflicts: agent-user
```

DVM rejects conflicts unless `DVM_ALLOW_RECIPE_CONFLICTS=1`. `docker` conflicts
with `agent-user` because Docker group access is root-equivalent in the guest.

## Write a recipe

```bash
# ~/.config/dvm/recipes/my-tool.sh
dvm_pkg curl
dvm_as_user bash -lc 'mkdir -p ~/.local/bin'
```

Helpers:

| Helper | Meaning |
| --- | --- |
| `dvm_pkg <pkg...>` | install Fedora packages |
| `dvm_as_user <cmd...>` | run as `DVM_USER` |
| `dvm_as_agent <cmd...>` | run as `DVM_AGENT_USER` |
| `dvm_ensure_user <user>` | create a guest user without subordinate ID allocation |
| `dvm_user_group <user>` | print primary group |
| `dvm_secret <NAME>` | print staged secret path |
| `dvm_has_secret <NAME>` | test staged secret availability |
| `dvm_append_once <file> <line>` | append one user-owned line |
| `dvm_download_verified <name> <url> <sha256> <dest>` | HTTPS download plus SHA-256 |
| `dvm_npm_global <pkg> <version> <policy>` | pinned user-local npm install |

Built-ins target Lima's latest Fedora template with `dnf5`.
