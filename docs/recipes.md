# Recipes

Recipes are Bash snippets run inside the guest during `dvm sync`, after
`DVM_PACKAGES` and before the project hook. Recipe order is significant.
Repeated recipes are de-duplicated after alias expansion.

Built-ins live in `share/dvm/recipes`. User overrides live in
`~/.config/dvm/recipes` and win by name.

## Built-In Recipes

| Recipe | Purpose | Source |
| --- | --- | --- |
| `age` | install age | [age.sh](../share/dvm/recipes/age.sh) |
| `agent-user` | create `DVM_AGENT_USER`, `dvm-agent`, and `dvm-agent-shell` | [agent-user.sh](../share/dvm/recipes/agent-user.sh) |
| `bat` | install bat | [bat.sh](../share/dvm/recipes/bat.sh) |
| `chezmoi` | install chezmoi; apply `DVM_CHEZMOI_REPO` when set | [chezmoi.sh](../share/dvm/recipes/chezmoi.sh) |
| `claude` | install pinned Claude Code with user-local npm | [claude.sh](../share/dvm/recipes/claude.sh) |
| `cloudflared` | install Cloudflare Tunnel and optionally register a token | [cloudflared.sh](../share/dvm/recipes/cloudflared.sh) |
| `codex` | install pinned OpenAI Codex CLI with user-local npm | [codex.sh](../share/dvm/recipes/codex.sh) |
| `delta` | install git-delta and set Git pager defaults | [delta.sh](../share/dvm/recipes/delta.sh) |
| `docker` | install Docker engine and compose support; conflicts with `agent-user` by default | [docker.sh](../share/dvm/recipes/docker.sh) |
| `fzf` | install fzf | [fzf.sh](../share/dvm/recipes/fzf.sh) |
| `gpg-keys` | create a guest-local signing key if none exists | [gpg-keys.sh](../share/dvm/recipes/gpg-keys.sh) |
| `helix` | install Helix | [helix.sh](../share/dvm/recipes/helix.sh) |
| `just` | install just | [just.sh](../share/dvm/recipes/just.sh) |
| `lazygit` | install lazygit | [lazygit.sh](../share/dvm/recipes/lazygit.sh) |
| `mistral` | install a user-supplied verified Mistral CLI binary | [mistral.sh](../share/dvm/recipes/mistral.sh) |
| `node` | install Node.js, npm, and enable corepack | [node.sh](../share/dvm/recipes/node.sh) |
| `ollama` | install a user-supplied verified Ollama binary and try to enable its service | [ollama.sh](../share/dvm/recipes/ollama.sh) |
| `opencode` | install pinned opencode with user-local npm | [opencode.sh](../share/dvm/recipes/opencode.sh) |
| `python` | install Python, pip, venv/virtualenv, and pipx | [python.sh](../share/dvm/recipes/python.sh) |
| `sops` | install sops | [sops.sh](../share/dvm/recipes/sops.sh) |
| `ssh-keys` | create a guest-local SSH key if missing | [ssh-keys.sh](../share/dvm/recipes/ssh-keys.sh) |
| `starship` | install Starship and add shell init lines | [starship.sh](../share/dvm/recipes/starship.sh) |
| `tailscale` | install Tailscale and optionally join with an auth key | [tailscale.sh](../share/dvm/recipes/tailscale.sh) |
| `yazi` | install yazi | [yazi.sh](../share/dvm/recipes/yazi.sh) |
| `zellij` | install zellij | [zellij.sh](../share/dvm/recipes/zellij.sh) |
| `zsh` | install zsh and make it the primary user's shell | [zsh.sh](../share/dvm/recipes/zsh.sh) |

Aliases: `ai-user` and `ai-agent` map to `agent-user`; `cloudflare` and
`cloudflare-tunnel` map to `cloudflared`; `ssh-key` maps to `ssh-keys`;
`gpg-key` maps to `gpg-keys`.

## Ordering And Conflicts

Recipes run in the order listed after global defaults are prepended and aliases
are canonicalized. Built-ins can declare conflicts with comment metadata:

```bash
# dvm-conflicts: agent-user
```

DVM rejects a recipe set with declared conflicts unless
`DVM_ALLOW_RECIPE_CONFLICTS=1` is set. The Docker recipe declares a conflict
with `agent-user` because Docker group access is root-equivalent inside the
guest. The Docker recipe does not add `DVM_AGENT_USER` to the Docker group
unless `DVM_DOCKER_AGENT_ACCESS=1` is exported into the guest.

## Supply Chain

Built-in npm recipes use exact default versions and install under
`~/.local/npm` as `DVM_USER`, not with `sudo npm install -g`.

Distro package recipes intentionally track the configured Fedora repositories;
DVM does not lock RPM versions or produce a package bill of materials yet.

| Recipe | Default version | Script policy |
| --- | --- | --- |
| `codex` | `0.132.0` | `--ignore-scripts` |
| `claude` | `2.1.146` | package lifecycle scripts run as `DVM_USER` |
| `opencode` | `1.15.6` | package lifecycle scripts run as `DVM_USER` |

Override versions with `DVM_CODEX_VERSION`, `DVM_CLAUDE_CODE_VERSION`, or
`DVM_OPENCODE_VERSION`. If you set `DVM_NPM_PREFIX`, add its `bin` directory to
your shell path yourself.

The `ollama` and `mistral` recipes no longer execute live upstream installer
scripts. They require a pinned HTTPS URL and SHA-256 checksum:

```bash
DVM_OLLAMA_URL="https://example.invalid/ollama"
DVM_OLLAMA_SHA256="..."
DVM_MISTRAL_URL="https://example.invalid/mistral"
DVM_MISTRAL_SHA256="..."
```

`dvm_download_verified` rejects non-HTTPS URLs, downloads with
`curl --proto '=https' --tlsv1.2`, verifies SHA-256, and only then installs the
binary.

## Writing A Recipe

```bash
# ~/.config/dvm/recipes/my-tool.sh
dvm_pkg curl
dvm_as_user bash -lc 'mkdir -p ~/.local/bin'
```

Available helpers:

| Helper | Meaning |
| --- | --- |
| `dvm_pkg <pkg...>` | install packages with `dnf5` |
| `dvm_as_user <cmd...>` | run a command as `DVM_USER` |
| `dvm_as_agent <cmd...>` | run a command as `DVM_AGENT_USER` |
| `dvm_ensure_user <user>` | create a guest user when missing |
| `dvm_user_group <user>` | print a user's primary group |
| `dvm_secret <NAME>` | print the randomized staged secret path or fail |
| `dvm_has_secret <NAME>` | test whether a staged secret path exists and is readable |
| `dvm_append_once <file> <line>` | append a line to a user-owned file once |
| `dvm_download_verified <name> <url> <sha256> <dest>` | download and install a verified binary |
| `dvm_npm_global <package> <version> <script-policy>` | install a pinned package under a user-owned npm prefix |

The helper API is intentionally small and may change before the first stable
release.

Built-in recipes target Lima's latest Fedora template only.
