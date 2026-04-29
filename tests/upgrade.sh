#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MOCK_BIN="$TMP/bin"
mkdir -p "$MOCK_BIN"

cat >"$MOCK_BIN/limactl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
list)
	exit 0
	;;
*)
	printf 'unexpected limactl command: %s\n' "$*" >&2
	exit 1
	;;
esac
MOCK

cat >"$MOCK_BIN/ssh-keygen" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'ssh-keygen mock\n'
MOCK

chmod +x "$MOCK_BIN/limactl" "$MOCK_BIN/ssh-keygen"

export PATH="$MOCK_BIN:$PATH"
export HOME="$TMP/home"
export DVM_CONFIG="$TMP/config"
export DVM_STATE="$TMP/state"
mkdir -p "$HOME" "$DVM_CONFIG" "$DVM_STATE"

for fixture in "$ROOT"/tests/fixtures/config-*.sh; do
	cp "$fixture" "$DVM_CONFIG/config.sh"
	"$ROOT/bin/dvm" doctor >"$TMP/doctor.out" 2>"$TMP/doctor.err"
	grep -Fq 'prefix:' "$TMP/doctor.out"
	"$ROOT/bin/dvm" list >"$TMP/list.out"
	"$ROOT/bin/dvm" config path >"$TMP/config-path.out"
	grep -Fxq "$DVM_CONFIG/config.sh" "$TMP/config-path.out"
	"$ROOT/bin/dvm" config print-defaults >"$TMP/defaults.out"
	grep -Fq 'DVM_AGENT_USER=' "$TMP/defaults.out"
	"$ROOT/bin/dvm" config print-template >"$TMP/template.out"
	grep -Fq 'local overrides only' "$TMP/template.out"
	"$ROOT/bin/dvm" config diff >"$TMP/config-diff.out"
done

cp "$ROOT/tests/fixtures/config-before-ai-checksums.sh" "$DVM_CONFIG/config.sh"
"$ROOT/bin/dvm" doctor >"$TMP/ai-host-doctor.out" 2>"$TMP/ai-host-doctor.err"
if grep -Fq 'DVM_AI_HOST=0.0.0.0 exposes' "$TMP/ai-host-doctor.err"; then
	echo "old fallback config pinned DVM_AI_HOST unexpectedly" >&2
	exit 1
fi

cat >"$DVM_CONFIG/config.sh" <<'CONFIG'
DVM_PREFIX="legacy"
DVM_GUEST_HOME="/home/tester"
DVM_CODE_DIR="/home/tester/code"
DVM_AI_HOST="0.0.0.0"
DVM_UNKNOWN_OPTION="typo"
CONFIG
"$ROOT/bin/dvm" doctor >"$TMP/pinned-doctor.out" 2>"$TMP/pinned-doctor.err"
grep -Fq 'DVM_AI_HOST=0.0.0.0 exposes' "$TMP/pinned-doctor.err"
grep -Fq 'unknown config variable in config.sh: DVM_UNKNOWN_OPTION' "$TMP/pinned-doctor.err"

awk '
	/^[[:space:]]*DVM_[A-Za-z0-9_]*=/ {
		name = $0
		sub(/=.*/, "", name)
		if (index($0, "${" name ":-") == 0) {
			print "default does not use fallback form: " $0 >"/dev/stderr"
			exit 1
		}
	}
' "$ROOT/defaults/config.sh"
