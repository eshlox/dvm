#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MOCK_BIN="$TMP/bin"
VM_HOME_ROOT="$TMP/vm-home"
LIST_FILE="$TMP/limactl-list"
LOG="$TMP/log"
mkdir -p "$MOCK_BIN" "$VM_HOME_ROOT"

cat >"$MOCK_BIN/sudo" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
"$@"
MOCK

cat >"$MOCK_BIN/dnf5" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'dnf5 %s\n' "$*" >>"$DVM_TEST_LOG"
MOCK

cat >"$MOCK_BIN/ssh-keygen" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
out=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	-f)
		out="$2"
		shift
		;;
	esac
	shift
done
[ -n "$out" ]
printf 'private-key\n' >"$out"
printf 'ssh-ed25519 public-key\n' >"$out.pub"
MOCK

cat >"$MOCK_BIN/limactl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

add_vm() {
	local vm
	vm="$1"
	touch "$DVM_TEST_LIST"
	grep -Fxq "$vm" "$DVM_TEST_LIST" || printf '%s\n' "$vm" >>"$DVM_TEST_LIST"
}

case "${1:-}" in
list)
	if [ "${2:-}" = "--format" ]; then
		cat "$DVM_TEST_LIST" 2>/dev/null || true
		exit 0
	fi
	cat "$DVM_TEST_LIST" 2>/dev/null || true
	;;
create)
	vm=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--name)
			vm="$2"
			shift
			;;
		esac
		shift
	done
	[ -n "$vm" ]
	printf 'create %s\n' "$vm" >>"$DVM_TEST_LOG"
	add_vm "$vm"
	;;
start)
	add_vm "$2"
	printf 'start %s\n' "$2" >>"$DVM_TEST_LOG"
	;;
shell)
	vm="$2"
	shift 2
	home="$DVM_TEST_VM_HOME/$vm"
	mkdir -p "$home"
	(
		export HOME="$home"
		export PATH="$DVM_TEST_PATH"
		cd "$home"
		"$@"
	)
	;;
delete)
	shift
	if [ "${1:-}" = "--force" ]; then
		shift
	fi
	vm="$1"
	printf 'delete %s\n' "$vm" >>"$DVM_TEST_LOG"
	grep -Fxv "$vm" "$DVM_TEST_LIST" >"$DVM_TEST_LIST.tmp" || true
	mv "$DVM_TEST_LIST.tmp" "$DVM_TEST_LIST"
	;;
*)
	printf 'unexpected limactl command: %s\n' "$*" >&2
	exit 1
	;;
esac
MOCK

chmod +x "$MOCK_BIN/sudo" "$MOCK_BIN/dnf5" "$MOCK_BIN/ssh-keygen" "$MOCK_BIN/limactl"

export DVM_TEST_LOG="$LOG"
export DVM_TEST_LIST="$LIST_FILE"
export DVM_TEST_VM_HOME="$VM_HOME_ROOT"
export DVM_TEST_PATH="$MOCK_BIN:$PATH"
export PATH="$MOCK_BIN:$PATH"
export HOME="$TMP/home"
export DVM_CONFIG="$TMP/config"
export DVM_STATE="$TMP/state"
export HOST_DOTFILES="$TMP/host-dotfiles"
mkdir -p "$HOME"
mkdir -p "$HOST_DOTFILES/.git" "$HOST_DOTFILES/.ssh" "$HOST_DOTFILES/.gnupg"
printf 'set -o vi\n' >"$HOST_DOTFILES/bashrc"
printf '#!/usr/bin/env bash\n' >"$HOST_DOTFILES/install.sh"
printf 'git metadata\n' >"$HOST_DOTFILES/.git/config"
printf 'secret key\n' >"$HOST_DOTFILES/.ssh/id_ed25519"
printf 'gpg material\n' >"$HOST_DOTFILES/.gnupg/private-keys-v1.d"
printf 'token=1\n' >"$HOST_DOTFILES/.env"
printf 'do not copy\n' >"$HOST_DOTFILES/secrets"

"$ROOT/install.sh" --prefix "$TMP/local-bin" --name dvm-test --init >/dev/null
[ -L "$TMP/local-bin/dvm-test" ]
[ -f "$DVM_CONFIG/config.sh" ]
[ -f "$DVM_CONFIG/setup.d/fedora.sh" ]

cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-app"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-app/code"
DVM_PACKAGES="git openssh-clients gpg helix"
DVM_SETUP_SCRIPTS="$DVM_CONFIG/setup.d/fedora.sh"
DVM_DOTFILES_DIR="$HOST_DOTFILES"
DVM_DOTFILES_TARGET="$VM_HOME_ROOT/testvm-app/.dotfiles"
DVM_GPG_DIR="$DVM_STATE/gpg"
CONFIG

