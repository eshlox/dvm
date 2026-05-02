#!/usr/bin/env bash
# shellcheck shell=bash

dvm_ai_install_opencode_tool() {
	dvm_ai_install_npm_tool 'opencode-ai@latest'
	dvm_ai_wrapper_args=()
	dvm_ai_wrapper_env=()
	if [ "$ai_yolo" = "1" ]; then
		dvm_ai_wrapper_env=('OPENCODE_CONFIG_CONTENT={"permission":"allow"}')
	fi
	dvm_ai_install_wrapper opencode "$agent_home/.local/bin/opencode"
}
