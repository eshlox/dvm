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
            if printf '%s\n' "$@" | grep -Fxq '/dev/stdin'; then
                cat >"$guest/secret-${dest##*/}"
            else
                cat >/dev/null || true
            fi
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

cat >"$DVM_CONFIG_DIR/vms/defaults-only.sh" <<'EOF'
DVM_RECIPES=(bat)
EOF

run_dvm() {
    "$ROOT/bin/dvm" "$@"
}

bash -n "$ROOT/bin/dvm"
for f in "$ROOT/share/dvm/prelude.sh" "$ROOT/share/dvm/recipes/"*.sh; do
    bash -n "$f"
done
ok "shell syntax is valid"

if grep -R "sudo npm install -g" "$ROOT/share/dvm/recipes" >/dev/null; then
    fail "built-in recipe uses root-global npm install"
fi
if grep -R "curl .*| *sh" "$ROOT/share/dvm/recipes" >/dev/null; then
    fail "built-in recipe uses curl pipe sh"
fi
ok "recipes avoid root npm and curl-pipe-shell installers"

out="$(run_dvm --help)"
case "$out" in *"sync"*"recipes"*"doctor"*"version"*) ok "help lists current commands" ;; *) fail "help output is wrong" ;; esac

out="$(run_dvm version)"
case "$out" in "dvm "*-dev) ok "version prints development version" ;; *) fail "version output is wrong" ;; esac

out="$(run_dvm recipes)"
case "$out" in *"agent-user"*"codex"*"tailscale"*) ok "recipes lists built-ins" ;; *) fail "recipes output missing built-ins" ;; esac
case "$out" in *"Aliases:"*"cloudflare"*"cloudflared"*"ssh-key"*"ssh-keys"*) ok "recipes lists aliases" ;; *) fail "recipes output missing aliases" ;; esac

out="$(DVM_DRY_RUN=1 run_dvm sync app)"
git_clone_literal="git clone \"\$DVM_GIT_REPO\""
case "$out" in
    *"limactl start argv"*"--mount-none"*"--port-forward"*"3000:3000"*"template:fedora"*) ;;
    *) fail "dry-run missing Lima argv" ;;
esac
case "$out" in
    *"# >>> recipe: zsh"*"# >>> recipe: fzf"*"# >>> recipe: node"*"# >>> recipe: codex"*) ;;
    *) fail "dry-run missing recipes" ;;
esac
case "$out" in *"dvm_pkg git tmux"*"$git_clone_literal"*) ok "dry-run prints guest script" ;; *) fail "dry-run guest script wrong" ;; esac
# shellcheck disable=SC2016 # Match literal guest-side variable expansion.
case "$out" in *'dvm_ensure_user "$DVM_USER"'*) ok "guest script ensures DVM_USER exists" ;; *) fail "guest script does not ensure DVM_USER" ;; esac
grep -Fq -- 'DVM_PROJECT_HOOK=0' <<<"$out" || fail "project hook is not disabled by default"
ok "project hook is disabled by default"
case "$out" in *"sudo dnf5 install -y"*) ok "guest script uses dnf5 only" ;; *) fail "guest script missing dnf5 package helper" ;; esac
case "$out" in *"apt-get"*|*"sudo dnf install"*) fail "guest script contains non-dnf5 package-manager fallback" ;; *) ok "guest script has no apt/dnf fallback" ;; esac
[ ! -s "$DVM_TEST_LOG" ] || fail "dry-run called limactl"
ok "dry-run does not contact Lima"

cat >"$DVM_CONFIG_DIR/vms/priv-hook.sh" <<'EOF'
DVM_PROJECT_HOOK=1
DVM_PROJECT_HOOK_PRIVILEGED=1
EOF
DVM_DRY_RUN=1 run_dvm sync priv-hook >"$TMP/priv-hook.out"
grep -Fq -- 'DVM_PROJECT_HOOK_PRIVILEGED=1' "$TMP/priv-hook.out" || fail "project hook setting not visible in dry-run"
grep -Fq -- 'warning: running project hook with provisioning privileges' "$TMP/priv-hook.out" || fail "privileged hook warning missing"
ok "privileged project hooks require visible opt-in"

