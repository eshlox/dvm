dvm_pkg openssh-clients

home="$(dvm_user_home)"
sudo install -d -o "$DVM_USER" -g "$DVM_USER" -m 0700 "$home/.ssh"
if [ ! -f "$home/.ssh/id_ed25519" ]; then
    dvm_as_user ssh-keygen -t ed25519 -N '' -C "dvm-$DVM_NAME" -f "$home/.ssh/id_ed25519"
    dvm_as_user cat "$home/.ssh/id_ed25519.pub"
fi
