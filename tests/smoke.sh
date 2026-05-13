#!/usr/bin/env bash
# End-to-end smoke test for dvm with a fake limactl.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LIMACTL_LOG="$TMP/limactl.log"
STDIN_LOG="$TMP/stdin.log"

# Fake limactl: logs argv, drains stdin on `shell`, returns no instances on list.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/limactl" <<EOF
#!/usr/bin/env bash
{ printf '%q ' "\$@"; printf '\n'; } >> "$LIMACTL_LOG"
case "\$1" in
    --version) echo "limactl version 1.0.0 (fake)" ;;
    list)
        # Simulate one running VM when DVM_FAKE_HAS_VM is set.
        if [ "\${DVM_FAKE_HAS_VM:-0}" = "1" ]; then
            case "\$2" in
                -q) printf 'dvm-app\n' ;;
                --format) printf 'dvm-app\tRunning\t4\t8GiB\n' ;;
            esac
        fi
        ;;
    shell) cat > "$STDIN_LOG" ;;
esac
exit 0
EOF
chmod +x "$TMP/bin/limactl"

mkdir -p "$TMP/cfg/vms"
cat > "$TMP/cfg/vms/app.sh" <<'EOF'
DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=30GiB
DVM_PORTS=(3000:3000 5173:5173)
DVM_PACKAGES=(git tmux)
DVM_RECIPES=(node-corepack)
EOF

cat > "$TMP/cfg/vms/cloud.sh" <<'EOF'
DVM_CPUS=2
DVM_MEMORY=2GiB
DVM_DISK=10GiB
DVM_RECIPES=(cloudflared)
DVM_SECRETS=(DVM_CLOUDFLARED_TOKEN)
EOF

run_dvm() {
    PATH="$TMP/bin:$PATH" \
    DVM_CONFIG_DIR="$TMP/cfg" \
    DVM_SHARE_DIR="$ROOT/share/dvm" \
    DVM_CACHE_DIR="$TMP/cache" \
    "$ROOT/bin/dvm" "$@"
}

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok()   { printf 'ok: %s\n' "$*"; }

# --- help -------------------------------------------------------------------
out="$(run_dvm help)"
case "$out" in *"sync"*"sh"*"recipes"*) ok "help lists commands" ;; *) fail "help" ;; esac

# --- sync renders YAML and pipes guest script ------------------------------
: > "$LIMACTL_LOG"; : > "$STDIN_LOG"
run_dvm sync app >/dev/null
grep -q "create --name dvm-app"     "$LIMACTL_LOG" || fail "no create call"
grep -q "start dvm-app"             "$LIMACTL_LOG" || fail "no start call"
grep -q "shell --workdir / dvm-app" "$LIMACTL_LOG" || fail "no shell call"
ok "sync app issued create/start/shell"

# YAML content
yaml="$TMP/cache/app.yaml"
[ -f "$yaml" ] || fail "no rendered yaml"
grep -q "cpus: 4"                "$yaml" || fail "yaml missing cpus"
grep -q 'memory: "8GiB"'         "$yaml" || fail "yaml missing memory"
grep -q "hostnamectl set-hostname app.dvm" "$yaml" || fail "yaml missing hostname"
grep -q "hostPort: 3000"         "$yaml" || fail "yaml missing port"
grep -q '/home/developer/code/app' "$yaml" || fail "yaml missing guest code_dir"
ok "rendered yaml has resources, ports, hostname, code_dir"

# Guest script
bash -n "$STDIN_LOG"
grep -q 'export DVM_VM=app'         "$STDIN_LOG" || fail "stdin missing DVM_VM"
grep -q 'dvm_pkg git tmux'          "$STDIN_LOG" || fail "stdin missing dvm_pkg call"
grep -q '# >>> recipe: node-corepack' "$STDIN_LOG" || fail "stdin missing recipe header"
ok "guest stdin passes bash -n and contains packages + recipe"

# --- secrets staging -------------------------------------------------------
: > "$LIMACTL_LOG"; : > "$STDIN_LOG"
DVM_CLOUDFLARED_TOKEN="testtok" run_dvm sync cloud >/dev/null
grep -q "install -m 600 -o developer /dev/stdin /tmp/dvm-secret-DVM_CLOUDFLARED_TOKEN" "$LIMACTL_LOG" \
    || fail "secret not staged via limactl shell install"
# Token value must NOT appear in argv log.
if grep -q "testtok" "$LIMACTL_LOG"; then fail "secret value leaked to argv log"; fi
ok "secret staged via install -m 600 with no argv leak"

# --- dry-run prints script without contacting Lima -------------------------
: > "$LIMACTL_LOG"
script="$(DVM_DRY_RUN=1 run_dvm sync app)"
case "$script" in *"set -euo pipefail"*"node-corepack"*) ok "dry-run emits script" ;; *) fail "dry-run output" ;; esac
case "$(cat "$LIMACTL_LOG")" in '') ok "dry-run did not call limactl" ;; *) fail "dry-run called limactl" ;; esac

# --- ls + filter ----------------------------------------------------------
: > "$LIMACTL_LOG"
DVM_FAKE_HAS_VM=1 run_dvm ls | grep -q "^app " || fail "ls missing app"
DVM_FAKE_HAS_VM=1 run_dvm ls app | grep -q "^app " || fail "ls <vm> filter"
ok "ls and ls <vm> work"

# --- stop, rm, sync --all --------------------------------------------------
: > "$LIMACTL_LOG"
run_dvm stop app >/dev/null
grep -q "stop dvm-app" "$LIMACTL_LOG" || fail "stop didn't call limactl"
ok "stop forwards to limactl"