cat >"$DVM_CONFIG_DIR/vms/gated-hook.sh" <<'EOF'
DVM_PROJECT_HOOK=1
DVM_PROJECT_HOOK_GIT_CONFIG=1
EOF
DVM_DRY_RUN=1 run_dvm sync gated-hook >"$TMP/gated-hook.out"
grep -Fq -- 'git -C "$DVM_CODE_DIR" config --bool --get dvm.hook' "$TMP/gated-hook.out" || fail "project hook git config gate missing"
grep -Fq -- 'skipping project hook; repo git config dvm.hook is not true' "$TMP/gated-hook.out" || fail "project hook git config skip message missing"
ok "project hooks can require repo-local git config opt-in"

NO_GLOBAL="$TMP/no-global"
mkdir -p "$NO_GLOBAL/vms"
printf 'DVM_RECIPES=(bat)\n' >"$NO_GLOBAL/vms/tiny.sh"
DVM_CONFIG_DIR="$NO_GLOBAL" DVM_DRY_RUN=1 run_dvm sync tiny >/dev/null
ok "sync works without a global config file"

out="$(DVM_DRY_RUN=1 run_dvm sync defaults-only)"
case "$out" in *"dvm_pkg git"*) ok "sync handles default packages without VM packages" ;; *) fail "sync missing default packages without VM packages" ;; esac

run_dvm sync app
grep -Fxq -- "--name" "$DVM_TEST_LOG" || fail "start argv missing --name"
grep -Fxq -- "--mount-none" "$DVM_TEST_LOG" || fail "start argv missing --mount-none"
grep -Fxq -- "dvm-app" "$DVM_TEST_LOG" || fail "start argv missing dvm-app"
grep -Fxq -- "template:fedora" "$DVM_TEST_LOG" || fail "start argv missing template"
grep -Fxq -- "5173:5173" "$DVM_TEST_LOG" || fail "start argv missing second port"
grep -Fq -- "# >>> recipe: codex" "$DVM_TEST_GUEST/dvm-app.sh" || fail "guest script missing codex"
grep -Fq -- "$git_clone_literal" "$DVM_TEST_GUEST/dvm-app.sh" || fail "guest script missing git clone"
ok "sync starts VM and renders package/recipe script"

: >"$DVM_TEST_LOG"
run_dvm ssh app -- echo hi >/dev/null
grep -Fxq -- "sudo" "$DVM_TEST_LOG" || fail "ssh command does not use sudo"
grep -Fxq -- "-u" "$DVM_TEST_LOG" || fail "ssh command missing user flag"
grep -Fxq -- "developer" "$DVM_TEST_LOG" || fail "ssh command does not run as DVM_USER"
grep -Fxq -- "/home/developer/code/app" "$DVM_TEST_LOG" || fail "ssh command missing project workdir"
ok "ssh commands run as DVM_USER in the project directory"

DVM_TAILSCALE_AUTHKEY=tskey-test DVM_CLOUDFLARED_TOKEN=cf-test run_dvm sync cloud
grep -Fq -- "# >>> recipe: cloudflare" "$DVM_TEST_GUEST/dvm-cloud.sh" || fail "alias recipe did not render"
grep -Fq -- "tailscale up" "$DVM_TEST_GUEST/dvm-cloud.sh" || fail "tailscale recipe missing"
grep -Fq -- "tailscale status" "$DVM_TEST_GUEST/dvm-cloud.sh" || fail "tailscale auth guard missing"
grep -Fq -- "service already installed" "$DVM_TEST_GUEST/dvm-cloud.sh" || fail "cloudflared service guard missing"
tailscale_secret="$(find "$DVM_TEST_GUEST" -maxdepth 1 -name 'secret-*-DVM_TAILSCALE_AUTHKEY' -print -quit)"
cloudflared_secret="$(find "$DVM_TEST_GUEST" -maxdepth 1 -name 'secret-*-DVM_CLOUDFLARED_TOKEN' -print -quit)"
if [ -z "$tailscale_secret" ] || [ "$(cat "$tailscale_secret")" != "tskey-test" ]; then
    fail "tailscale secret not staged"
fi
if [ -z "$cloudflared_secret" ] || [ "$(cat "$cloudflared_secret")" != "cf-test" ]; then
    fail "cloudflared secret not staged"
fi
! grep -Fq "tskey-test" "$DVM_TEST_LOG" || fail "secret leaked into limactl argv log"
! grep -Fq "/tmp/dvm-secret" "$DVM_TEST_LOG" || fail "old predictable secret path used"
ok "service recipes and secrets work"

