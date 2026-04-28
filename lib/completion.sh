#!/usr/bin/env bash
# shellcheck shell=bash

dvm_completion_zsh() {
	local command_name
	command_name="$(basename "$0")"
	cat <<'EOF' | sed "s/__DVM_COMMAND__/$command_name/g"
#compdef __DVM_COMMAND__

_dvm() {
  local -a commands vms
  commands=(
    'init:create user config'
    'new:create a VM'
    'setup:rerun setup in one VM'
    'setup-all:rerun setup in all VMs'
    'enter:enter a VM'
    'ssh:run a command in a VM'
    'key:print VM SSH public key'
    'list:list VMs'
    'rm:delete a VM'
    'gpg:manage VM GPG signing subkeys'
    'doctor:check local requirements'
    'completion:print shell completion'
    'help:show help'
  )
  vms=("${(@f)$(__DVM_COMMAND__ list 2>/dev/null)}")

  if (( CURRENT == 2 )); then
    _describe -t commands 'dvm command' commands
    _describe -t vms 'VM' vms
    return
  fi

  case "$words[2]" in
    enter|setup|ssh|key|rm)
      _describe -t vms 'VM' vms
      ;;
    gpg)
      if (( CURRENT == 3 )); then
        _values 'gpg command' create install revoke
      else
        _describe -t vms 'VM' vms
        _values 'gpg option' --expire --signing-key
      fi
      ;;
    completion)
      _values 'shell' bash zsh
      ;;
  esac
}

compdef _dvm __DVM_COMMAND__
EOF
}

dvm_completion() {
	case "${1:-zsh}" in
	zsh) dvm_completion_zsh ;;
	*) dvm_die "usage: dvm completion zsh" ;;
	esac
}
