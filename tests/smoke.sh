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

write_mock() {
	local name
	name="$1"
	cat >"$MOCK_BIN/$name"
}

write_mocks() {
	write_mock sudo <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
"$@"
MOCK

	write_mock dnf5 <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'dnf5 %s\n' "$*" >>"$DVM_TEST_LOG"
MOCK

	write_mock journalctl <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'journalctl %s\n' "$*" >>"$DVM_TEST_LOG"
printf 'mock journalctl %s\n' "$*"
MOCK

	write_mock ssh-keygen <<'MOCK'
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

	write_mock gpg <<'MOCK'
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

	write_mock limactl <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

add_vm() {
	local vm
	vm="$1"
	touch "$DVM_TEST_LIST"
	grep -Fxq "$vm" "$DVM_TEST_LIST" || printf '%s\n' "$vm" >>"$DVM_TEST_LIST"
}

write_port_forward() {
	local guest host host_ip rest spec vm
	vm="$1"
	spec="$2"
	host="${spec%%:*}"
	rest="${spec#*:}"
	guest="${rest%%,*}"
	host_ip="127.0.0.1"
	case "$spec" in
	*,hostIP=*) host_ip="${spec##*,hostIP=}" ;;
	esac
	mkdir -p "$DVM_TEST_VM_HOME/$vm"
	if [ ! -f "$DVM_TEST_VM_HOME/$vm/lima.yaml" ]; then
		printf 'portForwards:\n' >"$DVM_TEST_VM_HOME/$vm/lima.yaml"
	fi
	cat >>"$DVM_TEST_VM_HOME/$vm/lima.yaml" <<YAML
- hostPort: $host
  hostIP: $host_ip
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
	local expr guest host host_ip log_prefix object port static vm
	vm="$1"
	expr="$2"
	log_prefix="${3:-edit-port-forward}"
	rm -f "$DVM_TEST_VM_HOME/$vm/lima.yaml"
	if printf '%s\n' "$expr" | grep -Fq '"ignore":true'; then
		printf 'ignore-port 5355\n' >>"$DVM_TEST_LOG"
		write_ignore_port "$vm" 5355
	fi
	while IFS= read -r object; do
		host="$(printf '%s\n' "$object" | sed -n 's/.*"hostPort":\([0-9][0-9]*\).*/\1/p')"
		guest="$(printf '%s\n' "$object" | sed -n 's/.*"guestPort":\([0-9][0-9]*\).*/\1/p')"
		[ -n "$host" ] && [ -n "$guest" ] || continue
		port="$host:$guest"
		[ "$port" = "5355:5355" ] && continue
		host_ip="$(printf '%s\n' "$object" | sed -n 's/.*"hostIP":"\([^"]*\)".*/\1/p')"
		host_ip="${host_ip:-127.0.0.1}"
		static="false"
		case "$object" in
		*'"static":true'*) static="true" ;;
		esac
		printf '%s %s,static=%s,hostIP=%s\n' "$log_prefix" "$port" "$static" "$host_ip" >>"$DVM_TEST_LOG"
		write_port_forward "$vm" "$port,static=$static,hostIP=$host_ip"
	done < <(
		printf '%s\n' "$expr" |
			tr '{}' '\n'
	)
}

case "${1:-}" in
--version)
	printf 'limactl mock\n'
	;;
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
			*portForwards*)
				write_port_forwards_from_expr "$vm" "$2" port-forward
				;;
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
}

write_mocks
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
"$TMP/local-bin/dvm-test" version >"$TMP/version.out"
grep -Eq '^dvm ' "$TMP/version.out"

"$TMP/local-bin/dvm-test" init app >/dev/null 2>&1
[ -f "$DVM_CONFIG/vms/app.sh" ]
"$TMP/local-bin/dvm-test" init ai >/dev/null 2>&1
grep -Fq 'Llama VM example' "$DVM_CONFIG/vms/ai.sh"
"$TMP/local-bin/dvm-test" init cloudflared >/dev/null 2>&1
grep -Fq 'cloudflared VM example' "$DVM_CONFIG/vms/cloudflared.sh"

"$TMP/local-bin/dvm-test" init empty >/dev/null 2>&1
cat >"$DVM_CONFIG/vms/empty.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-empty/home"
CONFIG
"$TMP/local-bin/dvm-test" create empty >/dev/null 2>&1
grep -Fq 'create dvm-empty' "$LOG"
grep -Fq 'ignore-port 5355' "$LOG"

cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_SETUP_SCRIPTS=""
CONFIG
"$TMP/local-bin/dvm-test" init defaults >/dev/null 2>&1
cat >"$DVM_CONFIG/vms/defaults.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-defaults/home"
CONFIG
"$TMP/local-bin/dvm-test" create defaults >/dev/null 2>&1
[ -d "$VM_HOME_ROOT/dvm-defaults/home/code/defaults" ]
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
dvm_recipe_validate_port TEST_PORT 1234
dnf5 install -y git ripgrep
printf 'script:%s\n' "$DVM_NAME" >"$HOME/script-ran"
printf 'custom:%s\n' "$DVM_CUSTOM_VALUE" >"$HOME/custom-ran"
SCRIPT
cat >"$DVM_CONFIG/vms/app.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-app/home"
DVM_CUSTOM_VALUE="recipe-env"
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
grep -Fq 'port-forward 3000:3000,static=true,hostIP=127.0.0.1' "$LOG"
grep -Fq 'port-forward 5173:5173,static=true,hostIP=127.0.0.1' "$LOG"
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
DVM_CUSTOM_VALUE="recipe-env"
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
grep -Fq 'edit-port-forward 8080:8080,static=true,hostIP=127.0.0.1' "$LOG"
grep -Fq 'dnf5 install -y git ripgrep' "$LOG"
"$TMP/local-bin/dvm-test" list >"$TMP/list-long-reconfigured.out"
grep -Fq '3000:3000,5173:5173,8080:8080' "$TMP/list-long-reconfigured.out"
"$TMP/local-bin/dvm-test" status app >"$TMP/status.out"
grep -Fq 'name: app' "$TMP/status.out"
grep -Fq 'status: Running' "$TMP/status.out"
grep -Fq 'ports: 3000:3000,5173:5173,8080:8080' "$TMP/status.out"
grep -Fq 'host-ip: 127.0.0.1' "$TMP/status.out"
"$TMP/local-bin/dvm-test" logs app dvm-llama.service >"$TMP/logs.out"
grep -Fq 'mock journalctl -u dvm-llama.service --no-pager -n 100' "$TMP/logs.out"
grep -Fq 'journalctl -u dvm-llama.service --no-pager -n 100' "$LOG"
"$TMP/local-bin/dvm-test" doctor app >"$TMP/doctor.out"
grep -Fq 'doctor:' "$TMP/doctor.out"

cp "$DVM_CONFIG/vms/app.sh" "$DVM_CONFIG/vms/app.safe.sh"
cat >"$DVM_CONFIG/vms/app.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-app/home"
DVM_CUSTOM_VALUE="recipe-env"
DVM_HOST_IP="0.0.0.0"
DVM_PORTS="3000:3000 5173:5173 8080:8080"
DVM_DOTFILES_DIR="$TMP/dotfiles"
DVM_DOTFILES_TARGET="\$DVM_GUEST_HOME/.dotfiles"
DVM_SETUP_SCRIPTS="app.sh"
CONFIG
"$TMP/local-bin/dvm-test" setup app >/dev/null 2>&1
grep -Fq 'edit-port-forward 8080:8080,static=true,hostIP=0.0.0.0' "$LOG"
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
DVM_PORTS="0099:99"
CONFIG
if "$TMP/local-bin/dvm-test" setup app >/dev/null 2>"$TMP/leading-zero-port.err"; then
	echo "setup unexpectedly accepted a leading-zero host port" >&2
	exit 1
fi
grep -Fq 'invalid host port: 0099' "$TMP/leading-zero-port.err"
cat >"$DVM_CONFIG/vms/app.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-app/home"
DVM_PORTS="3000:3000 5173:5173 8080:8080"
DVM_DOTFILES_DIR="$TMP/dotfiles"
DVM_DOTFILES_TARGET="\$DVM_GUEST_HOME/.ssh/dotfiles"
CONFIG
if "$TMP/local-bin/dvm-test" setup app >/dev/null 2>"$TMP/bad-dotfiles-target.err"; then
	echo "setup unexpectedly accepted a dotfiles target under .ssh" >&2
	exit 1
