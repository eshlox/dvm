#!/usr/bin/env bash
# shellcheck disable=SC1003,SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

assert_contains() { grep -Fq -- "$2" "$1"; }

assert_contains_all() {
	local file="$1"
	local needle
	shift
	for needle in "$@"; do
		assert_contains "$file" "$needle"
	done
}

assert_matches() { grep -Eq -- "$2" "$1"; }

assert_not_contains() {
	local file="$1"
	local needle="$2"
	local message="$3"
	if grep -Fq -- "$needle" "$file"; then
		printf '%s\n' "$message" >&2
		exit 1
	fi
}

reset_log() { : >"$TMP/state/log"; }

run_fails() {
	local err="$1"
	local status
	shift
	set +e
	"$@" >/dev/null 2>"$err"
	status="$?"
	set -e
	[ "$status" -ne 0 ]
}

run_fails_capture() {
	local out="$1"
	local err="$2"
	local status
	shift 2
	set +e
	"$@" >"$out" 2>"$err"
	status="$?"
	set -e
	[ "$status" -ne 0 ]
}

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
	use bat
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

cat >"$TMP/config/vms/rooted.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=4GiB
DVM_DISK=20GiB
DVM_CODE_ROOT="~/work"

use python
VM

cat >"$TMP/config/vms/cloudflared.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/cloudflared"
DVM_CLOUDFLARED_TOKEN="${CLOUDFLARED_TOKEN:-}"

use cloudflared
VM

cat >"$TMP/config/vms/tailscale.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/tailscale"
DVM_NO_BASELINE=1
DVM_TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
DVM_TAILSCALE_FUNNEL_TARGET="http://lima-dvm-app.internal:3000"

use tailscale
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
copy)
	printf 'copy %s\n' "$*" >>"$state/log"
	;;
shell)
	vm="$1"
	shift
	printf 'shell %s %s\n' "$vm" "$*" >>"$state/log"
	cat >"$state/guest.sh"
	bash -n "$state/guest.sh"
	if grep -Fq '# dvm activity probe' "$state/guest.sh"; then
		activity="$(cat "$state/activity/$vm" 2>/dev/null || true)"
		case "$activity" in
		active:*)
			printf '%s\n' "$activity"
			exit 1
			;;
		fail:*)
			printf '%s\n' "${activity#fail:}" >&2
			exit 2
			;;
		*)
			printf 'inactive\n'
			;;
		esac
	fi
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
assert_contains "$TMP/old-dvm" old-target
[ -x "$TMP/install-bin/dvm" ]
[ ! -L "$TMP/install-bin/dvm" ]
assert_contains_all "$TMP/install-bin/dvm" \
	'dvm-run.' \
	'DVM_LIB_DIR="$tmp_parent/lib"'
[ ! -e "$TMP/install-config/lib" ]
[ ! -e "$TMP/install-config/completions" ]
"$TMP/install-bin/dvm" help >"$TMP/install-help.out"
assert_contains "$TMP/install-help.out" 'dvm init <name> [template]'

completion="$ROOT/share/dvm/completions/_dvm"
[ -f "$completion" ]
if command -v zsh >/dev/null 2>&1; then
	zsh -n "$completion"
fi

"$ROOT/bin/dvm" init newapp
[ -f "$TMP/config/vms/newapp.sh" ]
assert_contains "$TMP/config/vms/newapp.sh" 'DVM_CODE_DIR="~/code/$DVM_NAME"'
assert_matches "$TMP/config/vms/newapp.sh" '^use_tools$'
assert_not_contains "$TMP/config/vms/newapp.sh" '__DVM_HOST_MAX_CPUS__' \
	'init left __DVM_HOST_MAX_CPUS__ placeholder unsubstituted'
"$ROOT/bin/dvm" init llama llama
[ -f "$TMP/config/vms/llama.sh" ]
assert_contains "$TMP/config/vms/llama.sh" 'use llama'
run_fails "$TMP/init-bad.err" "$ROOT/bin/dvm" init bad missing-template
assert_contains "$TMP/init-bad.err" 'missing VM template: missing-template'
run_fails "$TMP/stop-all-extra.err" "$ROOT/bin/dvm" stop --all extra
assert_contains "$TMP/stop-all-extra.err" 'stop --all does not take a VM name'

rm -f "$TMP/config/vms/newapp.sh" "$TMP/config/vms/llama.sh"

"$ROOT/bin/dvm" sync app 2>"$TMP/apply.err"
assert_contains "$TMP/apply.err" 'dvm: syncing recipes for app: baseline zsh git helix lazygit starship fzf bat git-delta just tmux yazi node agent-user codex claude chezmoi'
assert_contains_all "$TMP/state/log" \
	'create dvm-app' \
	'start dvm-app' \
	'DVM_CODE_DIR=~/code/app'
assert_not_contains "$TMP/state/log" 'DVM_CHEZMOI_SIGNING_KEY=' \
	'default signing key should not require a VM config variable'
