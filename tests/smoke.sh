#!/usr/bin/env bash
# shellcheck disable=SC1003,SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/config/vms" "$TMP/state"
cp -R "$ROOT/share/dvm/." "$TMP/config/"
rm -rf "$TMP/config/vms"
mkdir -p "$TMP/config/vms"

cat >>"$TMP/config/config.sh" <<'CONFIG'

DVM_CHEZMOI_ROLE="vm"
DVM_CHEZMOI_NAME="Example User"
DVM_CHEZMOI_EMAIL="example@example.com"

use_app_tools() {
	use zsh
	use git
	use helix
	use lazygit
	use starship
	use fzf
	use git-delta
	use just
	use tmux
	use yazi
}
CONFIG

cat >"$TMP/config/vms/app.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=4GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/app"
DVM_PORTS="3000:3000"
DVM_CHEZMOI_REPO="https://github.com/example/dotfiles.git"
DVM_APP_ONLY="app"

use_app_tools
use node
use agent-user
use codex
use claude
use chezmoi
VM

cat >"$TMP/config/vms/second.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=4GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/second"

use python
VM

cat >"$TMP/config/vms/cloudflared.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/cloudflared"

use cloudflared
VM

cat >"$TMP/bin/limactl" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
state="${DVM_FAKE_STATE:?}"
cmd="$1"
shift
case "$cmd" in
list)
	if [ -f "$state/list_empty_once" ]; then
		rm -f "$state/list_empty_once"
		exit 0
	fi
	if [ -f "$state/created" ]; then
		case "${*:-}" in
		*"{{.Name}}"*"{{.Status}}"*)
			while IFS= read -r name; do printf '%s\tRunning\t%s/%s\n' "$name" "$state" "$name"; done <"$state/created"
			;;
		*"{{.Name}}"*"{{.Dir}}"*)
			while IFS= read -r name; do printf '%s\t%s/%s\n' "$name" "$state" "$name"; done <"$state/created"
			;;
		'')
			printf 'NAME STATUS SSH\n'
			while IFS= read -r name; do printf '%s Running 127.0.0.1:60022\n' "$name"; done <"$state/created"
			;;
		*)
			cat "$state/created"
			;;
		esac
	fi
	;;
create)
	name=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--name) name="$2"; shift ;;
		*)
			if [ -f "$1" ]; then
				mkdir -p "$state/$name"
				cp "$1" "$state/$name/lima.yaml"
				cp "$1" "$state/lima.yaml"
			fi
			;;
		esac
		shift || true
	done
	if [ -f "$state/created" ] && grep -Fxq "$name" "$state/created"; then
		printf 'FATA[0000] instance "%s" already exists\n' "$name" >&2
		exit 1
	fi
	touch "$state/created"
	grep -Fxq "$name" "$state/created" || printf '%s\n' "$name" >>"$state/created"
	printf 'create %s\n' "$name" >>"$state/log"
	;;
start)
	printf 'start %s\n' "$1" >>"$state/log"
	;;
stop)
	printf 'stop %s\n' "$1" >>"$state/log"
	;;
edit)
	printf 'edit %s\n' "$*" >>"$state/log"
	;;
shell)
	vm="$1"
	shift
	printf 'shell %s %s\n' "$vm" "$*" >>"$state/log"
	cat >"$state/guest.sh"
	bash -n "$state/guest.sh"
	;;
delete)
	printf 'delete %s\n' "$1" >>"$state/log"
	rm -rf "$state/$1"
	if [ -f "$state/created" ]; then
		grep -Fxv "$1" "$state/created" >"$state/created.tmp" || true
		mv "$state/created.tmp" "$state/created"
	fi
	;;
*)
	printf 'fake limactl: unsupported %s\n' "$cmd" >&2
	exit 1
	;;
esac
FAKE
chmod +x "$TMP/bin/limactl"

export PATH="$TMP/bin:$PATH"
export DVM_CONFIG="$TMP/config"
export DVM_FAKE_STATE="$TMP/state"
export LIMA_HOME="$TMP/state"
export EDITOR=:

mkdir -p "$TMP/install-bin"
printf '%s\n' old-target >"$TMP/old-dvm"
ln -s "$TMP/old-dvm" "$TMP/install-bin/dvm"
PREFIX="$TMP/install-bin" DVM_CONFIG="$TMP/install-config" "$ROOT/install.sh" --init >"$TMP/install.out"
grep -Fxq old-target "$TMP/old-dvm"
[ -x "$TMP/install-bin/dvm" ]
[ ! -L "$TMP/install-bin/dvm" ]
grep -Fq 'dvm-run.' "$TMP/install-bin/dvm"
"$TMP/install-bin/dvm" help >"$TMP/install-help.out"
grep -Fq 'dvm init <name> [template]' "$TMP/install-help.out"