: > "$LIMACTL_LOG"
DVM_FAKE_HAS_VM=1 run_dvm rm app --yes >/dev/null
grep -q "delete --force dvm-app" "$LIMACTL_LOG" || fail "rm didn't delete"
ok "rm --yes deletes instance"

: > "$LIMACTL_LOG"; : > "$STDIN_LOG"
DVM_CLOUDFLARED_TOKEN=tok run_dvm sync --all >/dev/null
[ "$(grep -c "create --name " "$LIMACTL_LOG")" -ge 2 ] || fail "sync --all didn't iterate"
ok "sync --all iterates over per-VM configs"

# --- cp parsing ------------------------------------------------------------
: > "$LIMACTL_LOG"
run_dvm cp ./local app:/guest >/dev/null
grep -qE "copy ./local dvm-app:/guest" "$LIMACTL_LOG" || fail "cp host->guest rewrite"
ok "cp rewrites vm:path to dvm-vm:path"

# --- cp rejects two local paths -------------------------------------------
if run_dvm cp ./a ./b >/dev/null 2>&1; then fail "cp should reject two local paths"; fi
ok "cp rejects two local paths"

# --- invalid VM name -------------------------------------------------------
if run_dvm sync "Bad-Name" >/dev/null 2>&1; then fail "should reject invalid VM name"; fi
ok "rejects invalid VM name"

# --- recipes list ----------------------------------------------------------
run_dvm recipes | grep -q "agent-user" || fail "recipes missing agent-user"
ok "recipes lists agent-user"

# --- key backup on rm (default) -----------------------------------
rm -rf "$TMP/cfg/backups"
: > "$LIMACTL_LOG"
DVM_FAKE_HAS_VM=1 run_dvm rm app --yes >/dev/null
grep -q 'id_ed25519_dvm_signing.pub' "$LIMACTL_LOG" \
    || fail "rm did not attempt to back up SSH keys"
[ -d "$TMP/cfg/backups/app" ] || fail "no backup dir created"
ok "rm backs up keys and creates backup dir"

# --- --no-backup skips backup ---------------------------------------
rm -rf "$TMP/cfg/backups"
: > "$LIMACTL_LOG"
DVM_FAKE_HAS_VM=1 run_dvm rm app --yes --no-backup >/dev/null
if grep -q 'id_ed25519_dvm_signing.pub' "$LIMACTL_LOG"; then
    fail "--no-backup should skip backup_keys"
fi
ok "rm --no-backup skips backup"

# --- sync restores keys from backup --------------------------------
mkdir -p "$TMP/cfg/backups/app/ssh"
echo "fake-priv-key-content" > "$TMP/cfg/backups/app/ssh/id_ed25519_dvm"
chmod 0600 "$TMP/cfg/backups/app/ssh/id_ed25519_dvm"
: > "$LIMACTL_LOG"; : > "$STDIN_LOG"
run_dvm sync app >/dev/null
grep -q 'install -m 0600 /dev/stdin' "$LIMACTL_LOG" \
    || fail "sync did not call install -m 0600 for restore"
ok "sync restores keys from backup dir on recreate"

# --- absolute-target symlink to bin/dvm works (regression: install.sh path) -
ln -sfn "$ROOT/bin/dvm" "$TMP/bin/dvm-link"
PATH="$TMP/bin:$PATH" \
DVM_CONFIG_DIR="$TMP/cfg" \
DVM_SHARE_DIR="$ROOT/share/dvm" \
DVM_CACHE_DIR="$TMP/cache" \
"$TMP/bin/dvm-link" help >/dev/null 2>&1 \
    || fail "dvm broken when launched through absolute-target symlink"
ok "works through absolute-target symlink"

# --- project hook is emitted in the guest script -------------------------
: > "$LIMACTL_LOG"; : > "$STDIN_LOG"
run_dvm sync app >/dev/null
grep -q '/.dvm/sync.sh' "$STDIN_LOG" || fail "project hook missing from guest script"
ok "project hook check appears in guest stdin"

# --- secret name validation ---------------------------------------------
cat > "$TMP/cfg/vms/bad.sh" <<'EOF'
DVM_RECIPES=()
DVM_SECRETS=("bad name")
EOF
if BAD_SECRET=x run_dvm sync bad >/dev/null 2>&1; then
    fail "should reject malformed secret name"
fi
ok "rejects malformed DVM_SECRETS entry"

# --- cp does not misparse local paths with colons -----------------------
: > "$LIMACTL_LOG"
# Source has a colon but is not a VM ref (uppercase, no valid VM prefix);
# treated as local, so cp must reject for missing VM side.
if run_dvm cp ./Foo:bar ./baz >/dev/null 2>&1; then
    fail "cp should reject when neither path looks like a VM ref"
fi
ok "cp does not misparse local paths containing :"

# --- cp rejects cross-VM ------------------------------------------------
if run_dvm cp app:/a other:/b >/dev/null 2>&1; then
    fail "cp should reject cross-VM"
fi
ok "cp rejects cross-VM"

# --- help and recipes do not invoke flock/envsubst -------------------
# bash -x traces show which external tools each command touches at dispatch.
trace="$(bash -x "$ROOT/bin/dvm" help 2>&1 >/dev/null || true)"
case "$trace" in *flock*|*envsubst*) fail "help triggered flock/envsubst" ;; esac
trace="$(bash -x "$ROOT/bin/dvm" recipes 2>&1 >/dev/null || true)"
case "$trace" in *flock*|*envsubst*) fail "recipes triggered flock/envsubst" ;; esac
ok "help/recipes don't invoke flock or envsubst"

printf '\nall tests passed\n'
