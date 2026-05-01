#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MOCK_BIN="$TMP/bin"
VM_HOME_ROOT="$TMP/vms"
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
	-f) out="$2"; shift ;;
	esac
	shift
done
[ -n "$out" ]
printf 'private-key\n' >"$out"
printf 'ssh-ed25519 public-key\n' >"$out.pub"
MOCK

cat >"$MOCK_BIN/gpg" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
state="$HOME/.gnupg/dvm-test-key"
mkdir -p "$HOME/.gnupg"
case "$*" in
*--quick-gen-key*)
	printf 'key\n' >"$state"
	;;
*--armor\ --export*)
	printf '%s\n' '-----BEGIN PGP PUBLIC KEY BLOCK-----' mock '-----END PGP PUBLIC KEY BLOCK-----'
	;;
*--with-colons*)
	printf 'fpr:::::::::ABCDEF1234567890:\n'
	;;
*--list-secret-keys*)
	[ -f "$state" ]
	;;
*)
	printf 'unexpected gpg %s\n' "$*" >&2
	exit 1
	;;
esac
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

write_port_forward() {
	local guest host rest spec vm
	vm="$1"
	spec="$2"
	host="${spec%%:*}"
	rest="${spec#*:}"
	guest="${rest%%,*}"
	mkdir -p "$DVM_TEST_VM_HOME/$vm"
	if [ ! -f "$DVM_TEST_VM_HOME/$vm/lima.yaml" ]; then
		printf 'portForwards:\n' >"$DVM_TEST_VM_HOME/$vm/lima.yaml"
	fi
	cat >>"$DVM_TEST_VM_HOME/$vm/lima.yaml" <<YAML
- hostPort: $host
  guestPort: $guest
YAML
}

write_ignore_port() {
	local guest vm
	vm="$1"
	guest="$2"
	mkdir -p "$DVM_TEST_VM_HOME/$vm"
	if [ ! -f "$DVM_TEST_VM_HOME/$vm/lima.yaml" ]; then
		printf 'portForwards:\n' >"$DVM_TEST_VM_HOME/$vm/lima.yaml"
	fi
	cat >>"$DVM_TEST_VM_HOME/$vm/lima.yaml" <<YAML
- guestPort: $guest
  proto: any
  ignore: true
YAML
}

write_port_forwards_from_expr() {
	local expr port vm
	vm="$1"
	expr="$2"
	rm -f "$DVM_TEST_VM_HOME/$vm/lima.yaml"
	if printf '%s\n' "$expr" | grep -Fq '"ignore":true'; then
		printf 'ignore-port 5355\n' >>"$DVM_TEST_LOG"
		write_ignore_port "$vm" 5355
	fi
	while IFS= read -r port; do
		[ -n "$port" ] || continue
		[ "$port" = "5355:5355" ] && continue
		write_port_forward "$vm" "$port,static=true"
	done < <(
		printf '%s\n' "$expr" |
			tr '{}' '\n' |
			sed -n 's/.*"hostPort":\([0-9][0-9]*\).*"guestPort":\([0-9][0-9]*\).*/\1:\2/p'
	)
}

case "${1:-}" in
list)
	if [ "${2:-}" = "--format" ]; then
		case "${3:-}" in
		*Status*Dir*)
			while IFS= read -r vm; do
				[ -n "$vm" ] || continue
				printf '%s\tRunning\t%s/%s\n' "$vm" "$DVM_TEST_VM_HOME" "$vm"
			done <"$DVM_TEST_LIST" 2>/dev/null || true
			;;
		*)
			cat "$DVM_TEST_LIST" 2>/dev/null || true
			;;
		esac
	else
		cat "$DVM_TEST_LIST" 2>/dev/null || true
	fi
	;;
create)
	vm=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--name)
			vm="$2"
			shift
			;;
		--port-forward)
			write_port_forward "$vm" "$2"
			printf 'port-forward %s\n' "$2" >>"$DVM_TEST_LOG"
			shift
			;;
		--set)
			case "$2" in
			*'"guestPort":5355'*'"ignore":true'* | *'"ignore":true'*'"guestPort":5355'*)
				printf 'ignore-port 5355\n' >>"$DVM_TEST_LOG"
				write_ignore_port "$vm" 5355
				;;
			esac
			shift
			;;
		esac
		shift
	done
	[ -n "$vm" ]
	printf 'create %s\n' "$vm" >>"$DVM_TEST_LOG"
	add_vm "$vm"
	;;
edit)
	vm=""
	set_expr=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--set)
			set_expr="$2"
			shift
			;;
		--tty=*)
			;;
		--start)
			;;
		*)
			vm="$1"
			;;
		esac
		shift
	done
	[ -n "$vm" ]
	printf 'edit %s\n' "$vm" >>"$DVM_TEST_LOG"
	write_port_forwards_from_expr "$vm" "$set_expr"
	add_vm "$vm"
	;;
