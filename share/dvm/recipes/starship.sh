dvm_pkg starship

home="$(dvm_user_home)"
dvm_append_once "$home/.bashrc" 'eval "$(starship init bash)"'
dvm_append_once "$home/.zshrc" 'eval "$(starship init zsh)"'
