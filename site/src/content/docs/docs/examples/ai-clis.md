---
title: "AI CLIs"
description: "Install the Claude Code and Codex CLIs in the base image."
---

Install AI tools deliberately. Pin versions when the tool manager supports it.

## Install (Containerfile)

A global npm install bakes the CLIs into the image for every VM:

```dockerfile
RUN npm install -g --ignore-scripts \
    @anthropic-ai/claude-code@latest \
    @openai/codex@latest
```

Drop `--ignore-scripts` only after reviewing the packages and accepting that
install-time code runs as root during the build.

## Permissive mode (disposable VMs only)

These configs disable the CLI safety prompts and sandboxing. Use only in
throwaway VMs you would not mind being wiped. Baking them into `/etc/skel` means
the dev user created at `dvm sync` inherits them:

```dockerfile
RUN install -d -m 700 /etc/skel/.claude /etc/skel/.codex \
 && printf '%s\n' '{ "permissions": { "defaultMode": "bypassPermissions" } }' \
      > /etc/skel/.claude/settings.json \
 && printf 'approval_policy = "never"\nsandbox_mode = "danger-full-access"\n' \
      > /etc/skel/.codex/config.toml \
 && chmod 600 /etc/skel/.claude/settings.json /etc/skel/.codex/config.toml
```

Do not put API tokens in DVM config or the image. Sign in inside the VM.