assert_contains_all "$TMP/state/guest.sh" \
	'set -euo pipefail' \
	'dvm hostname' \
	'hostnamectl set-hostname "$DVM_NAME"' \
	'dvm recipe: agent-user' \
	'/usr/local/libexec/dvm-ai-bwrap' \
	'--bind "$DVM_AI_CODE_DIR" /workspace' \
	'--setenv DVM_CODE_DIR /workspace' \
	'dvm recipe: codex' \
	'--dangerously-bypass-approvals-and-sandbox "\$@"' \
	'dvm recipe: claude' \
	'defaultMode = "bypassPermissions"' \
	'dvm project hook'
assert_contains "$TMP/state/lima.yaml" 'hostPort: 3000'
bash -n "$TMP/state/guest.sh"

reset_log
"$ROOT/bin/dvm" sync rooted
assert_contains "$TMP/state/log" 'DVM_CODE_DIR=~/work/rooted'

reset_log
CLOUDFLARED_TOKEN="smoke.Token_123=-" "$ROOT/bin/dvm" sync cloudflared
assert_contains_all "$TMP/state/guest.sh" \
	'dvm-cloudflared-token.' \
	'ActiveEnterTimestamp'
assert_not_contains "$TMP/state/log" 'CLOUDFLARED_TOKEN=smoke.Token_123=-' \
	'cloudflared token leaked into limactl argv log'
assert_not_contains "$TMP/state/log" 'DVM_CLOUDFLARED_TOKEN=smoke.Token_123=-' \
	'DVM cloudflared token leaked into limactl argv log'

reset_log
TAILSCALE_AUTH_KEY="tskey-auth-smoke-Test_123" "$ROOT/bin/dvm" sync tailscale
assert_contains_all "$TMP/state/guest.sh" \
	'dvm recipe: tailscale' \
	'dvm-tailscale-auth-key.' \
	'tailscale funnel --bg --https=443'
assert_contains "$TMP/state/log" 'DVM_TAILSCALE_FUNNEL_TARGET=http://lima-dvm-app.internal:3000'
assert_not_contains "$TMP/state/log" 'TAILSCALE_AUTH_KEY=tskey-auth-smoke-Test_123' \
	'tailscale auth key leaked into limactl argv log'
assert_not_contains "$TMP/state/log" 'DVM_TAILSCALE_AUTH_KEY=tskey-auth-smoke-Test_123' \
	'DVM tailscale auth key leaked into limactl argv log'

run_fails "$TMP/tailscale-bad.err" env TAILSCALE_AUTH_KEY="not-a-tskey" "$ROOT/bin/dvm" sync tailscale
assert_contains "$TMP/tailscale-bad.err" 'must start with tskey-'

perl -0pi -e 's/DVM_PORTS="3000:3000"/DVM_PORTS="3000:3000 9000:9000"/' "$TMP/config/vms/app.sh"
"$ROOT/bin/dvm" sync app
assert_contains "$TMP/state/log" 'edit --tty=false --set .portForwards'
bash -n "$TMP/state/guest.sh"

"$ROOT/bin/dvm" ls >"$TMP/list.out"
assert_matches "$TMP/list.out" '^app[[:space:]]+Running[[:space:]]+127\.0\.0\.1:60022'
assert_not_contains "$TMP/list.out" 'dvm-app' 'dvm ls leaked internal Lima prefix'

"$ROOT/bin/dvm" ssh app -- pwd
assert_contains_all "$TMP/state/log" \
	'shell dvm-app env TERM=' \
	' bash -c '

"$ROOT/bin/dvm" ssh dvm-app -- pwd
assert_contains "$TMP/state/log" 'shell dvm-app env TERM='

guest_home="/home/${USER:-developer}"
guest_code_dir="$guest_home/code/app"
printf 'plan\n' >"$TMP/plan.md"
reset_log
"$ROOT/bin/dvm" cp "$TMP/plan.md" app:.
assert_contains_all "$TMP/state/log" \
	"shell dvm-app mkdir -p $guest_code_dir" \
	"copy $TMP/plan.md dvm-app:$guest_code_dir"

reset_log
"$ROOT/bin/dvm" cp -r --backend=scp app:docs "$TMP/docs-out"
assert_contains "$TMP/state/log" "copy -r --backend=scp dvm-app:$guest_code_dir/docs $TMP/docs-out"
assert_not_contains "$TMP/state/log" 'bash -s -- dvm-agent' \
	'dvm cp refreshed agent ACLs on VM-to-host copy'

touch "$TMP/state/list_empty_once"
"$ROOT/bin/dvm" ssh app -- pwd
assert_contains "$TMP/state/log" 'shell dvm-app env TERM='

cat >"$TMP/config/vms/race.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/race"

use python
VM