fi
grep -Fq 'unsafe DVM_DOTFILES_TARGET' "$TMP/bad-dotfiles-target.err"
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
"$TMP/local-bin/dvm-test" ssh app bash -lc 'cd "$HOME/code/app"; pwd' >"$TMP/code-pwd.out"
grep -Fxq "$VM_HOME_ROOT/dvm-app/home/code/app" "$TMP/code-pwd.out"
"$TMP/local-bin/dvm-test" ssh-key app >"$TMP/ssh-key.out"
grep -Fxq 'ssh-ed25519 public-key' "$TMP/ssh-key.out"
grep -Fq 'Host github.com' "$VM_HOME_ROOT/dvm-app/home/.ssh/config"
grep -Fq 'IdentityFile '"$VM_HOME_ROOT/dvm-app/home"'/.ssh/id_ed25519_dvm' "$VM_HOME_ROOT/dvm-app/home/.ssh/config"
grep -Fq 'format = ssh' "$VM_HOME_ROOT/dvm-app/home/.config/git/config"
grep -Fq 'signingkey = '"$VM_HOME_ROOT/dvm-app/home"'/.ssh/id_ed25519_dvm.pub' "$VM_HOME_ROOT/dvm-app/home/.config/git/config"
grep -Fq 'gpgsign = true' "$VM_HOME_ROOT/dvm-app/home/.config/git/config"
"$TMP/local-bin/dvm-test" gpg-key app >"$TMP/gpg-key.out"
grep -Fq 'BEGIN PGP PUBLIC KEY BLOCK' "$TMP/gpg-key.out"
grep -Fq 'fingerprint: ABCDEF1234567890' "$TMP/gpg-key.out"

cat >"$DVM_CONFIG/vms/bad.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-bad/home"
DVM_SETUP_SCRIPTS=""
CONFIG
"$TMP/local-bin/dvm-test" create bad >/dev/null 2>&1
cat >"$DVM_CONFIG/vms/zok.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-zok/home"
DVM_SETUP_SCRIPTS=""
dvm_vm_setup() {
	printf 'setup-all:%s\n' "\$DVM_NAME" >"\$HOME/setup-all-ran"
}
CONFIG
"$TMP/local-bin/dvm-test" create zok >/dev/null 2>&1
rm -f "$VM_HOME_ROOT/dvm-zok/home/setup-all-ran"
cat >"$DVM_CONFIG/vms/bad.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-bad/home"
DVM_SETUP_SCRIPTS=""
dvm_vm_setup() {
	false
}
CONFIG
if "$TMP/local-bin/dvm-test" setup-all >/dev/null 2>"$TMP/setup-all-partial.err"; then
	echo "setup-all unexpectedly ignored a failing VM" >&2
	exit 1
fi
grep -Fxq 'setup-all:zok' "$VM_HOME_ROOT/dvm-zok/home/setup-all-ran"
grep -Fq 'setup failed: bad' "$TMP/setup-all-partial.err"
grep -Fq 'setup-all: ' "$TMP/setup-all-partial.err"
grep -Fq 'failed: bad' "$TMP/setup-all-partial.err"
cat >"$DVM_CONFIG/vms/bad.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-bad/home"
DVM_SETUP_SCRIPTS=""
CONFIG

"$TMP/local-bin/dvm-test" setup-all >/dev/null 2>&1
grep -Fxq 'inline:app' "$VM_HOME_ROOT/dvm-app/home/inline-ran"
rm -f "$VM_HOME_ROOT/dvm-zok/home/upgrade-all-ran"
cat >"$DVM_CONFIG/vms/zok.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-zok/home"
DVM_SETUP_SCRIPTS=""
dvm_vm_setup() {
	printf 'upgrade-all:%s\n' "\$DVM_NAME" >"\$HOME/upgrade-all-ran"
}
CONFIG
cat >"$DVM_CONFIG/vms/bad.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-bad/home"
DVM_SETUP_SCRIPTS=""
dvm_vm_setup() {
	false
}
CONFIG
if "$TMP/local-bin/dvm-test" upgrade-all >/dev/null 2>"$TMP/upgrade-all-partial.err"; then
	echo "upgrade-all unexpectedly ignored a failing VM" >&2
	exit 1
fi
grep -Fxq 'upgrade-all:zok' "$VM_HOME_ROOT/dvm-zok/home/upgrade-all-ran"
grep -Fq 'upgrade failed: bad' "$TMP/upgrade-all-partial.err"
grep -Fq 'upgrade-all: ' "$TMP/upgrade-all-partial.err"
grep -Fq 'failed: bad' "$TMP/upgrade-all-partial.err"
cat >"$DVM_CONFIG/vms/bad.sh" <<CONFIG
DVM_GUEST_HOME="$VM_HOME_ROOT/dvm-bad/home"
DVM_SETUP_SCRIPTS=""
CONFIG
"$TMP/local-bin/dvm-test" upgrade-all >/dev/null 2>&1
grep -Fq 'dnf5 upgrade -y' "$LOG"

"$TMP/local-bin/dvm-test" rm app --force
"$TMP/local-bin/dvm-test" list >"$TMP/list-after-rm.out"
if grep -Fxq app "$TMP/list-after-rm.out"; then
	echo "deleted VM still listed" >&2
	exit 1
fi
