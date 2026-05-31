#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
ok() { printf 'ok - %s\n' "$*"; }

export HOME="$TMP/home"
export DVM_CONFIG_DIR="$TMP/config"
export DVM_CACHE_DIR="$TMP/cache"
export DVM_STATE_DIR="$TMP/state-dir"
mkdir -p "$TMP/bin" "$HOME" "$DVM_CONFIG_DIR/vms/app" "$DVM_CONFIG_DIR/vms/defaults-only" "$TMP/guest"

export DVM_TEST_STATE="$TMP/state"
export DVM_TEST_LOG="$TMP/limactl.log"
export DVM_TEST_GUEST="$TMP/guest"
: >"$DVM_TEST_STATE"
: >"$DVM_TEST_LOG"

cat >"$TMP/bin/limactl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

state="$DVM_TEST_STATE"
log="$DVM_TEST_LOG"
guest="$DVM_TEST_GUEST"

add_state() {
    grep -Fxq "$1" "$state" 2>/dev/null || printf '%s\n' "$1" >>"$state"
}

remove_state() {
    grep -Fxv "$1" "$state" >"$state.tmp" 2>/dev/null || true
    mv "$state.tmp" "$state"
}

log_argv() {
    printf -- '--- %s ---\n' "$1" >>"$log"
    shift
    for arg in "$@"; do printf '%s\n' "$arg" >>"$log"; done
}

# Skip global flags that dvm may pass before the subcommand (e.g. --log-level warn).
while [ "${1:-}" = "--log-level" ]; do shift 2; done

cmd="${1:-}"
shift || true

case "$cmd" in
    --version)
        echo "limactl version 2.0.0 (fake)"
        ;;
    list)
        case "${1:-}" in
            -q)
                cat "$state"
                ;;
            --format)
                while IFS= read -r name; do
                    [ -n "$name" ] || continue
                    printf '%s\tRunning\t4\t8GiB\n' "$name"
                done <"$state"
                ;;
            *)
                cat "$state"
                ;;
        esac
        ;;
    start)
        log_argv start "$@"
        name=
        prev=
        for arg in "$@"; do
            if [ "$prev" = "--name" ]; then name="$arg"; fi
            prev="$arg"
        done
        if [ -z "$name" ] && [ "$#" -eq 1 ]; then name="$1"; fi
        [ -n "$name" ] && add_state "$name"
        ;;
    shell)
        log_argv shell "$@"
        vm=
        needs_stdin=0
        for arg in "$@"; do
            case "$arg" in dvm-*) vm="$arg" ;; -s) needs_stdin=1 ;; esac
        done
        [ -n "$vm" ] || vm=unknown
        if [ "$needs_stdin" = "1" ]; then
            {
                printf -- '--- shell %s ---\n' "$vm"
                cat
            } >>"$guest/$vm.sh"
        fi
        ;;
    copy)
        log_argv copy "$@"
        ;;
    stop)
        log_argv stop "$@"
        ;;
    delete)
        log_argv delete "$@"
        name="${@: -1}"
        remove_state "$name"
        ;;
    *)
        log_argv unknown "$cmd" "$@"
        ;;
esac
EOF
chmod +x "$TMP/bin/limactl"
export PATH="$TMP/bin:$PATH"

cat >"$DVM_CONFIG_DIR/setup.sh" <<'EOF'
printf 'global setup for %s\n' "$DVM_NAME"
sudo -u "$DVM_USER" -H bash -lc 'mkdir -p "$HOME/.local/bin"'
EOF

cat >"$DVM_CONFIG_DIR/config.sh" <<EOF
DVM_GLOBAL_SETUP="$DVM_CONFIG_DIR/setup.sh"
EOF

cat >"$DVM_CONFIG_DIR/vms/app/setup.sh" <<'EOF'
sudo -u "$DVM_USER" -H bash -lc 'printf "%s\n" "$DVM_NAME" >"$HOME/.dvm-project"'
EOF

