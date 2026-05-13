# Description: zsh shell, set as login shell for the primary user
dvm_pkg zsh shadow-utils
zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [ "$current_shell" != "$zsh_path" ]; then
    sudo usermod --shell "$zsh_path" "$(id -un)"
fi
