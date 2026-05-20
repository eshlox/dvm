#!/usr/bin/env bash
# End-to-end smoke test for dvm with a fake limactl.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
ok() { printf 'ok - %s\n' "$*"; }

export HOME="$TMP/home"
export DVM_CONFIG_DIR="$TMP/config"
export DVM_CACHE_DIR="$TMP/cache"
export DVM_SHARE_DIR="$ROOT/share/dvm"
export EDITOR=:
export VISUAL=
mkdir -p "$TMP/bin" "$HOME" "$DVM_CONFIG_DIR/vms" "$DVM_CONFIG_DIR/recipes" "$TMP/guest"

export DVM_TEST_STATE="$TMP/state"
export DVM_TEST_LOG="$TMP/limactl.log"
export DVM_TEST_GUEST="$TMP/guest"
: >"$DVM_TEST_STATE"
: >"$DVM_TEST_LOG"

cat >"$TMP/bin/limactl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

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

case "${1:-}" in
    --version)
        echo "limactl version 2.0.0 (fake)"
        ;;
    list)
        shift
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
        if [ -z "$name" ] && [ "${2:-}" ]; then name="$2"; fi
        [ -n "$name" ] && add_state "$name"
        ;;
    clone)
        log_argv clone "$@"
        name="${@: -1}"
        add_state "$name"
        ;;
    shell)
        log_argv shell "$@"
        vm=
        args=("$@")
        for ((i=0; i<${#args[@]}; i++)); do
            case "${args[$i]}" in
                dvm-*) vm="${args[$i]}" ;;
            esac
        done
        [ -n "$vm" ] || vm=unknown
        if printf '%s\n' "$@" | grep -Fxq 'bash'; then
            cat >"$guest/$vm.sh"
        elif printf '%s\n' "$@" | grep -Fxq 'install'; then
            dest="${@: -1}"
            cat >"$guest/${dest##*/}"
        else
            cat >/dev/null || true
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
        log_argv unknown "$@"
        ;;
esac
EOF
chmod +x "$TMP/bin/limactl"
export PATH="$TMP/bin:$PATH"

cat >"$DVM_CONFIG_DIR/config.sh" <<'EOF'
DVM_TEMPLATE=template:fedora
DVM_DEFAULT_PACKAGES=(git)
DVM_DEFAULT_RECIPES=(zsh fzf)
DVM_BASE_PACKAGES=(git ripgrep)
DVM_BASE_RECIPES=(zsh)
EOF

cat >"$DVM_CONFIG_DIR/vms/app.sh" <<'EOF'
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
DVM_PACKAGES=(tmux)
DVM_RECIPES=(node codex)
DVM_GIT_REPO="https://example.invalid/app.git"
EOF

cat >"$DVM_CONFIG_DIR/vms/cloud.sh" <<'EOF'
DVM_RECIPES=(tailscale cloudflare)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY DVM_CLOUDFLARED_TOKEN)
EOF

run_dvm() {
    "$ROOT/bin/dvm" "$@"
}

bash -n "$ROOT/bin/dvm"
for f in "$ROOT/share/dvm/prelude.sh" "$ROOT/share/dvm/recipes/"*.sh; do
    bash -n "$f"
done
ok "shell syntax is valid"

out="$(run_dvm --help)"
case "$out" in *"sync"*"recipes"*"doctor"*) ok "help lists current commands" ;; *) fail "help output is wrong" ;; esac

out="$(run_dvm recipes)"
case "$out" in *"agent-user"*"codex"*"tailscale"*) ok "recipes lists built-ins" ;; *) fail "recipes output missing built-ins" ;; esac
case "$out" in *"Aliases:"*"cloudflare"*"cloudflared"*"ssh-key"*"ssh-keys"*) ok "recipes lists aliases" ;; *) fail "recipes output missing aliases" ;; esac

out="$(DVM_DRY_RUN=1 run_dvm sync app)"
case "$out" in
    *"limactl start argv"*"--mount-none"*"--port-forward"*"3000:3000"*"template:fedora"*) ;;
    *) fail "dry-run missing Lima argv" ;;
