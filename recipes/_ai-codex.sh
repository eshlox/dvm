#!/usr/bin/env bash
# shellcheck shell=bash

dvm_ai_install_codex_tool() {
	dvm_ai_install_npm_tool '@openai/codex@latest'
	dvm_ai_wrapper_args=()
	dvm_ai_wrapper_env=()
	if [ "$ai_yolo" = "1" ]; then
		dvm_ai_wrapper_args=(--dangerously-bypass-approvals-and-sandbox)
	fi
	dvm_ai_install_wrapper codex "$agent_home/.local/bin/codex"
}