"$ROOT/bin/dvm" init newapp
[ -f "$TMP/config/vms/newapp.sh" ]
grep -Fq 'DVM_CODE_DIR="~/code/$DVM_NAME"' "$TMP/config/vms/newapp.sh"
"$ROOT/bin/dvm" init llama llama
[ -f "$TMP/config/vms/llama.sh" ]
grep -Fq 'use llama' "$TMP/config/vms/llama.sh"
set +e
"$ROOT/bin/dvm" init bad missing-template >/dev/null 2>"$TMP/init-bad.err"
status="$?"
set -e
[ "$status" -ne 0 ]
grep -Fq 'missing VM template: missing-template' "$TMP/init-bad.err"
rm -f "$TMP/config/vms/newapp.sh" "$TMP/config/vms/llama.sh"

"$ROOT/bin/dvm" apply app 2>"$TMP/apply.err"
grep -Fq 'dvm: applying recipes for app: baseline zsh git helix lazygit starship fzf git-delta just tmux yazi node agent-user codex claude chezmoi' "$TMP/apply.err"
grep -Fq 'create dvm-app' "$TMP/state/log"
grep -Fq 'start dvm-app' "$TMP/state/log"
grep -Fq 'DVM_CODE_DIR=~/code/app' "$TMP/state/log"
grep -Fq 'dvm hostname' "$TMP/state/guest.sh"
grep -Fq 'hostnamectl set-hostname "$DVM_NAME"' "$TMP/state/guest.sh"
grep -Fq 'dvm recipe: zsh' "$TMP/state/guest.sh"
grep -Fq 'usermod --shell "$zsh_path" "$(id -un)"' "$TMP/state/guest.sh"
grep -Fq 'dvm recipe: yazi' "$TMP/state/guest.sh"
grep -Fq 'dvm recipe: agent-user' "$TMP/state/guest.sh"
grep -Fq 'dnf5 install -y acl bubblewrap shadow-utils sudo' "$TMP/state/guest.sh"
grep -Fq 'useradd --system --create-home --user-group --shell /bin/bash "$DVM_AI_AGENT_USER"' "$TMP/state/guest.sh"
grep -Fq '/usr/local/libexec/dvm-ai-bwrap' "$TMP/state/guest.sh"
grep -Fq 'exec /usr/bin/bwrap \' "$TMP/state/guest.sh"
grep -Fq -- '--bind "$DVM_AI_CODE_DIR" /workspace' "$TMP/state/guest.sh"
grep -Fq -- '--setenv DVM_CODE_DIR /workspace' "$TMP/state/guest.sh"
grep -Fq -- '-- "$DVM_AI_TARGET" "$@"' "$TMP/state/guest.sh"
grep -Fq 'dvm recipe: codex' "$TMP/state/guest.sh"
grep -Fq 'dvm recipe: claude' "$TMP/state/guest.sh"
grep -Fq 'baseurl=https://downloads.claude.ai/claude-code/rpm/latest' "$TMP/state/guest.sh"
grep -Fq 'dnf5 --refresh upgrade -y claude-code' "$TMP/state/guest.sh"
grep -Fq 'defaultMode = "bypassPermissions"' "$TMP/state/guest.sh"
grep -Fq 'skipDangerousModePermissionPrompt = true' "$TMP/state/guest.sh"
grep -Fq 'DVM_CHEZMOI_ROLE=vm' "$TMP/state/log"
grep -Fq 'DVM_CHEZMOI_NAME=Example User' "$TMP/state/log"
if grep -Fq 'DVM_CHEZMOI_SIGNING_KEY=' "$TMP/state/log"; then
	printf 'default signing key should not require a VM config variable\n' >&2
	exit 1
fi
grep -Fq 'signing_key="${DVM_CHEZMOI_SIGNING_KEY:-~/.ssh/id_ed25519_dvm_signing.pub}"' "$TMP/state/guest.sh"
grep -Fq 'deploy_key="${DVM_CHEZMOI_DEPLOY_KEY:-~/.ssh/id_ed25519_dvm.pub}"' "$TMP/state/guest.sh"
grep -Fq 'signingKey = %s' "$TMP/state/guest.sh"
grep -Fq 'deployKey = %s' "$TMP/state/guest.sh"
grep -Fq 'dvm project hook' "$TMP/state/guest.sh"
grep -Fq 'hostPort: 3000' "$TMP/state/lima.yaml"
bash -n "$TMP/state/guest.sh"

perl -0pi -e 's/DVM_PORTS="3000:3000"/DVM_PORTS="3000:3000 9000:9000"/' "$TMP/config/vms/app.sh"
"$ROOT/bin/dvm" apply app
grep -Fq 'edit --tty=false --set .portForwards' "$TMP/state/log"
bash -n "$TMP/state/guest.sh"