cat >"$DVM_CONFIG_DIR/vms/chezmoi.sh" <<'EOF'
DVM_RECIPES=(chezmoi ssh-keys gpg-keys)
DVM_CHEZMOI_REPO="https://example.invalid/dotfiles.git"
DVM_CHEZMOI_ROLE=dev
EOF
DVM_DRY_RUN=1 run_dvm sync chezmoi >"$TMP/chezmoi.out"
grep -Fq -- "export DVM_CHEZMOI_REPO=https://example.invalid/dotfiles.git" "$TMP/chezmoi.out" || fail "chezmoi repo config not exported"
grep -Fq -- "export DVM_CHEZMOI_ROLE=dev" "$TMP/chezmoi.out" || fail "chezmoi role config not exported"
grep -Fq -- '"role": "%s"' "$TMP/chezmoi.out" || fail "chezmoi role config not rendered"
chezmoi_guard="[ ! -d \"\$home/.local/share/chezmoi\" ]"
grep -Fq -- "$chezmoi_guard" "$TMP/chezmoi.out" || fail "chezmoi init guard missing"
grep -Fq -- 'ssh-keygen' "$TMP/chezmoi.out" || fail "ssh key recipe missing"
grep -Fq -- 'created=1' "$TMP/chezmoi.out" || fail "gpg key creation flag missing"
ok "stateful recipes render idempotent guards"

DVM_DRY_RUN=1 run_dvm sync cloud >"$TMP/cloud.out"
grep -Fq -- 'sudo tee /etc/yum.repos.d/tailscale.repo' "$TMP/cloud.out" || fail "tailscale Fedora repo missing"
grep -Fq -- 'gpgcheck=1' "$TMP/cloud.out" || fail "tailscale package gpgcheck missing"
grep -Fq -- 'sudo tee /etc/yum.repos.d/cloudflared.repo' "$TMP/cloud.out" || fail "cloudflared Fedora repo missing"
# shellcheck disable=SC2016 # Match literal guest-side variable expansion.
! grep -Fq -- '--hostname "${DVM_TAILSCALE_HOSTNAME:-$DVM_NAME}" || true' "$TMP/cloud.out" || fail "tailscale auth failure is swallowed"
grep -Fq -- '--auth-key="file:$(dvm_secret DVM_TAILSCALE_AUTHKEY)"' "$TMP/cloud.out" || fail "tailscale does not use auth key file"
! grep -Fq -- '$(cat /tmp/dvm-secret' "$TMP/cloud.out" || fail "secret value is read from old tmp path"
! grep -Fq -- '/tmp/dvm-secret' "$TMP/cloud.out" || fail "old predictable secret path rendered"
! grep -Fq -- 'apt-get' "$TMP/cloud.out" || fail "cloud recipe contains apt fallback"
ok "service recipes target Fedora/dnf5"

cat >"$DVM_CONFIG_DIR/vms/docker.sh" <<'EOF'
DVM_RECIPES=(docker)
EOF
DVM_DRY_RUN=1 run_dvm sync docker >"$TMP/docker.out"
grep -Fq -- 'dvm_pkg moby-engine docker-compose || dvm_pkg docker docker-compose-plugin' "$TMP/docker.out" || fail "docker recipe bypasses dvm_pkg"
! grep -Fq -- 'sudo dnf5 install -y moby-engine' "$TMP/docker.out" || fail "docker recipe contains raw dnf5 install"
grep -Fq -- 'not adding %s to docker group' "$TMP/docker.out" || fail "docker recipe grants agent access by default"
ok "docker recipe uses dvm_pkg and withholds agent docker access"

cat >"$DVM_CONFIG_DIR/vms/docker-conflict.sh" <<'EOF'
DVM_RECIPES=(agent-user docker)
EOF
if DVM_DRY_RUN=1 run_dvm sync docker-conflict >/dev/null 2>&1; then
    fail "conflicting recipes accepted"
fi
ok "recipe conflicts are rejected"

