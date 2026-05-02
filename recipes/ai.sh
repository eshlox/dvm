#!/usr/bin/env bash
set -euo pipefail

agent_user="${DVM_AGENT_USER:-dvm-agent}"
code_dir="${DVM_CODE_DIR:?DVM_CODE_DIR is required}"
tools="${DVM_AI_TOOLS-claude codex opencode mistral}"
claude_channel="${DVM_CLAUDE_CHANNEL:-stable}"
ai_yolo="${DVM_AI_YOLO:-1}"
agent_home=""
dvm_ai_wrapper_args=()
dvm_ai_wrapper_env=()

dvm_ai_validate
if [ "$ai_yolo" = "1" ]; then
	dvm_recipe_warn "ai.sh: DVM_AI_YOLO=1 enables non-interactive AI tool approvals"
fi
dvm_ai_ensure_agent_user
dvm_ai_install_runner

if dvm_ai_needs_tool claude; then
	dvm_ai_install_claude_tool
fi

if dvm_ai_needs_tool codex || dvm_ai_needs_tool opencode; then
	dvm_ai_ensure_npm
fi

if dvm_ai_needs_tool codex; then
	dvm_ai_install_codex_tool
fi

if dvm_ai_needs_tool opencode; then
	dvm_ai_install_opencode_tool
fi

if dvm_ai_needs_tool mistral; then
	dvm_ai_install_mistral_tool
fi

cat <<EOF
AI tools are ready.

Installed tools: ${tools:-none}
Agent user: $agent_user
Code directory: $code_dir
YOLO mode: $ai_yolo

Run inside the VM:
  claude
  codex
  opencode
  vibe

Run from the host:
  dvm $DVM_NAME claude
EOF