start)
	add_vm "$2"
	printf 'start %s\n' "$2" >>"$DVM_TEST_LOG"
	;;
stop)
	printf 'stop %s\n' "$2" >>"$DVM_TEST_LOG"
	;;
shell)
	vm="$2"
	shift 2
	home="$DVM_TEST_VM_HOME/$vm/home"
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
	[ "${1:-}" = "--force" ] && shift
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

chmod +x "$MOCK_BIN"/*

export DVM_TEST_LOG="$LOG"
export DVM_TEST_LIST="$LIST_FILE"
export DVM_TEST_VM_HOME="$VM_HOME_ROOT"
export DVM_TEST_PATH="$MOCK_BIN:$PATH"
export PATH="$DVM_TEST_PATH"
export HOME="$TMP/home"
export DVM_CONFIG="$TMP/config"
export DVM_STATE="$TMP/state"
mkdir -p "$HOME"

"$ROOT/install.sh" --prefix "$TMP/local-bin" --name dvm-test --init >/dev/null 2>&1
[ -L "$TMP/local-bin/dvm-test" ]
[ -f "$DVM_CONFIG/config.sh" ]

"$TMP/local-bin/dvm-test" init app >/dev/null 2>&1
[ -f "$DVM_CONFIG/vms/app.sh" ]
"$TMP/local-bin/dvm-test" init ai >/dev/null 2>&1
grep -Fq 'Llama VM example' "$DVM_CONFIG/vms/ai.sh"
"$TMP/local-bin/dvm-test" init cloudflared >/dev/null 2>&1
grep -Fq 'cloudflared VM example' "$DVM_CONFIG/vms/cloudflared.sh"

"$TMP/local-bin/dvm-test" init empty >/dev/null 2>&1
cat >"$DVM_CONFIG/vms/empty.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-empty/home"
DVM_CODE_DIR="\$DVM_GUEST_HOME/code"
CONFIG
"$TMP/local-bin/dvm-test" create empty >/dev/null 2>&1
grep -Fq 'create dvm-empty' "$LOG"
grep -Fq 'ignore-port 5355' "$LOG"

cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PACKAGES="git helix"
DVM_SETUP_SCRIPTS=""
CONFIG
"$TMP/local-bin/dvm-test" init defaults >/dev/null 2>&1
cat >"$DVM_CONFIG/vms/defaults.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-defaults/home"
DVM_CODE_DIR="\$DVM_GUEST_HOME/code"
DVM_PACKAGES="\$DVM_PACKAGES jq"
CONFIG
"$TMP/local-bin/dvm-test" create defaults >/dev/null 2>&1
grep -Fq 'dnf5 install -y git helix jq' "$LOG"
cat >"$DVM_CONFIG/config.sh" <<'CONFIG'
# test reset
CONFIG

mkdir -p "$DVM_CONFIG/recipes" "$TMP/dotfiles"
printf 'set -o vi\n' >"$TMP/dotfiles/bashrc"
printf 'secret\n' >"$TMP/dotfiles/.env"
printf 'private\n' >"$TMP/dotfiles/private.sh"
cat >"$DVM_CONFIG/recipes/app.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'script:%s\n' "$DVM_NAME" >"$HOME/script-ran"
printf 'custom:%s\n' "$DVM_CUSTOM_VALUE" >"$HOME/custom-ran"
SCRIPT
cat >"$DVM_CONFIG/vms/app.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-app/home"
DVM_CODE_DIR="\$DVM_GUEST_HOME/code"
DVM_CUSTOM_VALUE="recipe-env"
DVM_PACKAGES="git ripgrep"
DVM_PORTS="3000:3000 5173:5173"
DVM_DOTFILES_DIR="$TMP/dotfiles"
DVM_DOTFILES_TARGET="\$DVM_GUEST_HOME/.dotfiles"
DVM_SETUP_SCRIPTS="app.sh"
dvm_vm_setup() {
	printf 'inline:%s\n' "\$DVM_NAME" >"\$HOME/inline-ran"
}
CONFIG

"$TMP/local-bin/dvm-test" create app >/dev/null 2>&1
grep -Fq 'create dvm-app' "$LOG"
grep -Fq 'port-forward 3000:3000,static=true' "$LOG"
grep -Fq 'port-forward 5173:5173,static=true' "$LOG"
grep -Fq 'dnf5 install -y git ripgrep' "$LOG"
grep -Fxq 'script:app' "$VM_HOME_ROOT/dvm-app/home/script-ran"
grep -Fxq 'custom:recipe-env' "$VM_HOME_ROOT/dvm-app/home/custom-ran"
grep -Fxq 'inline:app' "$VM_HOME_ROOT/dvm-app/home/inline-ran"
[ -f "$VM_HOME_ROOT/dvm-app/home/.dotfiles/bashrc" ]
[ ! -e "$VM_HOME_ROOT/dvm-app/home/.dotfiles/.env" ]
[ ! -e "$VM_HOME_ROOT/dvm-app/home/.dotfiles/private.sh" ]

"$TMP/local-bin/dvm-test" list >"$TMP/list.out"
grep -Fq app "$TMP/list.out"
grep -Fq '3000:3000,5173:5173' "$TMP/list.out"
if grep -Fq '5355' "$TMP/list.out"; then
	echo "ignored port 5355 leaked into dvm list output" >&2
	exit 1
fi

cat >"$DVM_CONFIG/vms/app.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-app/home"
DVM_CODE_DIR="\$DVM_GUEST_HOME/code"
DVM_CUSTOM_VALUE="recipe-env"
DVM_PACKAGES="git ripgrep jq"
DVM_PORTS="3000:3000 5173:5173 8080:8080"
DVM_DOTFILES_DIR="$TMP/dotfiles"
DVM_DOTFILES_TARGET="\$DVM_GUEST_HOME/.dotfiles"
DVM_SETUP_SCRIPTS="app.sh"
dvm_vm_setup() {
	printf 'inline:%s\n' "\$DVM_NAME" >"\$HOME/inline-ran"
}
CONFIG
"$TMP/local-bin/dvm-test" setup app >/dev/null 2>&1
grep -Fq 'stop dvm-app' "$LOG"
grep -Fq 'edit dvm-app' "$LOG"
grep -Fq 'dnf5 install -y git ripgrep jq' "$LOG"
"$TMP/local-bin/dvm-test" list >"$TMP/list-long-reconfigured.out"
grep -Fq '3000:3000,5173:5173,8080:8080' "$TMP/list-long-reconfigured.out"

cp "$DVM_CONFIG/vms/app.sh" "$DVM_CONFIG/vms/app.safe.sh"
cat >"$DVM_CONFIG/vms/app.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-app/home"
DVM_PORTS=":8080"
CONFIG
if "$TMP/local-bin/dvm-test" setup app >/dev/null 2>"$TMP/bad-port.err"; then
	echo "setup unexpectedly accepted an empty host port" >&2
	exit 1
fi
grep -Fq 'invalid host port' "$TMP/bad-port.err"
cat >"$DVM_CONFIG/vms/app.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-app/home"
DVM_PORTS="3000:3000 5173:5173 8080:8080"
dvm_vm_setup() {
	false
	printf 'bad\n' >"\$HOME/strict-ran"
}
CONFIG
if "$TMP/local-bin/dvm-test" setup app >/dev/null 2>"$TMP/strict.err"; then
	echo "setup unexpectedly ignored a failing inline setup command" >&2
	exit 1
fi
[ ! -e "$VM_HOME_ROOT/dvm-app/home/strict-ran" ]
mv "$DVM_CONFIG/vms/app.safe.sh" "$DVM_CONFIG/vms/app.sh"

"$TMP/local-bin/dvm-test" ssh app pwd >"$TMP/pwd.out"
grep -Fxq "$VM_HOME_ROOT/dvm-app/home" "$TMP/pwd.out"
# shellcheck disable=SC2016
"$TMP/local-bin/dvm-test" ssh app bash -lc 'cd "$HOME/code"; pwd' >"$TMP/code-pwd.out"
grep -Fxq "$VM_HOME_ROOT/dvm-app/home/code" "$TMP/code-pwd.out"
"$TMP/local-bin/dvm-test" ssh-key app >"$TMP/ssh-key.out"
grep -Fxq 'ssh-ed25519 public-key' "$TMP/ssh-key.out"
grep -Fq 'Host github.com' "$VM_HOME_ROOT/dvm-app/home/.ssh/config"
grep -Fq 'IdentityFile '"$VM_HOME_ROOT/dvm-app/home"'/.ssh/id_ed25519_dvm' "$VM_HOME_ROOT/dvm-app/home/.ssh/config"
"$TMP/local-bin/dvm-test" gpg-key app >"$TMP/gpg-key.out"
grep -Fq 'BEGIN PGP PUBLIC KEY BLOCK' "$TMP/gpg-key.out"
grep -Fq 'fingerprint: ABCDEF1234567890' "$TMP/gpg-key.out"

"$TMP/local-bin/dvm-test" setup-all >/dev/null 2>&1
grep -Fxq 'inline:app' "$VM_HOME_ROOT/dvm-app/home/inline-ran"
"$TMP/local-bin/dvm-test" upgrade-all >/dev/null 2>&1
grep -Fq 'dnf5 upgrade -y' "$LOG"

"$TMP/local-bin/dvm-test" rm app --force
"$TMP/local-bin/dvm-test" list >"$TMP/list-after-rm.out"
if grep -Fxq app "$TMP/list-after-rm.out"; then
	echo "deleted VM still listed" >&2
	exit 1
fi