cat >"$DVM_CONFIG_DIR/vms/dedupe.sh" <<'EOF'
DVM_RECIPES=(cloudflare cloudflared fzf)
EOF
DVM_DRY_RUN=1 run_dvm sync dedupe >"$TMP/dedupe.out"
[ "$(grep -Fc -- '# >>> recipe: cloudflared' "$TMP/dedupe.out")" -eq 1 ] || fail "alias recipe was not deduplicated"
[ "$(grep -Fc -- '# >>> recipe: fzf' "$TMP/dedupe.out")" -eq 1 ] || fail "default recipe was not deduplicated"
ok "recipes are canonicalized and deduplicated"

cat >"$DVM_CONFIG_DIR/vms/secret-hook.sh" <<'EOF'
DVM_SECRETS=(DVM_TEST_TOKEN)
DVM_GIT_REPO="https://example.invalid/app.git"
EOF
DVM_DRY_RUN=1 run_dvm sync secret-hook >"$TMP/secret-hook.out"
grep -Fq -- 'trap dvm_cleanup_staged_secrets EXIT INT TERM' "$TMP/secret-hook.out" || fail "guest secret cleanup trap missing"
grep -Fq -- 'export DVM_SECRET_PATH_DVM_TEST_TOKEN=/run/dvm-secrets/' "$TMP/secret-hook.out" || fail "secret path export missing"
cleanup_line="$(grep -n -- 'sudo rm -f /run/dvm-secrets/' "$TMP/secret-hook.out" | cut -d: -f1 | tail -1)"
# shellcheck disable=SC2016 # Match literal guest-side variable expansion.
clone_line="$(grep -n -- 'git clone "$DVM_GIT_REPO"' "$TMP/secret-hook.out" | cut -d: -f1 | head -1)"
if [ -z "$cleanup_line" ] || [ -z "$clone_line" ] || [ "$cleanup_line" -ge "$clone_line" ]; then
    fail "secrets are not cleaned before project clone"
fi
ok "secrets are randomized and cleaned before project-controlled hooks"

cat >"$DVM_CONFIG_DIR/vms/bad-env.sh" <<'EOF'
DVM_SECRETS=(DVM_TEST_TOKEN)
DVM_ENV=(DVM_TEST_TOKEN)
EOF
if DVM_DRY_RUN=1 run_dvm sync bad-env >/dev/null 2>&1; then
    fail "secret env var accepted in DVM_ENV"
fi
ok "DVM_ENV rejects staged secret names"

cat >"$DVM_CONFIG_DIR/vms/bad-env-danger.sh" <<'EOF'
DVM_ENV=(PATH)
EOF
if DVM_DRY_RUN=1 run_dvm sync bad-env-danger >/dev/null 2>&1; then
    fail "dangerous env var accepted in DVM_ENV"
fi
ok "DVM_ENV rejects dangerous names"

BAD_PERMS="$TMP/bad-perms"
mkdir -p "$BAD_PERMS/vms"
printf 'DVM_DEFAULT_RECIPES=()\n' >"$BAD_PERMS/config.sh"
printf 'DVM_RECIPES=(bat)\n' >"$BAD_PERMS/vms/app.sh"
chmod g+w "$BAD_PERMS/config.sh"
if DVM_CONFIG_DIR="$BAD_PERMS" DVM_DRY_RUN=1 run_dvm sync app >/dev/null 2>&1; then
    fail "unsafe config permissions accepted"
fi
chmod g-w "$BAD_PERMS/config.sh"
printf 'dvm_pkg bat\n' >"$BAD_PERMS/recipes-bad.sh"
mkdir -p "$BAD_PERMS/recipes"
mv "$BAD_PERMS/recipes-bad.sh" "$BAD_PERMS/recipes/bat.sh"
chmod o+w "$BAD_PERMS/recipes/bat.sh"
if DVM_CONFIG_DIR="$BAD_PERMS" DVM_DRY_RUN=1 run_dvm sync app >/dev/null 2>&1; then
    fail "unsafe user recipe permissions accepted"
fi
ok "unsafe config and user recipe permissions are rejected"

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