cat >"$DVM_CONFIG/setup.d/fedora.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$DVM_NAME" >>"$HOME/setup-ran"
[ -f "$DVM_DOTFILES_TARGET/install.sh" ]
SCRIPT

"$TMP/local-bin/dvm-test" new app >"$TMP/new.out"
grep -Fq 'public key for app' "$TMP/new.out"
grep -Fq 'create testvm-app' "$LOG"
grep -Fq 'helix' "$LOG"
grep -Fq 'app' "$VM_HOME_ROOT/testvm-app/setup-ran"
[ -f "$VM_HOME_ROOT/testvm-app/.dotfiles/bashrc" ]
[ -f "$VM_HOME_ROOT/testvm-app/.dotfiles/install.sh" ]
[ ! -e "$VM_HOME_ROOT/testvm-app/.dotfiles/.git" ]
[ ! -e "$VM_HOME_ROOT/testvm-app/.dotfiles/.ssh" ]
[ ! -e "$VM_HOME_ROOT/testvm-app/.dotfiles/.gnupg" ]
[ ! -e "$VM_HOME_ROOT/testvm-app/.dotfiles/.env" ]
[ ! -e "$VM_HOME_ROOT/testvm-app/.dotfiles/secrets" ]

"$TMP/local-bin/dvm-test" list >"$TMP/list.out"
grep -Fxq app "$TMP/list.out"
rm -f "$HOST_DOTFILES/bashrc"
printf 'export EDITOR=hx\n' >"$HOST_DOTFILES/zshrc"
"$TMP/local-bin/dvm-test" setup-all >/dev/null
[ "$(grep -Fc 'app' "$VM_HOME_ROOT/testvm-app/setup-ran")" -ge 2 ]
[ ! -e "$VM_HOME_ROOT/testvm-app/.dotfiles/bashrc" ]
[ -f "$VM_HOME_ROOT/testvm-app/.dotfiles/zshrc" ]
"$TMP/local-bin/dvm-test" key app >"$TMP/key.out"
grep -Fq 'ssh-ed25519' "$TMP/key.out"
"$TMP/local-bin/dvm-test" doctor >"$TMP/doctor.out"
grep -Fq "prefix: testvm" "$TMP/doctor.out"

cp "$DVM_CONFIG/config.sh" "$DVM_CONFIG/config.safe.sh"
cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-app"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-app/code"
DVM_PACKAGES="git openssh-clients gpg helix"
DVM_SETUP_SCRIPTS="$DVM_CONFIG/setup.d/fedora.sh"
DVM_DOTFILES_DIR="$HOME"
DVM_DOTFILES_TARGET="$VM_HOME_ROOT/testvm-app/.dotfiles"
DVM_GPG_DIR="$DVM_STATE/gpg"
CONFIG
if "$TMP/local-bin/dvm-test" setup app >"$TMP/dangerous.out" 2>"$TMP/dangerous.err"; then
	echo "setup unexpectedly succeeded with dangerous dotfiles dir" >&2
	exit 1
fi
grep -Fq 'refusing dangerous DVM_DOTFILES_DIR' "$TMP/dangerous.err"
mv "$DVM_CONFIG/config.safe.sh" "$DVM_CONFIG/config.sh"

mkdir -p "$VM_HOME_ROOT/testvm-app/code/repo"
git -C "$VM_HOME_ROOT/testvm-app/code/repo" init -q
printf 'dirty\n' >"$VM_HOME_ROOT/testvm-app/code/repo/file.txt"
if "$TMP/local-bin/dvm-test" rm app 2>"$TMP/rm.err"; then
	echo "delete unexpectedly succeeded with dirty repo" >&2
	exit 1
fi
grep -Fq 'dirty repository' "$TMP/rm.err"
mkdir -p "$DVM_STATE/gpg"
cat >"$DVM_STATE/gpg/app.env" <<'GPG'
PRIMARY_FPR='PRIMARY123'
SUBKEY_FPR='SUBKEY456'
GPG
"$TMP/local-bin/dvm-test" rm app --force >/dev/null 2>"$TMP/rm-force.err"
grep -Fq 'SUBKEY456' "$TMP/rm-force.err"
grep -Fq 'dvm gpg revoke app' "$TMP/rm-force.err"
"$TMP/local-bin/dvm-test" list >"$TMP/list-after-rm.out"
if grep -Fxq app "$TMP/list-after-rm.out"; then
	echo "deleted VM still listed" >&2
	exit 1
fi

"$TMP/local-bin/dvm-test" completion zsh >"$TMP/completion.zsh"
grep -Fq 'compdef _dvm dvm-test' "$TMP/completion.zsh"