cat >"$DVM_CONFIG_DIR/vms/app/config.sh" <<EOF
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
EOF

cat >"$DVM_CONFIG_DIR/vms/defaults-only/config.sh" <<'EOF'
# No per-VM overrides.
EOF

run_dvm() {
    "$ROOT/bin/dvm" "$@"
}

bash -n "$ROOT/bin/dvm"
ok "shell syntax is valid"

out="$(run_dvm --help)"
case "$out" in *"sync"*"ssh"*"version"*) ok "help lists commands" ;; *) fail "help output is wrong" ;; esac
if run_dvm unknown-command >/dev/null 2>&1; then
    fail "unknown command succeeded"
fi
ok "unknown commands fail"

out="$(run_dvm version)"
case "$out" in "dvm "*-dev) ok "version prints development version" ;; *) fail "version output is wrong" ;; esac

out="$(DVM_DRY_RUN=1 run_dvm sync app)"
case "$out" in
    *"limactl start argv"*"--mount-none"*"--port-forward"*"3000:3000"*"template:fedora"*) ;;
    *) fail "dry-run missing Lima argv" ;;
esac
case "$out" in
    *"setup scripts:"*"global:"*"$DVM_CONFIG_DIR/setup.sh"*"vm:"*"$DVM_CONFIG_DIR/vms/app/setup.sh"*) ;;
    *) fail "dry-run missing setup script order" ;;
esac
[ ! -s "$DVM_TEST_LOG" ] || fail "dry-run called limactl"
ok "dry-run shows setup plan without contacting Lima"

NO_GLOBAL="$TMP/no-global"
mkdir -p "$NO_GLOBAL/vms"
mkdir -p "$NO_GLOBAL/vms/tiny"
printf '# tiny\n' >"$NO_GLOBAL/vms/tiny/config.sh"
DVM_CONFIG_DIR="$NO_GLOBAL" DVM_DRY_RUN=1 run_dvm sync tiny >/dev/null
ok "sync works without a global config file"

out="$(DVM_DRY_RUN=1 run_dvm sync defaults-only)"
case "$out" in *"global:"*"$DVM_CONFIG_DIR/setup.sh"*"vm:     <none>"*) ok "VM setup is optional" ;; *) fail "optional VM setup output wrong" ;; esac

run_dvm sync app
grep -Fxq -- "--name" "$DVM_TEST_LOG" || fail "start argv missing --name"
grep -Fxq -- "--mount-none" "$DVM_TEST_LOG" || fail "start argv missing --mount-none"
grep -Fxq -- "dvm-app" "$DVM_TEST_LOG" || fail "start argv missing dvm-app"
grep -Fxq -- "template:fedora" "$DVM_TEST_LOG" || fail "start argv missing template"
grep -Fxq -- "5173:5173" "$DVM_TEST_LOG" || fail "start argv missing second port"
grep -Fq -- 'sudo useradd -m -s /bin/bash -K SUB_UID_COUNT="$DVM_SUBUID_COUNT" -K SUB_GID_COUNT="$DVM_SUBGID_COUNT"' "$DVM_TEST_GUEST/dvm-app.sh" || fail "guest bootstrap missing user creation"
grep -Fq -- 'ensure_subid_range "$DVM_USER" /etc/subuid --add-subuids "$DVM_SUBUID_COUNT"' "$DVM_TEST_GUEST/dvm-app.sh" || fail "guest bootstrap missing subuid setup"
grep -Fq -- 'ensure_subid_range "$DVM_USER" /etc/subgid --add-subgids "$DVM_SUBGID_COUNT"' "$DVM_TEST_GUEST/dvm-app.sh" || fail "guest bootstrap missing subgid setup"
grep -Fq -- 'sudo install -d -o "$DVM_USER" -g "$group" "$DVM_CODE_DIR"' "$DVM_TEST_GUEST/dvm-app.sh" || fail "guest bootstrap missing project dir"
grep -Fq -- 'global setup for %s' "$DVM_TEST_GUEST/dvm-app.sh" || fail "global setup script did not run"
grep -Fq -- '.dvm-project' "$DVM_TEST_GUEST/dvm-app.sh" || fail "VM setup script did not run"
ok "sync starts VM and runs bootstrap plus setup scripts"

