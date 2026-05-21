dvm_pkg zsh

zsh_path="$(command -v zsh)"
# chsh can fail in minimal images; users can still run zsh explicitly.
sudo chsh -s "$zsh_path" "$DVM_USER" || true
home="$(dvm_user_home)"
dvm_append_once "$home/.bashrc" '[ -t 1 ] && command -v zsh >/dev/null 2>&1 && exec zsh'
[ -f "$home/.zshrc" ] || dvm_as_user touch "$home/.zshrc"
