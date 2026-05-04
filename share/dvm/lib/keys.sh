# shellcheck shell=bash

ssh_key_vm() {
	local name
	name="${1:-}"
	[ -n "$name" ] || die "ssh-key requires a VM name"
	load_vm "$name"
	vm_exists || die "VM does not exist: $DVM_LIMA_NAME; run dvm apply $name first"
	start_vm
	limactl shell "$DVM_LIMA_NAME" env "DVM_NAME=$DVM_NAME" bash -s <<'DVM_SSH_KEY'
set -euo pipefail
if command -v dnf5 >/dev/null 2>&1; then
	sudo dnf5 install -y git openssh-clients >/dev/null
fi
key="$HOME/.ssh/id_ed25519_dvm"
signing_key="$HOME/.ssh/id_ed25519_dvm_signing"
config="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ ! -f "$key" ]; then
	ssh-keygen -t ed25519 -C "$DVM_NAME-dvm-github-access" -f "$key" -N ""
fi
if [ ! -f "$signing_key" ]; then
	ssh-keygen -t ed25519 -C "$DVM_NAME-dvm-git-signing" -f "$signing_key" -N ""
fi
write_public_key() {
	private_key="$1"
	public_key="$private_key.pub"
	tmp="$(mktemp "${public_key}.XXXXXX")"
	if ssh-keygen -y -f "$private_key" >"$tmp" && mv "$tmp" "$public_key"; then
		return 0
	fi
	rm -f "$tmp"
	return 1
}
[ -s "$key.pub" ] || write_public_key "$key"
[ -s "$signing_key.pub" ] || write_public_key "$signing_key"
touch "$config"
chmod 600 "$config"
if ! grep -Eq "^[[:space:]]*IdentityFile[[:space:]]+$key([[:space:]]|$)" "$config"; then
	{
		printf "\nHost github.com\n"
		printf "  HostName github.com\n"
		printf "  User git\n"
		printf "  IdentityFile %s\n" "$key"
		printf "  IdentitiesOnly yes\n"
		printf "  AddKeysToAgent no\n"
	} >>"$config"
fi
if command -v git >/dev/null 2>&1; then
	git_config="$HOME/.config/git/config"
	mkdir -p "$(dirname "$git_config")"
	GIT_CONFIG_GLOBAL="$git_config" git config --global gpg.format ssh
	GIT_CONFIG_GLOBAL="$git_config" git config --global user.signingkey "$signing_key.pub"
	GIT_CONFIG_GLOBAL="$git_config" git config --global commit.gpgsign true
fi
printf 'GitHub access key public key (use as deploy key or account authentication key):\n'
cat "$key.pub"
printf '\nGit commit signing public key (add to GitHub account as SSH signing key):\n'
cat "$signing_key.pub"
DVM_SSH_KEY
}

gpg_key_vm() {
	local name
	name="${1:-}"
	[ -n "$name" ] || die "gpg-key requires a VM name"
	load_vm "$name"
	vm_exists || die "VM does not exist: $DVM_LIMA_NAME; run dvm apply $name first"
	start_vm
	limactl shell "$DVM_LIMA_NAME" env "DVM_NAME=$DVM_NAME" bash -s <<'DVM_GPG_KEY'
set -euo pipefail
if command -v dnf5 >/dev/null 2>&1; then
	sudo dnf5 install -y gnupg2 >/dev/null
fi
uid="$DVM_NAME dvm <dvm-$DVM_NAME@local>"
if ! gpg --list-secret-keys "$uid" >/dev/null 2>&1; then
	gpg --batch --passphrase "" --quick-gen-key "$uid" ed25519 sign 1y
fi
gpg --armor --export "$uid"
gpg --with-colons --list-secret-keys "$uid" | awk -F: '$1 == "fpr" { print "fingerprint: " $10; exit }'
DVM_GPG_KEY
}