esac
case "$out" in
    *"# >>> recipe: zsh"*"# >>> recipe: fzf"*"# >>> recipe: node"*"# >>> recipe: codex"*) ;;
    *) fail "dry-run missing recipes" ;;
esac
case "$out" in *"dvm_pkg git tmux"*'git clone "$DVM_GIT_REPO"'*) ok "dry-run prints guest script" ;; *) fail "dry-run guest script wrong" ;; esac
case "$out" in *"sudo dnf5 install -y"*) ok "guest script uses dnf5 only" ;; *) fail "guest script missing dnf5 package helper" ;; esac
case "$out" in *"apt-get"*|*"sudo dnf install"*) fail "guest script contains non-dnf5 package-manager fallback" ;; *) ok "guest script has no apt/dnf fallback" ;; esac
[ ! -s "$DVM_TEST_LOG" ] || fail "dry-run called limactl"
ok "dry-run does not contact Lima"

NO_GLOBAL="$TMP/no-global"
mkdir -p "$NO_GLOBAL/vms"
printf 'DVM_RECIPES=(bat)\n' >"$NO_GLOBAL/vms/tiny.sh"
DVM_CONFIG_DIR="$NO_GLOBAL" DVM_DRY_RUN=1 run_dvm sync tiny >/dev/null
ok "sync works without a global config file"

run_dvm sync app
grep -Fxq -- "--name" "$DVM_TEST_LOG" || fail "start argv missing --name"
grep -Fxq -- "--mount-none" "$DVM_TEST_LOG" || fail "start argv missing --mount-none"
grep -Fxq -- "dvm-app" "$DVM_TEST_LOG" || fail "start argv missing dvm-app"
grep -Fxq -- "template:fedora" "$DVM_TEST_LOG" || fail "start argv missing template"
grep -Fxq -- "5173:5173" "$DVM_TEST_LOG" || fail "start argv missing second port"
grep -Fq -- "# >>> recipe: codex" "$DVM_TEST_GUEST/dvm-app.sh" || fail "guest script missing codex"
grep -Fq -- 'git clone "$DVM_GIT_REPO"' "$DVM_TEST_GUEST/dvm-app.sh" || fail "guest script missing git clone"
ok "sync starts VM and renders package/recipe script"

DVM_TAILSCALE_AUTHKEY=tskey-test DVM_CLOUDFLARED_TOKEN=cf-test run_dvm sync cloud
grep -Fq -- "# >>> recipe: cloudflare" "$DVM_TEST_GUEST/dvm-cloud.sh" || fail "alias recipe did not render"
grep -Fq -- "tailscale up" "$DVM_TEST_GUEST/dvm-cloud.sh" || fail "tailscale recipe missing"
grep -Fq -- "tailscale status" "$DVM_TEST_GUEST/dvm-cloud.sh" || fail "tailscale auth guard missing"
grep -Fq -- "service already installed" "$DVM_TEST_GUEST/dvm-cloud.sh" || fail "cloudflared service guard missing"
[ "$(cat "$DVM_TEST_GUEST/dvm-secret-DVM_TAILSCALE_AUTHKEY")" = "tskey-test" ] || fail "tailscale secret not staged"
[ "$(cat "$DVM_TEST_GUEST/dvm-secret-DVM_CLOUDFLARED_TOKEN")" = "cf-test" ] || fail "cloudflared secret not staged"
! grep -Fq "tskey-test" "$DVM_TEST_LOG" || fail "secret leaked into limactl argv log"
ok "service recipes and secrets work"

cat >"$DVM_CONFIG_DIR/vms/chezmoi.sh" <<'EOF'
DVM_RECIPES=(chezmoi ssh-keys gpg-keys)
DVM_CHEZMOI_REPO="https://example.invalid/dotfiles.git"
EOF
DVM_DRY_RUN=1 run_dvm sync chezmoi >"$TMP/chezmoi.out"
grep -Fq -- '[ ! -d "$home/.local/share/chezmoi" ]' "$TMP/chezmoi.out" || fail "chezmoi init guard missing"
grep -Fq -- 'ssh-keygen' "$TMP/chezmoi.out" || fail "ssh key recipe missing"
grep -Fq -- 'created=1' "$TMP/chezmoi.out" || fail "gpg key creation flag missing"
ok "stateful recipes render idempotent guards"

