#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MOCK_BIN="$TMP/bin"
VM_HOME_ROOT="$TMP/vm-home"
LIST_FILE="$TMP/limactl-list"
LOG="$TMP/log"
AGENT_USER_FILE="$TMP/agent-user"
mkdir -p "$MOCK_BIN" "$VM_HOME_ROOT"

cat >"$MOCK_BIN/sudo" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
while [ "$#" -gt 0 ]; do
	case "$1" in
	-H)
		shift
		;;
	-u)
		shift 2
		;;
	--)
		shift
		break
		;;
	-*)
		shift
		;;
	*)
		break
		;;
	esac
done
"$@"
MOCK

cat >"$MOCK_BIN/dnf5" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'dnf5 %s\n' "$*" >>"$DVM_TEST_LOG"
MOCK

cat >"$MOCK_BIN/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
out=""
url=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	-o)
		out="$2"
		shift
		;;
	http://* | https://*)
		url="$1"
		;;
	esac
	shift
done
[ -n "$out" ]
[ -n "$url" ]
mkdir -p "$(dirname "$out")"
printf 'model from %s\n' "$url" >"$out"
MOCK

cat >"$MOCK_BIN/sha256sum" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'sha256sum %s\n' "$*" >>"$DVM_TEST_LOG"
if [ "${1:-}" = "-c" ]; then
	cat >/dev/null
fi
MOCK

cat >"$MOCK_BIN/systemctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl %s\n' "$*" >>"$DVM_TEST_LOG"
case "${1:-}" in
is-active)
	printf 'active\n'
	;;
is-enabled)
	printf 'enabled\n'
	;;
esac
MOCK

cat >"$MOCK_BIN/llama-server" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'llama-server %s\n' "$*" >>"$DVM_TEST_LOG"
MOCK

cat >"$MOCK_BIN/useradd" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'useradd %s\n' "$*" >>"$DVM_TEST_LOG"
user="${*: -1}"
printf '%s\n' "$user" >"$DVM_TEST_AGENT_USER"
MOCK

cat >"$MOCK_BIN/id" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "-u" ] && [ "$#" -eq 2 ] &&
	[ -f "$DVM_TEST_AGENT_USER" ] &&
	[ "$2" = "$(cat "$DVM_TEST_AGENT_USER")" ]; then
	printf '1001\n'
	exit 0
fi
exec /usr/bin/id "$@"
MOCK

cat >"$MOCK_BIN/chown" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'chown %s\n' "$*" >>"$DVM_TEST_LOG"
MOCK

cat >"$MOCK_BIN/setfacl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'setfacl %s\n' "$*" >>"$DVM_TEST_LOG"
MOCK

cat >"$MOCK_BIN/bwrap" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'bwrap %s\n' "$*" >>"$DVM_TEST_LOG"
while [ "$#" -gt 0 ]; do
	case "$1" in
	--setenv)
		export "$2=$3"
		shift 3
		;;
	--)
		shift
		break
		;;
	*)
		shift
		;;
	esac
done
"$@"
MOCK

cat >"$MOCK_BIN/npm" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'npm %s\n' "$*" >>"$DVM_TEST_LOG"
MOCK

cat >"$MOCK_BIN/uv" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'uv %s\n' "$*" >>"$DVM_TEST_LOG"
MOCK

cat >"$MOCK_BIN/free" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "-h" ]; then
	cat <<'FREE'
               total        used        free      shared  buff/cache   available
Mem:           1.0Gi       128Mi       512Mi       0.0Ki       384Mi       768Mi
Swap:             0B          0B          0B
FREE
else
	exec /usr/bin/free "$@"
fi
MOCK

cat >"$MOCK_BIN/ss" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
cat <<'SS'
LISTEN 0 4096 127.0.0.1:22 0.0.0.0:*
LISTEN 0 4096 0.0.0.0:8080 0.0.0.0:*
SS
MOCK

cat >"$MOCK_BIN/hostname" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "-I" ]; then
	printf '192.0.2.15 \n'
	exit 0
fi
exec /bin/hostname "$@"
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

