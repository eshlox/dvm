# shellcheck shell=bash
# shellcheck disable=SC2034,SC2088
# Global DVM defaults. Uncomment lines below to override built-in defaults.
# Per-VM config in ~/.config/dvm/vms/<name>.sh overrides these in turn.

# VM resources (per-VM DVM_CPUS / DVM_MEMORY / DVM_DISK override these):
# DVM_CPUS=2          # default 2
# DVM_MEMORY=2GiB     # default 2GiB
# DVM_DISK=10GiB      # default 10GiB

# DVM_ARCH=default                   # default; resolves to host arch
# DVM_USER="${USER:-developer}"      # default; primary guest user
# DVM_CODE_ROOT="~/code"             # default; parent for DVM_CODE_DIR
# DVM_HOST_IP="127.0.0.1"            # default; bind IP for two-part DVM_PORTS
# DVM_AI_AGENT_USER="dvm-agent"      # default; user for AI tools

# Codex defaults to unattended yolo mode inside the dvm-agent Bubblewrap sandbox.
# Set to 0 to enable Codex approval prompts and its own sandbox.
# DVM_CODEX_YOLO=1

# Claude defaults to unattended bypass mode inside the dvm-agent Bubblewrap sandbox.
# Set to 0 to enable Claude permission prompts.
# DVM_CLAUDE_BYPASS=1

# Tailscale auth key for VMs that use the `tailscale` recipe. Pass at sync time
# instead so it does not sit in a config file: `TAILSCALE_AUTH_KEY=tskey-... dvm sync ...`.
# DVM_TAILSCALE_AUTH_KEY="tskey-..."

# Settings for the chezmoi recipe. DVM_CHEZMOI_REPO is required when any VM uses
# `use chezmoi`. The signing/deploy key paths default to those created by
# `dvm ssh-key <name>`; override only if you use custom key names.
# DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"
# DVM_CHEZMOI_ROLE="vm"
# DVM_CHEZMOI_NAME="Your Name"
# DVM_CHEZMOI_EMAIL="you@example.com"
# DVM_CHEZMOI_SIGNING_KEY="~/.ssh/id_ed25519_dvm_signing.pub"
# DVM_CHEZMOI_DEPLOY_KEY="~/.ssh/id_ed25519_dvm.pub"

# Default toolset shared across app VMs. The bundled VM template calls
# `use_tools`, so any recipe uncommented here is installed in every VM that
# keeps that call. Define more helpers (e.g. `use_data_tools`) and call them
# from per-VM configs to mix and match.
use_tools() {
	: # placeholder; remove once at least one `use` line below is uncommented
	# use zsh         # zsh shell (sets as login shell)
	# use git         # git
	# use helix       # Helix editor
	# use lazygit     # lazygit TUI
	# use starship    # starship prompt
	# use fzf         # fzf fuzzy finder
	# use bat         # bat (cat with syntax highlighting)
	# use git-delta   # delta diff pager
	# use just        # just task runner
	# use tmux        # tmux terminal multiplexer
	# use yazi        # yazi file manager
	# use node        # Node.js, npm, corepack
	# use python      # Python and uv
	# use agent-user  # dvm-agent user with Bubblewrap sandbox for AI tools
	# use codex       # Codex CLI
	# use claude      # Claude Code CLI
	# use opencode    # OpenCode CLI
	# use mistral     # Mistral CLI
	# use chezmoi     # public dotfiles via chezmoi over HTTPS
}