: >"$DVM_TEST_LOG"
run_dvm sh app >/dev/null
grep -Fq -- 'getent passwd "$USER"' "$DVM_TEST_LOG" || fail "sh command does not resolve login shell"
grep -Fq -- 'exec "$shell" -l' "$DVM_TEST_LOG" || fail "sh command does not exec login shell"
ok "sh opens DVM_USER login shell in the project directory"

: >"$DVM_TEST_LOG"
run_dvm ssh app -- echo hi >/dev/null
grep -Fxq -- "sudo" "$DVM_TEST_LOG" || fail "ssh command does not use sudo"
grep -Fxq -- "-u" "$DVM_TEST_LOG" || fail "ssh command missing user flag"
grep -Fxq -- "developer" "$DVM_TEST_LOG" || fail "ssh command does not run as DVM_USER"
grep -Fxq -- "/home/developer/code/app" "$DVM_TEST_LOG" || fail "ssh command missing project workdir"
ok "ssh commands run as DVM_USER in the project directory"

: >"$DVM_TEST_LOG"
printf 'hello\n' >"$TMP/local"
run_dvm cp "$TMP/local" app:/tmp/file >/dev/null
grep -Fxq -- "sudo" "$DVM_TEST_LOG" || fail "copy does not use sudo"
grep -Fxq -- "developer" "$DVM_TEST_LOG" || fail "copy does not run as DVM_USER"
grep -Fxq -- "/tmp/file" "$DVM_TEST_LOG" || fail "copy did not preserve absolute VM path"

: >"$DVM_TEST_LOG"
run_dvm cp "$TMP/local" app:notes.txt >/dev/null
grep -Fxq -- "/home/developer/code/app/notes.txt" "$DVM_TEST_LOG" || fail "copy did not resolve relative VM path in project directory"
ok "cp runs as DVM_USER and maps relative vm:path to the project directory"

mkdir -p "$DVM_CONFIG_DIR/vms/bad-port"
cat >"$DVM_CONFIG_DIR/vms/bad-port/config.sh" <<'EOF'
DVM_PORTS=(70000:3000)
EOF
if DVM_DRY_RUN=1 run_dvm sync bad-port >/dev/null 2>&1; then
    fail "invalid port accepted"
fi
ok "invalid port is rejected"

mkdir -p "$DVM_CONFIG_DIR/vms/bad-user"
cat >"$DVM_CONFIG_DIR/vms/bad-user/config.sh" <<'EOF'
DVM_USER='developer) NOPASSWD: ALL #'
EOF
if DVM_DRY_RUN=1 run_dvm sync bad-user >/dev/null 2>&1; then
    fail "invalid DVM_USER accepted"
fi
ok "invalid DVM_USER is rejected"

mkdir -p "$DVM_CONFIG_DIR/vms/bad-subuid"
cat >"$DVM_CONFIG_DIR/vms/bad-subuid/config.sh" <<'EOF'
DVM_SUBUID_COUNT=lots
EOF
if DVM_DRY_RUN=1 run_dvm sync bad-subuid >/dev/null 2>&1; then
    fail "invalid DVM_SUBUID_COUNT accepted"
fi
ok "invalid subordinate ID counts are rejected"

BAD_PERMS="$TMP/bad-perms"
mkdir -p "$BAD_PERMS/vms/app"
printf '# config\n' >"$BAD_PERMS/config.sh"
printf '# vm\n' >"$BAD_PERMS/vms/app/config.sh"
chmod g+w "$BAD_PERMS/config.sh"
if DVM_CONFIG_DIR="$BAD_PERMS" DVM_DRY_RUN=1 run_dvm sync app >/dev/null 2>&1; then
    fail "unsafe config permissions accepted"