write_lima_port_forward() {
	local guest host rest spec vm
	vm="$1"
	spec="$2"
	host="${spec%%:*}"
	rest="${spec#*:}"
	guest="${rest%%,*}"
	mkdir -p "$DVM_TEST_VM_HOME/$vm"
	cat >"$DVM_TEST_VM_HOME/$vm/lima.yaml" <<YAML
portForwards:
- guestPort: $guest
  hostPort: $host
  hostIP: "127.0.0.1"
YAML
}

case "${1:-}" in
list)
	if [ "${2:-}" = "--format" ]; then
		case "${3:-}" in
		*Status*Dir*)
			while IFS= read -r vm; do
				[ -n "$vm" ] || continue
				status="Running"
				case "$vm" in
				*stopped*) status="Stopped" ;;
				esac
				printf '%s\t%s\t%s/%s\n' "$vm" "$status" "$DVM_TEST_VM_HOME" "$vm"
			done <"$DVM_TEST_LIST" 2>/dev/null || true
			exit 0
			;;
		*Status*)
			while IFS= read -r vm; do
				[ -n "$vm" ] || continue
				status="Running"
				case "$vm" in
				*stopped*) status="Stopped" ;;
				esac
				printf '%s\t%s\n' "$vm" "$status"
			done <"$DVM_TEST_LIST" 2>/dev/null || true
			exit 0
			;;
		esac
		cat "$DVM_TEST_LIST" 2>/dev/null || true
		exit 0
	fi
	cat "$DVM_TEST_LIST" 2>/dev/null || true
	;;
create)
	vm=""
	port_forward=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--name)
			vm="$2"
			shift
			;;
		--port-forward)
			port_forward="$2"
			shift
			;;
		esac
		shift
	done
	[ -n "$vm" ]
	printf 'create %s\n' "$vm" >>"$DVM_TEST_LOG"
	if [ -n "$port_forward" ]; then
		printf 'port-forward %s\n' "$port_forward" >>"$DVM_TEST_LOG"
		write_lima_port_forward "$vm" "$port_forward"
	fi
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
	guest="$(printf '%s\n' "$set_expr" | sed -n 's/.*"guestPort":\([0-9][0-9]*\).*/\1/p')"
	host="$(printf '%s\n' "$set_expr" | sed -n 's/.*"hostPort":\([0-9][0-9]*\).*/\1/p')"
	if [ -n "$guest" ] && [ -n "$host" ]; then
		write_lima_port_forward "$vm" "$host:$guest,static=true"
	fi
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

chmod +x \
	"$MOCK_BIN/sudo" \
	"$MOCK_BIN/dnf5" \
	"$MOCK_BIN/curl" \
	"$MOCK_BIN/sha256sum" \
	"$MOCK_BIN/systemctl" \
	"$MOCK_BIN/llama-server" \
	"$MOCK_BIN/useradd" \
	"$MOCK_BIN/id" \
	"$MOCK_BIN/chown" \
	"$MOCK_BIN/setfacl" \
	"$MOCK_BIN/bwrap" \
	"$MOCK_BIN/npm" \
	"$MOCK_BIN/uv" \
	"$MOCK_BIN/free" \
	"$MOCK_BIN/ss" \
	"$MOCK_BIN/hostname" \
	"$MOCK_BIN/ssh-keygen" \
	"$MOCK_BIN/limactl"

export DVM_TEST_LOG="$LOG"
export DVM_TEST_LIST="$LIST_FILE"
export DVM_TEST_VM_HOME="$VM_HOME_ROOT"
export DVM_TEST_AGENT_USER="$AGENT_USER_FILE"
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

"$ROOT/install.sh" --prefix "$TMP/local-bin" --name dvm-test --init >/dev/null 2>&1
[ -L "$TMP/local-bin/dvm-test" ]
[ -f "$DVM_CONFIG/config.sh" ]
[ -f "$DVM_CONFIG/setup.d/fedora.sh" ]
grep -Fq 'This file is for local overrides only' "$DVM_CONFIG/config.sh"
if grep -q '^DVM_PREFIX=' "$DVM_CONFIG/config.sh"; then
	echo "init config should not pin DVM_PREFIX" >&2
	exit 1
fi
"$TMP/local-bin/dvm-test" config print-template >"$TMP/config-template.out"
grep -Fq 'This file is for local overrides only' "$TMP/config-template.out"
"$TMP/local-bin/dvm-test" config diff >"$TMP/init-config.diff"
[ ! -s "$TMP/init-config.diff" ]

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

