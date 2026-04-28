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

chmod +x \
	"$MOCK_BIN/sudo" \
	"$MOCK_BIN/dnf5" \
	"$MOCK_BIN/curl" \
	"$MOCK_BIN/systemctl" \
	"$MOCK_BIN/llama-server" \
	"$MOCK_BIN/useradd" \
	"$MOCK_BIN/id" \
	"$MOCK_BIN/chown" \
	"$MOCK_BIN/setfacl" \
	"$MOCK_BIN/bwrap" \
	"$MOCK_BIN/npm" \
	"$MOCK_BIN/uv" \
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
DVM_AI_MODELS="tiny=https://example.test/tiny.gguf other=https://example.test/other.gguf"
CONFIG

"$TMP/local-bin/dvm-test" ai create >"$TMP/ai-create.out"
grep -Fq 'create testvm-ai' "$LOG"
grep -Fq 'dnf5 install -y llama-cpp curl' "$LOG"
grep -Fq 'systemctl enable dvm-llama.service' "$LOG"
grep -Fq 'systemctl restart dvm-llama.service' "$LOG"
[ -f "$VM_HOME_ROOT/testvm-ai/models/tiny.gguf" ]
[ -f "$VM_HOME_ROOT/testvm-ai/models/other.gguf" ]
[ "$(readlink "$VM_HOME_ROOT/testvm-ai/models/current.gguf")" = "$VM_HOME_ROOT/testvm-ai/models/tiny.gguf" ]
[ -f "$TMP/systemd/dvm-llama.service" ]
grep -Fq 'ExecStart=' "$TMP/systemd/dvm-llama.service"
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

cat >"$DVM_CONFIG/config.sh" <<CONFIG
DVM_PREFIX="testvm"
DVM_GUEST_HOME="$VM_HOME_ROOT/testvm-ai"
DVM_CODE_DIR="$VM_HOME_ROOT/testvm-ai/code"
DVM_PACKAGES="git openssh-clients gpg"
DVM_SETUP_SCRIPTS=" "
DVM_GPG_DIR="$DVM_STATE/gpg"
DVM_AGENT_HOME="$VM_HOME_ROOT/testvm-ai-agent"
CONFIG

"$TMP/local-bin/dvm-test" agent setup ai >"$TMP/agent-setup.out"
grep -Fq 'dnf5 install -y bubblewrap acl shadow-utils' "$LOG"
grep -Fq 'useradd -m -d' "$LOG"
grep -Fq 'setfacl -m u:dvm-agent:rwx' "$LOG"
grep -Fq 'agent user: dvm-agent' "$TMP/agent-setup.out"
# shellcheck disable=SC2016
"$TMP/local-bin/dvm-test" agent ai -- bash -lc 'printf "%s\n" "$HOME" >"$DVM_CODE_DIR/agent-home"; printf "%s\n" "$DVM_AGENT" >"$DVM_CODE_DIR/agent-flag"'
grep -Fxq "$VM_HOME_ROOT/testvm-ai-agent" "$VM_HOME_ROOT/testvm-ai/code/agent-home"
grep -Fxq "1" "$VM_HOME_ROOT/testvm-ai/code/agent-flag"
grep -Fq 'bwrap ' "$LOG"
"$TMP/local-bin/dvm-test" agent install ai codex >/dev/null
grep -Fq 'dnf5 install -y nodejs npm' "$LOG"
grep -Fq 'npm install -g @openai/codex' "$LOG"
"$TMP/local-bin/dvm-test" agent install ai opencode >/dev/null
grep -Fq 'npm install -g opencode-ai' "$LOG"
"$TMP/local-bin/dvm-test" agent install ai mistral >/dev/null
grep -Fq 'dnf5 install -y uv python3' "$LOG"
grep -Fq 'uv tool install mistral-vibe' "$LOG"

"$TMP/local-bin/dvm-test" completion zsh >"$TMP/completion.zsh"
grep -Fq 'compdef _dvm dvm-test' "$TMP/completion.zsh"
grep -Fq 'ai:manage a llama.cpp VM' "$TMP/completion.zsh"
grep -Fq 'agent:run AI tools as the restricted agent user' "$TMP/completion.zsh"
grep -Fq "_values 'agent tool' claude codex opencode mistral all" "$TMP/completion.zsh"