fi
chmod g-w "$BAD_PERMS/config.sh"
printf '# setup\n' >"$BAD_PERMS/setup.sh"
printf 'DVM_GLOBAL_SETUP="%s/setup.sh"\n' "$BAD_PERMS" >"$BAD_PERMS/config.sh"
chmod o+w "$BAD_PERMS/setup.sh"
if DVM_CONFIG_DIR="$BAD_PERMS" DVM_DRY_RUN=1 run_dvm sync app >/dev/null 2>&1; then
    fail "unsafe global setup permissions accepted"
fi
printf '# vm setup\n' >"$BAD_PERMS/vms/app/setup.sh"
chmod g+w "$BAD_PERMS/vms/app/setup.sh"
if DVM_CONFIG_DIR="$BAD_PERMS" DVM_DRY_RUN=1 run_dvm sync app >/dev/null 2>&1; then
    fail "unsafe VM setup permissions accepted"
fi
ok "unsafe config and setup permissions are rejected"

out="$(run_dvm new fresh)"
[ -f "$DVM_CONFIG_DIR/vms/fresh/config.sh" ] || fail "new did not write config"
[ -f "$DVM_CONFIG_DIR/vms/fresh/setup.sh" ] || fail "new did not write setup script"
case "$out" in *"wrote"*"fresh/config.sh"*"wrote"*"fresh/setup.sh"*) ;; *) fail "new did not print written paths" ;; esac
grep -Fq 'DVM_CPUS=4' "$DVM_CONFIG_DIR/vms/fresh/config.sh" || fail "new config missing defaults"
grep -Fq 'DVM_SUBUID_COUNT=65536' "$DVM_CONFIG_DIR/vms/fresh/config.sh" || fail "new config missing rootless container example"
grep -Fq 'sudo dnf5 install -y' "$DVM_CONFIG_DIR/vms/fresh/setup.sh" || fail "new setup missing package example"
ok "new writes starter config and setup script"

run_dvm stop missing
ok "stop of missing VM is a no-op"

printf 'dvm-manual\n' >>"$DVM_TEST_STATE"
out="$(run_dvm ls --only-config)"
case "$out" in *"manual"*) fail "ls --only-config included unmanaged instance" ;; *) ok "ls --only-config filters unmanaged instances" ;; esac

: >"$DVM_TEST_LOG"
run_dvm stop --all --only-config
grep -Fxq -- "dvm-app" "$DVM_TEST_LOG" || fail "stop --all --only-config skipped configured VM"
! grep -Fxq -- "dvm-manual" "$DVM_TEST_LOG" || fail "stop --all --only-config stopped unmanaged VM"
ok "stop --all --only-config filters unmanaged instances"

out="$(run_dvm rm ghost --yes)"
case "$out" in *"no Lima instance: ghost"*) ok "rm reports missing VM" ;; *) fail "rm missing output wrong" ;; esac

printf 'dvm-orphan\n' >>"$DVM_TEST_STATE"
run_dvm rm orphan --yes >/dev/null
! grep -Fxq "dvm-orphan" "$DVM_TEST_STATE" || fail "rm did not delete orphan without config"
ok "rm works without a VM config file"

run_dvm rm fresh --yes >"$TMP/rm-fresh.out" 2>"$TMP/rm-fresh.err"
grep -Fq -- "warning: config remains" "$TMP/rm-fresh.err" || fail "rm did not warn about remaining config"
[ -d "$DVM_CONFIG_DIR/vms/fresh" ] || fail "rm deleted VM config directory without --config"
run_dvm rm fresh --yes --config >/dev/null
[ ! -e "$DVM_CONFIG_DIR/vms/fresh" ] || fail "rm --config did not remove VM config directory"
ok "rm warns about and optionally removes stale config and setup"

if DVM_LIMACTL=/no/such/limactl run_dvm ls >/dev/null 2>&1; then
    fail "missing limactl accepted"
fi
ok "commands fail clearly when limactl is missing"

printf 'all smoke tests passed\n'
