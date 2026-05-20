dvm_pkg gnupg2

home="$(dvm_user_home)"
sudo install -d -o "$DVM_USER" -g "$(dvm_user_group "$DVM_USER")" -m 0700 "$home/.gnupg"

created=0
if ! dvm_as_user gpg --list-secret-keys --with-colons | grep -q '^sec'; then
    dvm_as_user gpg --batch --passphrase '' --quick-generate-key \
        "DVM $DVM_NAME <dvm-$DVM_NAME@local>" ed25519 sign 0
    created=1
fi

key_id="$(dvm_as_user gpg --list-secret-keys --with-colons | awk -F: '/^sec/ { print $5; exit }')"
if [ -n "$key_id" ]; then
    dvm_as_user git config --global user.signingkey "$key_id" || true
    dvm_as_user git config --global commit.gpgsign true || true
    if [ "$created" = 1 ]; then
        dvm_as_user gpg --armor --export "$key_id" || true
    fi
fi
