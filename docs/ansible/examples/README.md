# Ansible role examples

> **Status: reference sketches.** These files show shape and intent of
> roles that fit DVM's contract. They are not lint-tested against a real
> Fedora image and not run in CI. Treat them as starting points: paste
> into your repo, then validate with `ansible-playbook --syntax-check`,
> `ansible-lint`, and a real `dvm sync` against a throwaway VM before
> relying on them.

| File | What it shows |
|---|---|
| [base.yml](base.yml) | Minimum baseline: common packages, code dir |
| [agent_user.yml](agent_user.yml) | Unprivileged `dvm-agent` identity + group membership for code write access |
| [sandbox.yml](sandbox.yml) | Bubblewrap `dvm-agent` wrapper that contains AI tools at runtime |
| [chezmoi.yml](chezmoi.yml) | Apply dotfiles from a separate repo |
| [keys.yml](keys.yml) | SSH/GPG identity — `generate` and `vault` modes |
| [codex.yml](codex.yml) | OpenAI Codex CLI, agent-user scoped |
| [claude.yml](claude.yml) | Anthropic Claude Code CLI, agent-user scoped |
| [tailscale.yml](tailscale.yml) | Tailnet join via env-supplied auth key |
| [cloudflared.yml](cloudflared.yml) | Cloudflare Tunnel via env-supplied token |
| [llama.yml](llama.yml) | llama.cpp server with verified model download |

See [../../ansible.md](../../ansible.md) for the full external repo
contract.
