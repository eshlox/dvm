#!/usr/bin/env bash
# shellcheck shell=bash

dvm_ai_install_claude_tool() {
	sudo tee /etc/yum.repos.d/claude-code.repo >/dev/null <<EOF
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/$claude_channel
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF
	sudo dnf5 install -y claude-code
	dvm_ai_wrapper_args=()
	dvm_ai_wrapper_env=()
	if [ "$ai_yolo" = "1" ]; then
		dvm_ai_wrapper_args=(--dangerously-skip-permissions)
	fi
	dvm_ai_install_wrapper claude /usr/bin/claude
}
