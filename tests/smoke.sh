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
mkdir -p "$HOME"

"$ROOT/install.sh" --prefix "$TMP/local-bin" --name dvm-test --init >/dev/null
[ -L "$TMP/local-bin/dvm-test" ]
[ -f "$DVM_CONFIG/config.sh" ]
[ -f "$DVM_CONFIG/setup.d/fedora.sh" ]

cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-app/code"
DVM_PACKAGES="git openssh-clients gpg helix"
DVM_SETUP_SCRIPTS="$DVM_CONFIG/setup.d/fedora.sh"
DVM_GPG_DIR="$DVM_STATE/gpg"
CONFIG

cat >"$DVM_CONFIG/setup.d/fedora.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$DVM_NAME" >>"$HOME/setup-ran"
SCRIPT

"$TMP/local-bin/dvm-test" new app >"$TMP/new.out"
grep -Fq 'public key for app' "$TMP/new.out"
grep -Fq 'create testvm-app' "$LOG"
grep -Fq 'helix' "$LOG"
grep -Fq 'app' "$VM_HOME_ROOT/testvm-app/setup-ran"

"$TMP/local-bin/dvm-test" list >"$TMP/list.out"
grep -Fxq app "$TMP/list.out"
"$TMP/local-bin/dvm-test" setup-all >/dev/null
[ "$(grep -Fc 'app' "$VM_HOME_ROOT/testvm-app/setup-ran")" -ge 2 ]
"$TMP/local-bin/dvm-test" key app >"$TMP/key.out"
grep -Fq 'ssh-ed25519' "$TMP/key.out"
"$TMP/local-bin/dvm-test" doctor >"$TMP/doctor.out"
grep -Fq "prefix: testvm" "$TMP/doctor.out"

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
