dvm_pkg gnupg2 git

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
    if [ -d "$DVM_CODE_DIR/.git" ]; then
        dvm_as_user git -C "$DVM_CODE_DIR" config user.signingkey "$key_id"
        dvm_as_user git -C "$DVM_CODE_DIR" config commit.gpgsign true
    else
        printf 'dvm recipe gpg-keys: no project Git repo yet; not enabling global signing\n'
    fi
    if [ "$created" = 1 ]; then
        dvm_as_user gpg --armor --export "$key_id" || true
    fi
fi
