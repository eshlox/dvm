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
        # Minimal stateful podman: guest_podman passes a standalone "podman" arg,
        # so track container existence to make create/exists/rm behave across
        # calls (image exists always misses, so the dev-base build path runs).
        pcmd=(); seen=0
        for arg in "$@"; do
            if [ "$seen" = 1 ]; then pcmd+=("$arg"); fi
            if [ "$arg" = podman ]; then seen=1; fi
        done
        if [ "${#pcmd[@]}" -gt 0 ]; then
            cstate="$state.containers"; touch "$cstate"
            case "${pcmd[0]} ${pcmd[1]:-}" in
                "container exists") grep -Fxq "${pcmd[2]:-}" "$cstate" || exit 1 ;;
                "image exists") exit 1 ;;
            esac
            if [ "${pcmd[0]}" = create ]; then
                prev=
                for a in "${pcmd[@]}"; do
                    if [ "$prev" = --name ]; then printf '%s\n' "$a" >>"$cstate"; fi
                    prev="$a"
                done
            elif [ "${pcmd[0]}" = rm ]; then
                last="${pcmd[$((${#pcmd[@]} - 1))]}"
                grep -Fxv "$last" "$cstate" >"$cstate.t" 2>/dev/null || true
                mv "$cstate.t" "$cstate"
            fi
        fi
        ;;
    copy)
        log_argv copy "$@"
        # When the destination is a host path (absolute, no instance: prefix),
        # create it so the caller's atomic rename of an extracted artifact works.
        dst="${@: -1}"
        case "$dst" in
            /*) printf 'fake-qcow2\n' >"$dst" ;;
        esac
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

# uname shim so the arch-mapping test can simulate Apple Silicon (arm64) on a
# Linux CI host. Passes through to the real uname unless FAKE_UNAME_M is set.
cat >"$TMP/bin/uname" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-m" ] && [ -n "${FAKE_UNAME_M:-}" ]; then
    printf '%s\n' "$FAKE_UNAME_M"
    exit 0
fi
exec /usr/bin/uname "$@"
EOF
chmod +x "$TMP/bin/uname"

export PATH="$TMP/bin:$PATH"

cat >"$DVM_CONFIG_DIR/config.sh" <<'EOF'
# Global config.
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
case "$out" in
    "dvm "[0-9]*.[0-9]*.[0-9]*) ok "version prints a semver" ;;
    *) fail "version output is wrong" ;;
esac

out="$(DVM_DRY_RUN=1 run_dvm sync app)"
case "$out" in
    *"limactl start argv"*"--mount-none"*"--port-forward"*"3000:3000"*"template:fedora"*) ;;
    *) fail "dry-run missing Lima argv" ;;
esac
case "$out" in
    *"setup script: $DVM_CONFIG_DIR/vms/app/setup.sh"*) ;;
    *) fail "dry-run missing setup script" ;;
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
case "$out" in *"setup script: <none>"*) ok "VM setup is optional" ;; *) fail "optional VM setup output wrong" ;; esac

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
grep -Fq -- '.dvm-project' "$DVM_TEST_GUEST/dvm-app.sh" || fail "VM setup script did not run"
ok "sync starts VM and runs bootstrap plus the VM setup script"

# Logs may capture setup output that includes secrets; the state dir and logs
# must be readable only by the owner regardless of umask.
[ "$(stat -c '%a' "$DVM_STATE_DIR/app")" = "700" ] || fail "per-VM state dir is not owner-only"
[ "$(stat -c '%a' "$DVM_STATE_DIR/app/lima.log")" = "600" ] || fail "lima log is not owner-only"
[ "$(stat -c '%a' "$DVM_STATE_DIR/app/setup.log")" = "600" ] || fail "setup log is not owner-only"
ok "sync writes logs and state dir readable only by the owner"

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

: >"$DVM_TEST_LOG"
run_dvm cp "$TMP/local" app: >/dev/null
grep -Fxq -- "/home/developer/code/app" "$DVM_TEST_LOG" || fail "copy to bare vm: did not resolve to the project directory"
ok "cp to a bare vm: target resolves to the project directory"

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
printf '# vm setup\n' >"$BAD_PERMS/vms/app/setup.sh"
chmod g+w "$BAD_PERMS/vms/app/setup.sh"
if DVM_CONFIG_DIR="$BAD_PERMS" DVM_DRY_RUN=1 run_dvm sync app >/dev/null 2>&1; then
    fail "unsafe VM setup permissions accepted"
fi
ok "unsafe config and setup permissions are rejected"

out="$(run_dvm new fresh)"
[ -f "$DVM_CONFIG_DIR/vms/fresh/config.sh" ] || fail "new did not write config"
[ -f "$DVM_CONFIG_DIR/vms/fresh/setup.sh" ] || fail "new did not write setup script"
case "$out" in *"wrote"*"vms/fresh/{config.sh,setup.sh}"*) ;; *) fail "new did not print written paths" ;; esac
grep -Fq '# DVM_CPUS=2' "$DVM_CONFIG_DIR/vms/fresh/config.sh" || fail "new config missing commented resource override"
grep -Fq '# DVM_PORTS=' "$DVM_CONFIG_DIR/vms/fresh/config.sh" || fail "new config missing commented port example"
grep -Eq '^[^#]*DVM_CPUS=' "$DVM_CONFIG_DIR/vms/fresh/config.sh" && fail "new config should not set resources, only inherit"
grep -Fq 'sudo dnf5 install -y' "$DVM_CONFIG_DIR/vms/fresh/setup.sh" || fail "new setup missing package example"
ok "new writes starter config and setup script"

NEW_GLOBAL="$TMP/new-global"
mkdir -p "$NEW_GLOBAL"
out="$(DVM_CONFIG_DIR="$NEW_GLOBAL" run_dvm new first)"
[ -f "$NEW_GLOBAL/config.sh" ] || fail "new did not auto-create global config"
grep -Eq '^DVM_USER=' "$NEW_GLOBAL/config.sh" || fail "auto-created global config missing DVM_USER"
case "$out" in *"wrote"*"config.sh (global)"*) ;; *) fail "new did not report global config creation" ;; esac
out="$(DVM_CONFIG_DIR="$NEW_GLOBAL" run_dvm new second)"
case "$out" in *"(global)"*) fail "new recreated existing global config" ;; *) ;; esac
ok "new auto-creates the global config once"

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

# A stale global setup.sh is no longer used; sync warns instead of silently
# dropping it.
printf '# legacy global setup\n' >"$DVM_CONFIG_DIR/setup.sh"
err="$(DVM_DRY_RUN=1 run_dvm sync app 2>&1 >/dev/null)"
case "$err" in *"is no longer used"*) ok "sync warns about a stale global setup.sh" ;; *) fail "missing stale global setup.sh warning" ;; esac
rm -f "$DVM_CONFIG_DIR/setup.sh"

# --- base image ---
if run_dvm base build >/dev/null 2>&1; then
    fail "base build accepted without a Containerfile"
fi
ok "base build requires a Containerfile"

out="$(run_dvm base init)"
[ -f "$DVM_CONFIG_DIR/base/Containerfile" ] || fail "base init did not write Containerfile"
grep -Fq 'FROM dvm-base' "$DVM_CONFIG_DIR/base/Containerfile" || fail "base Containerfile missing FROM dvm-base"
case "$out" in *"wrote"*"base/Containerfile"*) ;; *) fail "base init did not report the written path" ;; esac
if run_dvm base init >/dev/null 2>&1; then
    fail "base init overwrote an existing Containerfile"
fi
ok "base init scaffolds the Containerfile once"

: >"$DVM_TEST_GUEST/dvm-builder.sh"
run_dvm base build >/dev/null
grep -Fxq -- "dvm-builder" "$DVM_TEST_STATE" || fail "base build did not create the builder instance"
b="$DVM_TEST_GUEST/dvm-builder.sh"
grep -Fq 'podman build' "$b" || fail "base build did not run podman build in the builder"
grep -Fq 'Containerfile.dvm-base' "$b" || fail "base build did not build the dvm-base plumbing layer"
grep -Fq -- '-t dvm-target' "$b" || fail "base build did not build the target image"
grep -Fq 'bootc-image-builder' "$b" || fail "base build did not invoke bootc-image-builder"
grep -Fq '@sha256:' "$b" || fail "base build did not use digest-pinned upstream images"
[ -f "$DVM_CACHE_DIR/base/disk.qcow2" ] || fail "base build did not produce the qcow2"
[ -f "$DVM_CACHE_DIR/base/metadata.json" ] || fail "base build did not write metadata"
ok "base build provisions a builder and produces the qcow2"

[ "$(stat -c '%a' "$DVM_STATE_DIR/base/build.log")" = "600" ] || fail "base build log is not owner-only"
ok "base build log is readable only by the owner"

out="$(run_dvm base status)"
case "$out" in *"base image:"*"disk.qcow2"*) ok "base status reports the cached image" ;; *) fail "base status output wrong" ;; esac

# With a base image present, sync boots the generated template, not template:fedora.
out="$(DVM_DRY_RUN=1 run_dvm sync app)"
case "$out" in
    *"base image:"*"$DVM_CACHE_DIR/base/template.yaml"*) ;;
    *) fail "sync did not use the base image template" ;;
esac
case "$out" in *"template:fedora"*) fail "sync still used template:fedora with a base image present" ;; *) ;; esac
ok "sync boots from the base image when one exists"

# DVM_VM_TYPE flows into the Lima start argv.
out="$(DVM_VM_TYPE=vz DVM_DRY_RUN=1 run_dvm sync app)"
case "$out" in *"--vm-type"*"vz"*) ok "DVM_VM_TYPE is passed to limactl" ;; *) fail "DVM_VM_TYPE not passed to limactl" ;; esac

# The generated template uses Lima's canonical arch. Simulate Apple Silicon
# (arm64) and confirm it is normalized to aarch64. defaults-only has no instance
# yet, so its first sync takes the create path that writes the template.
FAKE_UNAME_M=arm64 run_dvm sync defaults-only >/dev/null
grep -Fq 'arch: "aarch64"' "$DVM_CACHE_DIR/base/template.yaml" || fail "base template arch not normalized to aarch64"
! grep -Fq 'arm64' "$DVM_CACHE_DIR/base/template.yaml" || fail "base template leaked the raw uname arch"
ok "base template normalizes host arch to Lima's canonical value"

# Names that collide with the base-image workflow are refused everywhere, even
# though a dvm-builder instance exists.
if run_dvm new builder >/dev/null 2>&1; then fail "new accepted the reserved builder name"; fi
if run_dvm new base >/dev/null 2>&1; then fail "new accepted the reserved base name"; fi
if run_dvm sync builder >/dev/null 2>&1; then fail "sync operated on the builder"; fi
if run_dvm rm builder --yes >/dev/null 2>&1; then fail "rm operated on the builder"; fi
grep -Fxq -- "dvm-builder" "$DVM_TEST_STATE" || fail "guard removed the builder instance"
ok "VM commands refuse reserved base/builder names"

out="$(run_dvm ls)"
case "$out" in *"builder"*) fail "ls listed the builder instance" ;; *) ok "ls hides the builder instance" ;; esac

# base rm --image removes the configured image by exact path, honoring a custom
# DVM_BASE_IMAGE outside the default cache.
CUSTOM_IMG="$TMP/custom/base.qcow2"
mkdir -p "$(dirname "$CUSTOM_IMG")"
printf 'img\n' >"$CUSTOM_IMG"
DVM_BASE_IMAGE="$CUSTOM_IMG" run_dvm base rm --image >/dev/null
[ ! -e "$CUSTOM_IMG" ] || fail "base rm --image ignored a custom DVM_BASE_IMAGE"
ok "base rm --image honors a custom DVM_BASE_IMAGE"

# --- project containers ---
run_dvm new pool >/dev/null
out="$(run_dvm add pool/api)"
[ -f "$DVM_CONFIG_DIR/vms/pool/projects/api/project.sh" ] || fail "add did not write project.sh"
[ -f "$DVM_CONFIG_DIR/vms/pool/projects/api/setup.sh" ] || fail "add did not write project setup.sh"
case "$out" in *"wrote"*"projects/api/{project.sh,setup.sh}"*) ;; *) fail "add did not report written paths" ;; esac
ok "add scaffolds a project under a VM"

if run_dvm add pool >/dev/null 2>&1; then fail "add accepted a non-project spec"; fi
if run_dvm add nope/api >/dev/null 2>&1; then fail "add accepted a project under a missing VM"; fi
if run_dvm reset pool/api >/dev/null 2>&1; then fail "reset without --yes succeeded"; fi
if run_dvm ssh pool/api >/dev/null 2>&1; then fail "ssh into project without a command succeeded"; fi
if run_dvm logs >/dev/null 2>&1; then fail "logs without a spec succeeded"; fi
ok "project command guards reject bad invocations"

cat >"$DVM_CONFIG_DIR/vms/pool/projects/api/project.sh" <<'EOF'
IMAGE=node:22
NESTED=1
PROJ_PORTS=(3000:3000)
EOF

: >"$DVM_TEST_LOG"
run_dvm sync pool >/dev/null
grep -Fxq -- "dvm-pool" "$DVM_TEST_STATE" || fail "sync did not create the pool VM"
grep -Fq -- 'loginctl enable-linger' "$DVM_TEST_GUEST/dvm-pool.sh" || fail "sync did not enable linger for rootless podman"
grep -Fq -- 'podman-restart.service' "$DVM_TEST_GUEST/dvm-pool.sh" || fail "sync did not enable podman-restart"
grep -Fxq -- "--restart=always" "$DVM_TEST_LOG" || fail "project container missing restart policy"
grep -Fxq -- "node:22" "$DVM_TEST_LOG" || fail "project container did not use IMAGE override"
grep -Fxq -- "/dev/fuse" "$DVM_TEST_LOG" || fail "NESTED project missing /dev/fuse"
grep -Fxq -- "127.0.0.1:3000:3000" "$DVM_TEST_LOG" || fail "project container missing published port"
grep -Fxq -- "dvm-pool-api:/work" "$DVM_TEST_LOG" || fail "project container missing workspace volume"
ok "sync creates project containers with image, ports, nesting, and a workspace volume"

out="$(run_dvm ls pool)"
case "$out" in *"api"*) ok "ls <vm> lists project containers" ;; *) fail "ls <vm> did not list projects" ;; esac

: >"$DVM_TEST_LOG"
run_dvm sh pool/api >/dev/null
grep -Fq -- 'podman exec -it' "$DVM_TEST_LOG" || fail "sh did not exec into the project container"
ok "sh opens a shell inside the project container"

: >"$DVM_TEST_LOG"
run_dvm ssh pool/api -- echo hello >/dev/null
grep -Fq -- 'podman exec -w' "$DVM_TEST_LOG" || fail "ssh did not exec into the project container"
grep -Fxq -- "hello" "$DVM_TEST_LOG" || fail "ssh did not pass the command"
ok "ssh runs a command inside the project container"

: >"$DVM_TEST_LOG"
run_dvm logs pool/api >/dev/null
grep -Fxq -- "logs" "$DVM_TEST_LOG" || fail "logs did not call podman logs"
ok "logs shows a project container's logs"

: >"$DVM_TEST_LOG"
run_dvm stop pool/api >/dev/null
grep -Fxq -- "stop" "$DVM_TEST_LOG" || fail "stop did not stop the project container"
ok "stop stops a single project container"

: >"$DVM_TEST_LOG"
printf 'hi\n' >"$TMP/cpfile"
run_dvm cp "$TMP/cpfile" pool/api:/work/x >/dev/null
grep -Fxq -- "cp" "$DVM_TEST_LOG" || fail "cp did not invoke podman cp"
grep -Fq -- 'api:/work/x' "$DVM_TEST_LOG" || fail "cp did not target the container path"
ok "cp copies a file into a project container"

: >"$DVM_TEST_LOG"
run_dvm reset pool/api --yes >/dev/null
grep -Fxq -- "rm" "$DVM_TEST_LOG" || fail "reset did not remove the old container"
grep -Fxq -- "--restart=always" "$DVM_TEST_LOG" || fail "reset did not recreate the container"
ok "reset recreates a project container"

: >"$DVM_TEST_LOG"
run_dvm rm pool/api --yes >/dev/null
grep -Fxq -- "rm" "$DVM_TEST_LOG" || fail "rm did not remove the project container"
[ -f "$DVM_CONFIG_DIR/vms/pool/projects/api/project.sh" ] || fail "rm removed the project config without --config"
ok "rm removes a project container and keeps config"

# dev-base: tools defined once in packages.txt, built into the VM and shared.
run_dvm base dev-init >/dev/null
[ -f "$DVM_CONFIG_DIR/base/dev/Containerfile" ] || fail "base dev-init did not write the dev Containerfile"
[ -f "$DVM_CONFIG_DIR/base/packages.txt" ] || fail "base dev-init did not ensure packages.txt"
grep -Fq 'dvm-packages.txt' "$DVM_CONFIG_DIR/base/dev/Containerfile" || fail "dev Containerfile does not install from packages.txt"
grep -Fq 'dvm-packages.txt' "$DVM_CONFIG_DIR/base/Containerfile" || fail "VM Containerfile does not install from packages.txt"
: >"$DVM_TEST_LOG"
DVM_REBUILD_DEV_BASE=1 run_dvm sync pool >/dev/null
grep -Fq 'podman build' "$DVM_TEST_LOG" || fail "sync did not build the dev-base image"
grep -Fq 'localhost/dvm-dev-base' "$DVM_TEST_LOG" || fail "sync did not tag the dev-base image"
ok "dev-base image is built into the VM from the shared packages.txt"

run_dvm base rm --image >/dev/null
[ ! -e "$DVM_CACHE_DIR/base/disk.qcow2" ] || fail "base rm --image left the cached image"
ok "base rm --image removes the cached image"

# scripts/update-pins must actually rewrite the digest pins (regression guard:
# the rewrite once silently no-opped on a mismatched pattern). Run it against a
# throwaway copy with a stubbed crane on PATH.
PIN_ROOT="$TMP/pinroot"
mkdir -p "$PIN_ROOT/bin" "$PIN_ROOT/scripts"
cp "$ROOT/bin/dvm" "$PIN_ROOT/bin/dvm"
cp "$ROOT/scripts/update-pins" "$PIN_ROOT/scripts/update-pins"
FAKE_DIGEST="sha256:$(printf 'c%.0s' {1..64})"
cat >"$TMP/bin/crane" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$FAKE_DIGEST"
EOF
chmod +x "$TMP/bin/crane"
bash "$PIN_ROOT/scripts/update-pins" >/dev/null
grep -Fq "$FAKE_DIGEST" "$PIN_ROOT/bin/dvm" || fail "update-pins did not write the resolved digest"
! grep -Fq 'REPLACE_WITH_DIGEST' "$PIN_ROOT/bin/dvm" || fail "update-pins left a placeholder digest"
grep -Fq '# track: quay.io/fedora/fedora-bootc:42' "$PIN_ROOT/bin/dvm" || fail "update-pins dropped a track comment"
rm -f "$TMP/bin/crane"
ok "update-pins rewrites the digest pins"

printf 'all smoke tests passed\n'