DVM_DRY_RUN=1 run_dvm sync cloud >"$TMP/cloud.out"
grep -Fq -- 'sudo tee /etc/yum.repos.d/tailscale.repo' "$TMP/cloud.out" || fail "tailscale Fedora repo missing"
grep -Fq -- 'sudo tee /etc/yum.repos.d/cloudflared.repo' "$TMP/cloud.out" || fail "cloudflared Fedora repo missing"
! grep -Fq -- 'apt-get' "$TMP/cloud.out" || fail "cloud recipe contains apt fallback"
ok "service recipes target Fedora/dnf5"

cat >"$DVM_CONFIG_DIR/vms/bad-port.sh" <<'EOF'
DVM_PORTS=(70000:3000)
EOF
if DVM_DRY_RUN=1 run_dvm sync bad-port >/dev/null 2>&1; then
    fail "invalid port accepted"
fi
ok "invalid port is rejected"

cat >"$DVM_CONFIG_DIR/vms/bad-recipe.sh" <<'EOF'
DVM_RECIPES=(does-not-exist)
EOF
if DVM_DRY_RUN=1 run_dvm sync bad-recipe >/dev/null 2>&1; then
    fail "unknown recipe accepted"
fi
ok "unknown recipe is rejected"

cat >"$DVM_CONFIG_DIR/vms/bad-user.sh" <<'EOF'
DVM_AGENT_USER='dvm-agent) NOPASSWD: ALL #'
EOF
if DVM_DRY_RUN=1 run_dvm sync bad-user >/dev/null 2>&1; then
    fail "invalid DVM_AGENT_USER accepted"
fi
ok "invalid DVM_AGENT_USER is rejected"

run_dvm base build
grep -Fxq -- "dvm-base" "$DVM_TEST_LOG" || fail "base build did not touch dvm-base"

: >"$DVM_TEST_LOG"
out="$(DVM_DRY_RUN=1 run_dvm base build)"
case "$out" in *"limactl start argv"*"--- guest script ---"*) ;; *) fail "base dry-run missing output" ;; esac
[ ! -s "$DVM_TEST_LOG" ] || fail "base dry-run called limactl"
ok "base dry-run does not contact Lima"

cat >"$DVM_CONFIG_DIR/vms/from-base.sh" <<'EOF'
DVM_USE_BASE=1
DVM_RECIPES=(bat)
EOF
run_dvm sync from-base
grep -Fq -- "--- clone ---" "$DVM_TEST_LOG" || fail "base clone not used"
grep -Fxq -- "dvm-from-base" "$DVM_TEST_LOG" || fail "base clone missing target"
ok "base build and clone path work"

run_dvm new fresh
[ -f "$DVM_CONFIG_DIR/vms/fresh.sh" ] || fail "new did not write config"
grep -Fq "DVM_RECIPES=(zsh fzf node codex)" "$DVM_CONFIG_DIR/vms/fresh.sh" || fail "new config missing default recipe example"
ok "new writes starter config"

run_dvm stop missing
ok "stop of missing VM is a no-op"

out="$(run_dvm rm ghost --yes)"
case "$out" in *"no Lima instance: ghost"*) ok "rm reports missing VM" ;; *) fail "rm missing output wrong" ;; esac

printf 'dvm-orphan\n' >>"$DVM_TEST_STATE"
run_dvm rm orphan --yes >/dev/null
! grep -Fxq "dvm-orphan" "$DVM_TEST_STATE" || fail "rm did not delete orphan without config"
ok "rm works without a VM config file"

out="$(run_dvm doctor)"
case "$out" in *"limactl"*"ok"*"VISUAL/EDITOR"*"ok"*"git"*"built-in recipes"*) ok "doctor reports basic checks" ;; *) fail "doctor output wrong" ;; esac

printf 'all smoke tests passed\n'