mkdir -p "$TMP/state/dvm-race"
cp "$TMP/state/lima.yaml" "$TMP/state/dvm-race/lima.yaml"
assert_contains "$TMP/state/created" dvm-race || printf '%s\n' dvm-race >>"$TMP/state/created"
touch "$TMP/state/list_empty_once"
"$ROOT/bin/dvm" sync race
assert_contains "$TMP/state/log" 'shell dvm-race env '
rm -f "$TMP/config/vms/race.sh"

"$ROOT/bin/dvm" ssh-key app
assert_contains "$TMP/state/log" 'shell dvm-app env DVM_NAME=app bash -s'
assert_contains "$TMP/state/guest.sh" 'Git commit signing public key'

"$ROOT/bin/dvm" gpg-key app
assert_contains "$TMP/state/log" 'shell dvm-app env DVM_NAME=app bash -s'

mkdir -p "$TMP/state/activity"
printf 'active: zellij\n' >"$TMP/state/activity/dvm-app"
printf 'fail: probe unavailable\n' >"$TMP/state/activity/dvm-rooted"
printf 'active: dvm-cloudflared.service\n' >"$TMP/state/activity/dvm-cloudflared"
printf 'active: tailscaled.service\n' >"$TMP/state/activity/dvm-tailscale"
reset_log
"$ROOT/bin/dvm" stop --inactive --force >"$TMP/stop-inactive.out" 2>"$TMP/stop-inactive.err"
assert_contains "$TMP/stop-inactive.out" 'dvm stop --all: 2 stopped, 3 skipped, 0 failed'
assert_contains "$TMP/stop-inactive.err" 'skipping active VM: dvm-app (active: zellij)'
assert_contains "$TMP/state/log" 'stop dvm-rooted'
assert_not_contains "$TMP/state/log" 'stop dvm-app' 'dvm stop --inactive stopped an active VM'
assert_not_contains "$TMP/state/log" 'stop dvm-cloudflared' 'dvm stop --inactive stopped an active VM'
assert_not_contains "$TMP/state/log" 'stop dvm-tailscale' 'dvm stop --inactive stopped an active VM'
rm -rf "$TMP/state/activity"

reset_log
"$ROOT/bin/dvm" stop --all >"$TMP/stop-all.out"
assert_contains "$TMP/stop-all.out" 'dvm stop --all: 5 stopped, 0 skipped, 0 failed'

"$ROOT/bin/dvm" stop app
assert_contains "$TMP/state/log" 'stop dvm-app'

"$ROOT/bin/dvm" rm app --yes
assert_contains_all "$TMP/state/log" \
	'shell dvm-app bash -s -- ~/code/app' \
	'stop dvm-app' \
	'delete dvm-app'

mkdir -p "$TMP/state/dvm-orphan"
cp "$TMP/state/lima.yaml" "$TMP/state/dvm-orphan/lima.yaml"
assert_contains "$TMP/state/created" dvm-orphan || printf '%s\n' dvm-orphan >>"$TMP/state/created"
"$ROOT/bin/dvm" rm orphan --yes 2>"$TMP/rm-orphan.err"
assert_contains_all "$TMP/rm-orphan.err" \
	'deleting Lima VM without DVM config: dvm-orphan' \
	'dirty check skipped because DVM config is missing'
assert_contains "$TMP/state/log" 'delete dvm-orphan'

reset_log
rm -f "$TMP/state/created"
rm -rf "$TMP/state"/dvm-*
"$ROOT/bin/dvm" sync --all >"$TMP/apply-all.out"
assert_contains_all "$TMP/state/log" \
	'create dvm-app' \
	'create dvm-second'
if grep -F -- 'shell dvm-second ' "$TMP/state/log" | grep -Fq -- 'DVM_APP_ONLY='; then
	printf 'DVM_APP_ONLY leaked from app into second\n' >&2
	exit 1
fi

"$ROOT/bin/dvm" log cloudflared
assert_contains "$TMP/state/log" 'shell dvm-cloudflared sudo journalctl -u dvm-cloudflared.service --no-pager -n 100'

cat >"$TMP/config/vms/invalid.sh" <<'VM'
DVM_USER="root:bad"
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/invalid"

use python
VM

run_fails "$TMP/invalid.err" "$ROOT/bin/dvm" sync invalid
assert_contains "$TMP/invalid.err" 'invalid DVM_USER: root:bad'
rm -f "$TMP/config/vms/invalid.sh"

cat >"$TMP/config/vms/bad.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/bad"

use missing-recipe
VM

reset_log
rm -f "$TMP/state/created"
rm -rf "$TMP/state"/dvm-*
run_fails_capture "$TMP/apply-all-fail.out" "$TMP/apply-all-fail.err" "$ROOT/bin/dvm" sync --all
assert_contains "$TMP/apply-all-fail.err" 'dvm: sync failed: bad'
assert_contains_all "$TMP/apply-all-fail.out" \
	'dvm sync --all:' \
	'1 failed'
assert_contains "$TMP/state/log" 'create dvm-second'