"$TMP/local-bin/dvm-test" new app >"$TMP/new.out" 2>"$TMP/new.err"
grep -Fxq 'ssh-ed25519 public-key' "$TMP/new.out"
grep -Fq 'public key for app' "$TMP/new.err"
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
"$TMP/local-bin/dvm-test" list --long >"$TMP/list-long.out"
grep -Fq 'NAME' "$TMP/list-long.out"
grep -Fq 'STATUS' "$TMP/list-long.out"
grep -Fq 'PORTS' "$TMP/list-long.out"
grep -Fq 'AI_URL' "$TMP/list-long.out"
grep -Fq 'app' "$TMP/list-long.out"
grep -Fq 'Running' "$TMP/list-long.out"
grep -Fq '128Mi/1.0Gi' "$TMP/list-long.out"
grep -Fq '22,8080' "$TMP/list-long.out"
rm -f "$HOST_DOTFILES/bashrc"
printf 'export EDITOR=hx\n' >"$HOST_DOTFILES/zshrc"
"$TMP/local-bin/dvm-test" setup-all >/dev/null 2>"$TMP/setup-all.err"
[ "$(grep -Fc 'app' "$VM_HOME_ROOT/testvm-app/setup-ran")" -ge 2 ]
[ ! -e "$VM_HOME_ROOT/testvm-app/.dotfiles/bashrc" ]
[ -f "$VM_HOME_ROOT/testvm-app/.dotfiles/zshrc" ]
grep -Fq 'setup-all complete: 1 succeeded' "$TMP/setup-all.err"
cp "$DVM_CONFIG/config.sh" "$DVM_CONFIG/config.safe.sh"
cp "$DVM_CONFIG/setup.d/fedora.sh" "$DVM_CONFIG/setup.d/fedora.safe.sh"
printf 'testvm-bad\n' >>"$LIST_FILE"
cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-app"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-app/code"
DVM_PACKAGES="git openssh-clients gpg"
DVM_SETUP_SCRIPTS="$DVM_CONFIG/setup.d/fedora.sh"
DVM_SETUP_ALL_JOBS="2"
DVM_GPG_DIR="$DVM_STATE/gpg"
CONFIG
cat >"$DVM_CONFIG/setup.d/fedora.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$DVM_NAME" >>"$HOME/setup-all-ran"
if [ "$DVM_NAME" = "bad" ]; then
	echo "bad setup failed" >&2
	exit 42
fi
SCRIPT
if "$TMP/local-bin/dvm-test" setup-all >/dev/null 2>"$TMP/setup-all-fail.err"; then
	echo "setup-all unexpectedly succeeded with a failing VM" >&2
	exit 1
fi
grep -Fq '[app]' "$TMP/setup-all-fail.err"
grep -Fq '[bad] bad setup failed' "$TMP/setup-all-fail.err"
grep -Fq 'setup-all failed for 1 of 2: bad' "$TMP/setup-all-fail.err"
mv "$DVM_CONFIG/config.safe.sh" "$DVM_CONFIG/config.sh"
mv "$DVM_CONFIG/setup.d/fedora.safe.sh" "$DVM_CONFIG/setup.d/fedora.sh"
"$TMP/local-bin/dvm-test" key app >"$TMP/key.out" 2>"$TMP/key.err"
grep -Fq 'ssh-ed25519' "$TMP/key.out"
if grep -Fq 'public key for app' "$TMP/key.out"; then
	echo "dvm key wrote prose to stdout" >&2
	exit 1
fi
"$TMP/local-bin/dvm-test" doctor >"$TMP/doctor.out"
grep -Fq "prefix: testvm" "$TMP/doctor.out"
"$TMP/local-bin/dvm-test" app pwd >"$TMP/shortcut-ssh.out"
grep -Fxq "$VM_HOME_ROOT/testvm-app" "$TMP/shortcut-ssh.out"

cp "$DVM_CONFIG/config.sh" "$DVM_CONFIG/config.safe.sh"
cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="-bad"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-app"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-app/code"
CONFIG
if "$TMP/local-bin/dvm-test" list >"$TMP/bad-prefix.out" 2>"$TMP/bad-prefix.err"; then
	echo "list unexpectedly succeeded with invalid prefix" >&2
	exit 1