"$ROOT/bin/dvm" list >"$TMP/list.out"
grep -Eq '^NAME[[:space:]]+STATUS[[:space:]]+SSH' "$TMP/list.out"
grep -Eq '^app[[:space:]]+Running[[:space:]]+127\.0\.0\.1:60022' "$TMP/list.out"
if grep -Fq 'dvm-app' "$TMP/list.out"; then
	printf 'dvm list leaked internal Lima prefix\n' >&2
	exit 1
fi

"$ROOT/bin/dvm" ssh app -- pwd
grep -Fq 'shell dvm-app env TERM=' "$TMP/state/log"
grep -Fq ' bash -c ' "$TMP/state/log"
grep -Fq '${code_dir#\~/}' "$TMP/state/log"
grep -Fq 'export SHELL="$login_shell"' "$TMP/state/log"
expanded_code_dir="$(
	HOME=/home/example bash -c '
		code_dir="~/code/app"
		case "$code_dir" in
			"~") code_dir="$HOME" ;;
			"~/"*) code_dir="$HOME/${code_dir#\~/}" ;;
		esac
		printf "%s\n" "$code_dir"
	'
)"
[ "$expanded_code_dir" = "/home/example/code/app" ]

"$ROOT/bin/dvm" ssh dvm-app -- pwd
grep -Fq 'shell dvm-app env TERM=' "$TMP/state/log"

touch "$TMP/state/list_empty_once"
"$ROOT/bin/dvm" ssh app -- pwd
grep -Fq 'shell dvm-app env TERM=' "$TMP/state/log"

cat >"$TMP/config/vms/race.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/race"

use python
VM

mkdir -p "$TMP/state/dvm-race"
cp "$TMP/state/lima.yaml" "$TMP/state/dvm-race/lima.yaml"
grep -Fxq dvm-race "$TMP/state/created" || printf '%s\n' dvm-race >>"$TMP/state/created"
touch "$TMP/state/list_empty_once"
"$ROOT/bin/dvm" apply race
grep -Fq 'start dvm-race' "$TMP/state/log"
grep -Fq 'shell dvm-race env ' "$TMP/state/log"
rm -f "$TMP/config/vms/race.sh"

"$ROOT/bin/dvm" ssh-key app
grep -Fq 'shell dvm-app env DVM_NAME=app bash -s' "$TMP/state/log"
grep -Fq 'id_ed25519_dvm_signing' "$TMP/state/guest.sh"
grep -Fq 'dvm-github-access' "$TMP/state/guest.sh"
grep -Fq 'dvm-git-signing' "$TMP/state/guest.sh"
grep -Fq 'user.signingkey "$signing_key.pub"' "$TMP/state/guest.sh"
grep -Fq 'GitHub access key public key' "$TMP/state/guest.sh"
grep -Fq 'Git commit signing public key' "$TMP/state/guest.sh"

"$ROOT/bin/dvm" gpg-key app
grep -Fq 'shell dvm-app env DVM_NAME=app bash -s' "$TMP/state/log"

"$ROOT/bin/dvm" stop app
grep -Fq 'stop dvm-app' "$TMP/state/log"

"$ROOT/bin/dvm" rm app --yes
grep -Fq 'shell dvm-app bash -s -- ~/code/app' "$TMP/state/log"
grep -Fq 'stop dvm-app' "$TMP/state/log"
grep -Fq 'delete dvm-app' "$TMP/state/log"

: >"$TMP/state/log"
rm -f "$TMP/state/created"
rm -rf "$TMP/state"/dvm-*
"$ROOT/bin/dvm" apply --all >"$TMP/apply-all.out"
grep -Fq 'create dvm-app' "$TMP/state/log"
grep -Fq 'create dvm-second' "$TMP/state/log"
if grep -F 'shell dvm-second ' "$TMP/state/log" | grep -Fq 'DVM_APP_ONLY='; then
	printf 'DVM_APP_ONLY leaked from app into second\n' >&2
	exit 1
fi

"$ROOT/bin/dvm" logs cloudflared
grep -Fq 'shell dvm-cloudflared sudo journalctl -u dvm-cloudflared.service --no-pager -n 100' "$TMP/state/log"

"$ROOT/bin/dvm" logs cloudflared -f
grep -Fq 'shell dvm-cloudflared sudo journalctl -u dvm-cloudflared.service -f' "$TMP/state/log"

cat >"$TMP/config/vms/bad.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/bad"

use missing-recipe
VM

: >"$TMP/state/log"
rm -f "$TMP/state/created"
rm -rf "$TMP/state"/dvm-*
set +e
"$ROOT/bin/dvm" apply --all >"$TMP/apply-all-fail.out" 2>"$TMP/apply-all-fail.err"
status="$?"
set -e
[ "$status" -ne 0 ]
grep -Fq 'dvm: apply failed: bad' "$TMP/apply-all-fail.err"
grep -Fq 'dvm apply --all:' "$TMP/apply-all-fail.out"
grep -Fq '1 failed' "$TMP/apply-all-fail.out"
grep -Fq 'create dvm-second' "$TMP/state/log"
