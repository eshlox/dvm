# How To

## Create A VM With Common Tools

```bash
dvm new app
```

Edit the generated config:

```bash
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
DVM_PACKAGES=(git tmux ripgrep)
DVM_RECIPES=(zsh fzf starship node)
DVM_GIT_REPO="git@github.com:me/app.git"
```

Then:

```bash
dvm sync app
dvm sh app
```

## Set Global Defaults

```bash
dvm config edit
```

```bash
DVM_DEFAULT_PACKAGES=(git ripgrep fd-find tmux)
DVM_DEFAULT_RECIPES=(zsh fzf starship)
```

Every VM gets those defaults before its own packages and recipes.

## Add A Project Hook

DVM runs `$DVM_CODE_DIR/.dvm/sync.sh` last when it exists. This hook lives in
the guest project repo, not on the host, and runs as `DVM_USER` by default.

```bash
#!/usr/bin/env bash
set -euo pipefail
corepack enable
npm install
```

Disable hooks for a VM with:

```bash
DVM_PROJECT_HOOK=0
```

`DVM_PROJECT_HOOK_PRIVILEGED=1` runs project-controlled code with provisioning
privileges. Use that only for repositories you fully trust, and review
`DVM_DRY_RUN=1 dvm sync <vm>` before syncing.

For an allow-list style workflow, set:

```bash
DVM_PROJECT_HOOK_GIT_CONFIG=1
```

Then opt in from inside the project repo:

```bash
git config dvm.hook true
```

## Share A Local Service

For local-only browser testing:

```bash
DVM_PORTS=(3000:3000)
```

For teammates, prefer an identity-aware network path:

```bash
DVM_RECIPES=(tailscale)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY)
```

```bash
DVM_TAILSCALE_AUTHKEY=tskey-... dvm sync demo
```

Or use Cloudflare Tunnel:

```bash
DVM_RECIPES=(cloudflared)
DVM_SECRETS=(DVM_CLOUDFLARED_TOKEN)
```

For direct VM IP access, configure Lima networking outside DVM.

## Run AI Tools Inside The VM

For normal project work, run AI tools as the main VM user inside your existing
shell, tmux, or zellij session:

```bash
dvm sh app
zellij
claude
codex
```

This trusted-dev mode gives the tool the same access you have inside the VM:
installed runtimes, local databases, test dependencies, project files, and
per-project SSH/signing keys. Keep those keys narrowly scoped to the project,
do not forward broad host SSH/GPG agents into the VM, and do not store
production credentials there.

Use the guardrail agent user only when you specifically want to hide the main
user home from the AI tool:

```bash
DVM_RECIPES=(agent-user codex claude opencode)
```

Inside the VM:

```bash
dvm-agent codex
dvm-agent claude
dvm-agent opencode
```

Or open an interactive guardrail shell:

```bash
dvm-agent-shell
```

The wrapper requires Bubblewrap by default, hides the main user's home, and
exposes only the project directory plus the agent user's home. It preserves
network access unless you run the command with `DVM_AGENT_NETWORK=0`. Set
`DVM_AGENT_ALLOW_UNSANDBOXED=1` only when you intentionally want the weak
plain-`sudo` fallback.

## Guest-Local Keys

```bash
DVM_RECIPES=(ssh-keys gpg-keys)
```

The generated keys live only in the VM. They are not copied from the host.

## Reuse A Base VM

Put slow, stable setup in the base:

```bash
DVM_BASE_PACKAGES=(git ripgrep fd-find)
DVM_BASE_RECIPES=(zsh fzf starship)
```

Build it:

```bash
dvm base build
```

Then opt into cloning it:

```bash
DVM_USE_BASE=1
dvm sync app
```

Base builds and removals are locked. A sync that needs to clone a missing VM
from the base refuses to proceed while `dvm base build` or `dvm base rm` holds
the base lock.

## Inspect Before Running

```bash
DVM_DRY_RUN=1 dvm sync app
```

This prints the Lima argv and generated guest script.

## Recover From A Failed Sync

Fix the failed package/recipe/config and run `dvm sync <vm>` again. DVM does
not roll back partial setup. See [errors-and-recovery.md](errors-and-recovery.md)
for stale locks and half-built VMs.