fi
grep -Fq 'invalid DVM_PREFIX' "$TMP/bad-prefix.err"
mv "$DVM_CONFIG/config.safe.sh" "$DVM_CONFIG/config.sh"

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

cp "$DVM_CONFIG/config.sh" "$DVM_CONFIG/config.safe.sh"
cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-app"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-app/code"
DVM_PACKAGES="git openssh-clients gpg helix"
DVM_SETUP_SCRIPTS="$DVM_CONFIG/setup.d/fedora.sh"
DVM_DOTFILES_DIR="$HOST_DOTFILES"
DVM_DOTFILES_TARGET="$VM_HOME_ROOT/testvm-app/"
DVM_GPG_DIR="$DVM_STATE/gpg"
CONFIG
if "$TMP/local-bin/dvm-test" setup app >"$TMP/home-target.out" 2>"$TMP/home-target.err"; then
	echo "setup unexpectedly succeeded with guest-home dotfiles target" >&2
	exit 1
fi
grep -Fq 'refusing unsafe DVM_DOTFILES_TARGET' "$TMP/home-target.err"
cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-app"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-app/code"
DVM_PACKAGES="git openssh-clients gpg helix"
DVM_SETUP_SCRIPTS="$DVM_CONFIG/setup.d/fedora.sh"
DVM_DOTFILES_DIR="$HOST_DOTFILES"
DVM_DOTFILES_TARGET="$VM_HOME_ROOT/testvm-app/../../escape"
DVM_GPG_DIR="$DVM_STATE/gpg"
CONFIG
if "$TMP/local-bin/dvm-test" setup app >"$TMP/traversal-target.out" 2>"$TMP/traversal-target.err"; then
	echo "setup unexpectedly succeeded with path-traversal dotfiles target" >&2
	exit 1
fi
grep -Fq 'DVM_DOTFILES_TARGET must not contain . or .. path segments' "$TMP/traversal-target.err"
mv "$DVM_CONFIG/config.safe.sh" "$DVM_CONFIG/config.sh"

git -C "$VM_HOME_ROOT/testvm-app/code" init -q
printf 'dirty\n' >"$VM_HOME_ROOT/testvm-app/code/file.txt"
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

cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-ai"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-ai/code"
DVM_PACKAGES="git openssh-clients gpg"
DVM_SETUP_SCRIPTS=" "
DVM_GPG_DIR="$DVM_STATE/gpg"
DVM_AI_NAME="ai"
DVM_AI_MODELS_DIR="$VM_HOME_ROOT/testvm-ai/models"
DVM_AI_CURRENT_MODEL="$VM_HOME_ROOT/testvm-ai/models/current.gguf"
DVM_AI_SYSTEMD_DIR="$TMP/systemd"
DVM_AI_PORT="18080"
DVM_AI_DEFAULT_MODEL="tiny"
DVM_AI_MODELS="tiny=https://example.test/tiny.gguf#sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa other=https://example.test/other.gguf"
CONFIG

"$TMP/local-bin/dvm-test" ai create >"$TMP/ai-create.out" 2>"$TMP/ai-create.err"
grep -Fq 'create testvm-ai' "$LOG"
grep -Fq 'port-forward 18080:18080,static=true' "$LOG"
grep -Fq 'dnf5 install -y llama-cpp curl' "$LOG"
grep -Fq 'systemctl enable dvm-llama.service' "$LOG"
grep -Fq 'systemctl restart dvm-llama.service' "$LOG"
grep -Fq 'sha256sum -c -' "$LOG"
[ -f "$VM_HOME_ROOT/testvm-ai/models/tiny.gguf" ]
[ -f "$VM_HOME_ROOT/testvm-ai/models/other.gguf" ]
[ "$(readlink "$VM_HOME_ROOT/testvm-ai/models/current.gguf")" = "$VM_HOME_ROOT/testvm-ai/models/tiny.gguf" ]
[ -f "$TMP/systemd/dvm-llama.service" ]
grep -Fq 'ExecStart=' "$TMP/systemd/dvm-llama.service"
grep -Fq -- '--host 127.0.0.1' "$TMP/systemd/dvm-llama.service"
grep -Fq -- '--port 18080' "$TMP/systemd/dvm-llama.service"