cat >"$DVM_CONFIG_DIR/vms/agent.sh" <<'EOF'
DVM_RECIPES=(agent-user)
EOF
DVM_DRY_RUN=1 run_dvm sync agent >"$TMP/agent.out"
grep -Fq -- '/usr/local/bin/dvm-agent-shell' "$TMP/agent.out" || fail "agent shell helper missing"
grep -Fq -- 'bwrap missing; refusing to run without guardrail' "$TMP/agent.out" || fail "agent runner does not fail closed"
grep -Fq -- '--dev /dev' "$TMP/agent.out" || fail "agent runner does not use minimal dev"
grep -Fq -- '-K SUB_UID_COUNT=0 -K SUB_GID_COUNT=0' "$TMP/agent.out" || fail "user creation does not disable subordinate ID allocation"
! grep -Fq -- '--dev-bind /dev /dev' "$TMP/agent.out" || fail "agent runner exposes full dev bind"
# shellcheck disable=SC2016 # Match literal generated guest script line.
[ "$(grep -Fc -- 'sudo install -d -o "$DVM_USER" -g "$(dvm_user_group "$DVM_USER")" "$DVM_CODE_DIR"' "$TMP/agent.out")" -eq 1 ] || fail "agent-user repeats code dir creation"
ok "agent-user installs a fail-closed guardrail helper"

run_dvm base build
grep -Fxq -- "dvm-base" "$DVM_TEST_LOG" || fail "base build did not touch dvm-base"

: >"$DVM_TEST_LOG"
out="$(DVM_DRY_RUN=1 run_dvm base build)"
case "$out" in *"limactl start argv"*"--- guest script ---"*) ;; *) fail "base dry-run missing output" ;; esac
[ ! -s "$DVM_TEST_LOG" ] || fail "base dry-run called limactl"
ok "base dry-run does not contact Lima"

mkdir -p "$DVM_CACHE_DIR/base.lock"
if run_dvm base build >/dev/null 2>&1; then
    fail "base build ignored existing lock"
fi
rmdir "$DVM_CACHE_DIR/base.lock"
ok "base operations use the base lock"

cat >"$DVM_CONFIG_DIR/vms/from-base.sh" <<'EOF'
DVM_USE_BASE=1
DVM_RECIPES=(bat)
EOF
run_dvm sync from-base
grep -Fq -- "--- clone ---" "$DVM_TEST_LOG" || fail "base clone not used"
grep -Fxq -- "dvm-from-base" "$DVM_TEST_LOG" || fail "base clone missing target"
ok "base build and clone path work"

cat >"$DVM_CONFIG_DIR/vms/from-base-locked.sh" <<'EOF'
DVM_USE_BASE=1
DVM_RECIPES=(bat)
EOF
mkdir -p "$DVM_CACHE_DIR/base.lock"
if run_dvm sync from-base-locked >/dev/null 2>&1; then
    fail "sync cloned from a locked base"
fi
rmdir "$DVM_CACHE_DIR/base.lock"
ok "sync refuses to clone from a locked base"

run_dvm new fresh
[ -f "$DVM_CONFIG_DIR/vms/fresh.sh" ] || fail "new did not write config"
grep -Fxq "DVM_RECIPES=(zsh fzf)" "$DVM_CONFIG_DIR/vms/fresh.sh" || fail "new config default recipes are not conservative"
grep -Fq "# DVM_RECIPES=(zsh fzf node codex)" "$DVM_CONFIG_DIR/vms/fresh.sh" || fail "new config missing commented AI recipe example"
grep -Fq "# DVM_PROJECT_HOOK=0" "$DVM_CONFIG_DIR/vms/fresh.sh" || fail "new config does not disable project hooks by default"
ok "new writes starter config"

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
[ -f "$DVM_CONFIG_DIR/vms/fresh.sh" ] || fail "rm removed config without --config"
run_dvm rm fresh --yes --config >/dev/null
[ ! -f "$DVM_CONFIG_DIR/vms/fresh.sh" ] || fail "rm --config did not remove config"
ok "rm warns about and optionally removes stale config"

out="$(run_dvm doctor)"
case "$out" in *"limactl"*"ok"*"VISUAL/EDITOR"*"ok"*"git"*"built-in recipes"*) ok "doctor reports basic checks" ;; *) fail "doctor output wrong" ;; esac

out="$(run_dvm doctor --probe app)"
case "$out" in *"probe app"*"ok"*) ok "doctor probe checks VM reachability" ;; *) fail "doctor probe output wrong" ;; esac

if DVM_LIMACTL=/no/such/limactl run_dvm ls >/dev/null 2>&1; then
    fail "missing limactl accepted"
fi
ok "commands fail clearly when limactl is missing"

printf 'all smoke tests passed\n'
