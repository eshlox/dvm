#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/config/vms" "$TMP/state"
cp -R "$ROOT/share/dvm/." "$TMP/config/"
rm -rf "$TMP/config/vms"
mkdir -p "$TMP/config/vms"

cat >"$TMP/config/vms/app.sh" <<'VM'
DVM_CPUS=2
DVM_MEMORY=4GiB
DVM_DISK=20GiB
DVM_CODE_DIR="~/code/app"
DVM_PORTS="3000:3000"
DVM_CHEZMOI_REPO="https://github.com/example/dotfiles.git"
DVM_APP_ONLY="app"

use node
use agent-user
use codex
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

"$ROOT/bin/dvm" apply app
grep -Fq 'create dvm-app' "$TMP/state/log"
grep -Fq 'start dvm-app' "$TMP/state/log"
grep -Fq 'DVM_CODE_DIR=~/code/app' "$TMP/state/log"
grep -Fq 'dvm recipe: agent-user' "$TMP/state/guest.sh"
grep -Fq 'dvm recipe: codex' "$TMP/state/guest.sh"
grep -Fq 'dvm project hook' "$TMP/state/guest.sh"
grep -Fq 'hostPort: 3000' "$TMP/state/lima.yaml"
bash -n "$TMP/state/guest.sh"

perl -0pi -e 's/DVM_PORTS="3000:3000"/DVM_PORTS="3000:3000 9000:9000"/' "$TMP/config/vms/app.sh"
"$ROOT/bin/dvm" apply app
grep -Fq 'edit --tty=false --set .portForwards' "$TMP/state/log"
bash -n "$TMP/state/guest.sh"

"$ROOT/bin/dvm" list >"$TMP/list.out"
grep -Fq 'dvm-app' "$TMP/list.out"

"$ROOT/bin/dvm" ssh app -- pwd
grep -Fq 'shell dvm-app bash -lc' "$TMP/state/log"

"$ROOT/bin/dvm" ssh-key app
grep -Fq 'shell dvm-app env DVM_NAME=app bash -s' "$TMP/state/log"

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
set +e
"$ROOT/bin/dvm" apply --all >"$TMP/apply-all-fail.out" 2>"$TMP/apply-all-fail.err"
status="$?"
set -e
[ "$status" -ne 0 ]
grep -Fq 'dvm: apply failed: bad' "$TMP/apply-all-fail.err"
grep -Fq 'dvm apply --all:' "$TMP/apply-all-fail.out"
grep -Fq '1 failed' "$TMP/apply-all-fail.out"
grep -Fq 'create dvm-second' "$TMP/state/log"