"$TMP/local-bin/dvm-test" ai models >"$TMP/ai-models.out"
grep -Fq '* tiny.gguf' "$TMP/ai-models.out"
grep -Fq 'other.gguf' "$TMP/ai-models.out"
"$TMP/local-bin/dvm-test" ai use other >"$TMP/ai-use.out"
grep -Fq 'active model: other.gguf' "$TMP/ai-use.out"
[ "$(readlink "$VM_HOME_ROOT/testvm-ai/models/current.gguf")" = "$VM_HOME_ROOT/testvm-ai/models/other.gguf" ]
"$TMP/local-bin/dvm-test" ai status >"$TMP/ai-status.out"
grep -Fq 'vm: ai' "$TMP/ai-status.out"
grep -Fq 'service: active' "$TMP/ai-status.out"
grep -Fq 'enabled: enabled' "$TMP/ai-status.out"
grep -Fq 'model: other.gguf' "$TMP/ai-status.out"
"$TMP/local-bin/dvm-test" ai host >"$TMP/ai-host.out"
grep -Fq 'host: http://127.0.0.1:18080' "$TMP/ai-host.out"
grep -Fq 'inside-vm: http://127.0.0.1:18080' "$TMP/ai-host.out"
"$TMP/local-bin/dvm-test" list --long >"$TMP/ai-list-long.out"
grep -Fq 'ai' "$TMP/ai-list-long.out"
grep -Fq 'http://127.0.0.1:18080' "$TMP/ai-list-long.out"
rm -f "$VM_HOME_ROOT/testvm-ai/lima.yaml"
"$TMP/local-bin/dvm-test" ai host >"$TMP/ai-host-not-forwarded.out"
grep -Fq 'host: not forwarded (run: dvm ai expose ai)' "$TMP/ai-host-not-forwarded.out"
"$TMP/local-bin/dvm-test" ai expose >"$TMP/ai-expose.out" 2>"$TMP/ai-expose.err"
grep -Fq 'host: http://127.0.0.1:18080' "$TMP/ai-expose.out"
grep -Fq 'edit testvm-ai' "$LOG"

cp "$DVM_CONFIG/config.sh" "$DVM_CONFIG/config.safe.sh"
cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-ai"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-ai/code"
DVM_PACKAGES="git openssh-clients gpg"
DVM_SETUP_SCRIPTS=" "
DVM_GPG_DIR="$DVM_STATE/gpg"
DVM_AI_NAME="ai"
DVM_AI_MODELS_DIR="$VM_HOME_ROOT/testvm-ai/models"
DVM_AI_CURRENT_MODEL="$VM_HOME_ROOT/testvm-ai/models/current.gguf"
DVM_AI_SYSTEMD_DIR="$TMP/systemd"
DVM_AI_PORT="18080"
DVM_AI_HOST="0.0.0.0"
DVM_AI_DEFAULT_MODEL="tiny"
DVM_AI_MODELS="tiny=https://example.test/tiny.gguf"
CONFIG
"$TMP/local-bin/dvm-test" ai host >"$TMP/ai-host-exposed.out"
grep -Fq 'host: http://127.0.0.1:18080' "$TMP/ai-host-exposed.out"
grep -Fq 'guest-network: http://192.0.2.15:18080' "$TMP/ai-host-exposed.out"
"$TMP/local-bin/dvm-test" list --long >"$TMP/ai-list-long-exposed.out"
grep -Fq 'http://127.0.0.1:18080' "$TMP/ai-list-long-exposed.out"
mv "$DVM_CONFIG/config.safe.sh" "$DVM_CONFIG/config.sh"

cp "$DVM_CONFIG/config.sh" "$DVM_CONFIG/config.safe.sh"
cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-ai"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-ai/code"
DVM_PACKAGES="git openssh-clients gpg"
DVM_SETUP_SCRIPTS=" "
DVM_GPG_DIR="$DVM_STATE/gpg"
DVM_AI_NAME="ai"
DVM_AI_MODELS_DIR="$VM_HOME_ROOT/testvm-ai/models"
DVM_AI_CURRENT_MODEL="$VM_HOME_ROOT/testvm-ai/models/current.gguf"
DVM_AI_SYSTEMD_DIR="$TMP/systemd"
DVM_AI_PORT="18080"
DVM_AI_DEFAULT_MODEL="missing"
DVM_AI_MODELS="tiny=https://example.test/tiny.gguf"
CONFIG
if "$TMP/local-bin/dvm-test" ai models >"$TMP/ai-bad-default.out" 2>"$TMP/ai-bad-default.err"; then
	echo "ai models unexpectedly succeeded with missing default model" >&2
	exit 1
fi
grep -Fq 'DVM_AI_DEFAULT_MODEL is not listed in DVM_AI_MODELS' "$TMP/ai-bad-default.err"
cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-ai"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-ai/code"
DVM_PACKAGES="git openssh-clients gpg"
DVM_SETUP_SCRIPTS=" "
DVM_GPG_DIR="$DVM_STATE/gpg"
DVM_AI_NAME="ai"
DVM_AI_MODELS_DIR="$VM_HOME_ROOT/testvm-ai/models"
DVM_AI_CURRENT_MODEL="$VM_HOME_ROOT/testvm-ai/models/current.gguf"
DVM_AI_SYSTEMD_DIR="$TMP/systemd"
DVM_AI_PORT="18080"
DVM_AI_DEFAULT_MODEL="tiny"
DVM_AI_MODELS="tiny=http://example.test/tiny.gguf"
CONFIG
if "$TMP/local-bin/dvm-test" ai models >"$TMP/ai-http.out" 2>"$TMP/ai-http.err"; then
	echo "ai models unexpectedly succeeded with an HTTP model URL" >&2
	exit 1
fi
grep -Fq 'AI model URL must start with https://' "$TMP/ai-http.err"
mv "$DVM_CONFIG/config.safe.sh" "$DVM_CONFIG/config.sh"

cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-ai"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-ai/code"
DVM_PACKAGES="git openssh-clients gpg"
DVM_SETUP_SCRIPTS=" "
DVM_GPG_DIR="$DVM_STATE/gpg"
DVM_AGENT_HOME="$VM_HOME_ROOT/testvm-ai-agent"
CONFIG

"$TMP/local-bin/dvm-test" agent setup ai >"$TMP/agent-setup.out" 2>"$TMP/agent-setup.err"
grep -Fq 'dnf5 install -y bubblewrap acl shadow-utils' "$LOG"
grep -Fq 'useradd -m -d' "$LOG"
grep -Fq 'setfacl -m u:dvm-agent:rwx' "$LOG"
grep -Fq 'agent user: dvm-agent' "$TMP/agent-setup.out"
# shellcheck disable=SC2016
"$TMP/local-bin/dvm-test" agent ai -- bash -lc 'printf "%s\n" "$HOME" >"$DVM_CODE_DIR/agent-home"; printf "%s\n" "$DVM_AGENT" >"$DVM_CODE_DIR/agent-flag"'
grep -Fxq "$VM_HOME_ROOT/testvm-ai-agent" "$VM_HOME_ROOT/testvm-ai/code/agent-home"
grep -Fxq "1" "$VM_HOME_ROOT/testvm-ai/code/agent-flag"
grep -Fq 'bwrap ' "$LOG"
grep -Fq -- '--unshare-pid' "$LOG"
"$TMP/local-bin/dvm-test" agent install ai codex >/dev/null 2>"$TMP/agent-codex.err"
grep -Fq 'dnf5 install -y nodejs npm' "$LOG"
grep -Fq 'npm install -g @openai/codex' "$LOG"
"$TMP/local-bin/dvm-test" agent install ai opencode >/dev/null 2>"$TMP/agent-opencode.err"
grep -Fq 'npm install -g opencode-ai' "$LOG"
"$TMP/local-bin/dvm-test" agent install ai mistral >/dev/null 2>"$TMP/agent-mistral.err"
grep -Fq 'dnf5 install -y uv python3' "$LOG"
grep -Fq 'uv tool install mistral-vibe' "$LOG"

"$TMP/local-bin/dvm-test" completion zsh >"$TMP/completion.zsh"
grep -Fq 'compdef _dvm dvm-test' "$TMP/completion.zsh"
grep -Fq 'ai:manage a llama.cpp VM' "$TMP/completion.zsh"
grep -Fq 'agent:run AI tools as the restricted agent user' "$TMP/completion.zsh"
grep -Fq "_values 'agent tool' claude codex opencode mistral all" "$TMP/completion.zsh"
