#!/usr/bin/env bash
# End-to-end smoke test for dvm with fake limactl and ansible-playbook.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LIMACTL_LOG="$TMP/limactl.log"
ANSIBLE_LOG="$TMP/ansible.log"
HOME_DIR="$TMP/home"
mkdir -p "$HOME_DIR/.lima"

# --- fake limactl: logs argv, simulates list/inventory ----------------------
mkdir -p "$TMP/bin"
cat > "$TMP/bin/limactl" <<EOF
#!/usr/bin/env bash
{ printf '%q ' "\$@"; printf '\n'; } >> "$LIMACTL_LOG"
case "\$1" in
    --version) echo "limactl version 2.1.1 (fake)" ;;
    list)
        if [ "\${DVM_FAKE_HAS_VM:-0}" = "1" ]; then
            case "\$2" in
                -q) printf 'dvm-app\n' ;;
                --format) printf 'dvm-app\tRunning\t4\t8GiB\n' ;;
            esac
        fi
        ;;
    start)
        # First non-flag positional after 'start' is the instance name or template.
        # If we see --name, create the inventory file Lima would generate.
        shift
        name=""
        while [ \$# -gt 0 ]; do
            case "\$1" in
                --name) name="\$2"; shift 2 ;;
                --cpus|--memory|--disk|--port-forward) shift 2 ;;
                template:*) [ -z "\$name" ] && name="\$2"; shift ;;
                *) shift ;;
            esac
        done
        if [ -n "\$name" ]; then
            mkdir -p "$HOME_DIR/.lima/\$name"
            printf 'all:\n  hosts:\n    %s:\n' "\$name" > "$HOME_DIR/.lima/\$name/ansible-inventory.yaml"
        fi
        ;;
    clone)
        # Last positional is the new name.
        shift
        prev=""
        for a in "\$@"; do prev="\$a"; done
        mkdir -p "$HOME_DIR/.lima/\$prev"
        printf 'all:\n  hosts:\n    %s:\n' "\$prev" > "$HOME_DIR/.lima/\$prev/ansible-inventory.yaml"
        ;;
esac
exit 0
EOF
chmod +x "$TMP/bin/limactl"

# --- fake ansible-playbook: logs argv (one arg per line, no escaping) ------
cat > "$TMP/bin/ansible-playbook" <<EOF
#!/usr/bin/env bash
printf -- '--- ansible-playbook ---\n' >> "$ANSIBLE_LOG"
for a in "\$@"; do printf '%s\n' "\$a" >> "$ANSIBLE_LOG"; done
case "\$1" in
    --version) echo "ansible-playbook 2.16.0 (fake)" ;;
esac
exit 0
EOF
chmod +x "$TMP/bin/ansible-playbook"

# --- fake Ansible repo ------------------------------------------------------
mkdir -p "$TMP/ansible"
cat > "$TMP/ansible/site.yml" <<'EOF'
- hosts: all
  tasks: []
EOF

# --- dvm config ------------------------------------------------------------
mkdir -p "$TMP/cfg/vms"
cat > "$TMP/cfg/config.sh" <<EOF
DVM_TEMPLATE="template:fedora"
DVM_CPUS=2
DVM_MEMORY=4
DVM_DISK=30
DVM_ANSIBLE_REPO="$TMP/ansible"
DVM_ANSIBLE_PLAYBOOK="site.yml"
EOF

cat > "$TMP/cfg/vms/app.sh" <<'EOF'
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
DVM_ANSIBLE_TAGS=(base agent-user codex node chezmoi)
DVM_ANSIBLE_EXTRA_VARS=(
  "dvm_profile=app"
  "chezmoi_repo=git@github.com:me/dotfiles.git"
)
EOF

cat > "$TMP/cfg/vms/cloud.sh" <<'EOF'
DVM_CPUS=2
DVM_MEMORY=2
DVM_DISK=20
DVM_ANSIBLE_TAGS=(base cloudflared)
EOF

run_dvm() {
    PATH="$TMP/bin:$PATH" \
    HOME="$HOME_DIR" \
    DVM_CONFIG_DIR="$TMP/cfg" \
    DVM_SHARE_DIR="$ROOT/share/dvm" \
    DVM_CACHE_DIR="$TMP/cache" \
    "$ROOT/bin/dvm" "$@"
}

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok()   { printf 'ok: %s\n' "$*"; }

# --- help -----------------------------------------------------------------
out="$(run_dvm help)"
case "$out" in *"sync"*"ansible"*"doctor"*) ok "help lists commands" ;; *) fail "help" ;; esac

# --- bash syntax of dvm itself --------------------------------------------
bash -n "$ROOT/bin/dvm"
ok "bin/dvm parses with bash -n"

# --- sync app: limactl start argv ------------------------------------------
: > "$LIMACTL_LOG"; : > "$ANSIBLE_LOG"
run_dvm sync app >/dev/null
grep -q -- "start --name dvm-app"            "$LIMACTL_LOG" || fail "no start --name"
grep -q -- "--cpus 4"                        "$LIMACTL_LOG" || fail "missing --cpus 4"
grep -q -- "--memory 8"                      "$LIMACTL_LOG" || fail "missing --memory 8"
grep -q -- "--disk 60"                       "$LIMACTL_LOG" || fail "missing --disk 60"
grep -q -- "--port-forward 127.0.0.1:3000:3000" "$LIMACTL_LOG" || fail "missing port forward 3000"
grep -q -- "--port-forward 127.0.0.1:5173:5173" "$LIMACTL_LOG" || fail "missing port forward 5173"
grep -q -- "template:fedora"                 "$LIMACTL_LOG" || fail "missing template:fedora"
ok "sync app issues limactl start with flags and template"

# --- vars file content -----------------------------------------------------
vars="$TMP/cache/app.vars.yml"
[ -f "$vars" ] || fail "no vars file"
grep -q "^dvm_name: app$"           "$vars" || fail "vars missing dvm_name"
grep -q "^dvm_lima_name: dvm-app$"  "$vars" || fail "vars missing dvm_lima_name"
grep -q "^dvm_user: developer$"     "$vars" || fail "vars missing dvm_user"
grep -q "^dvm_code_dir: /home/developer/code/app$" "$vars" || fail "vars missing code_dir"
grep -q "host: 3000"                "$vars" || fail "vars missing port host"
grep -q "guest: 3000"               "$vars" || fail "vars missing port guest"
ok "vars file contains expected DVM-managed keys"

# --- ansible-playbook argv -------------------------------------------------
# The fake logs one arg per line, so each grep -Fxq matches an exact arg.
grep -Fxq -- "-i" "$ANSIBLE_LOG" || fail "ansible argv missing -i"
grep -Fxq -- "$HOME_DIR/.lima/dvm-app/ansible-inventory.yaml" "$ANSIBLE_LOG" \
    || fail "ansible argv missing inventory path"
grep -Fxq -- "$TMP/ansible/site.yml" "$ANSIBLE_LOG" || fail "ansible argv missing playbook"
grep -Fxq -- "@$TMP/cache/app.vars.yml" "$ANSIBLE_LOG" || fail "ansible argv missing vars file"
grep -Fxq -- "--tags" "$ANSIBLE_LOG" || fail "ansible argv missing --tags"
grep -Fxq -- "base,agent-user,codex,node,chezmoi" "$ANSIBLE_LOG" || fail "ansible argv tags wrong"
grep -Fxq -- "dvm_profile=app" "$ANSIBLE_LOG" || fail "ansible argv missing dvm_profile=app"
grep -Fxq -- "chezmoi_repo=git@github.com:me/dotfiles.git" "$ANSIBLE_LOG" || fail "ansible argv missing chezmoi_repo"
ok "ansible-playbook argv has inventory, playbook, vars file, tags, extra-vars"

# --- no secret-looking values in vars file or ansible argv ----------------
for needle in token password secret TOKEN PASSWORD SECRET; do
    if grep -q "$needle" "$vars"; then fail "vars file contains '$needle'"; fi
done
ok "vars file contains no secret-looking values"

# --- dry-run prints argv and does NOT call limactl/ansible ----------------
: > "$LIMACTL_LOG"; : > "$ANSIBLE_LOG"
out="$(DVM_DRY_RUN=1 run_dvm sync app)"
case "$out" in
    *"limactl start argv"*"--cpus"*"template:fedora"*"ansible-playbook argv"*) ;;
    *) fail "dry-run output missing argv blocks" ;;
esac
[ ! -s "$LIMACTL_LOG" ] || fail "dry-run called limactl"
[ ! -s "$ANSIBLE_LOG" ] || fail "dry-run called ansible-playbook"
ok "dry-run prints argv without calling limactl or ansible"

# --- reject secret-looking extra-var --------------------------------------
cat > "$TMP/cfg/vms/bad.sh" <<'EOF'
DVM_ANSIBLE_TAGS=(base)
DVM_ANSIBLE_EXTRA_VARS=("github_token=ghp_xxx")
EOF
if run_dvm sync bad >/dev/null 2>&1; then
    fail "should reject secret-looking extra-var"
fi
ok "rejects secret-looking DVM_ANSIBLE_EXTRA_VARS entry"

# --- reject when DVM_ANSIBLE_REPO unset -----------------------------------
cat > "$TMP/cfg/config.sh.empty" <<EOF
# no DVM_ANSIBLE_REPO
DVM_TEMPLATE="template:fedora"
EOF
if PATH="$TMP/bin:$PATH" HOME="$HOME_DIR" \
       DVM_CONFIG_DIR="$TMP/cfg-empty" DVM_SHARE_DIR="$ROOT/share/dvm" \
       DVM_CACHE_DIR="$TMP/cache" \
       "$ROOT/bin/dvm" sync app >/dev/null 2>&1; then
    fail "should require DVM_ANSIBLE_REPO and a config"
fi
ok "rejects sync when ansible repo is unconfigured"

# --- ls / stop / rm --------------------------------------------------------
: > "$LIMACTL_LOG"
DVM_FAKE_HAS_VM=1 run_dvm ls | grep -q "^app " || fail "ls missing app"
DVM_FAKE_HAS_VM=1 run_dvm ls app | grep -q "^app " || fail "ls <vm> filter"
ok "ls and ls <vm> work"

: > "$LIMACTL_LOG"
run_dvm stop app >/dev/null
grep -q "stop dvm-app" "$LIMACTL_LOG" || fail "stop didn't call limactl"
ok "stop forwards to limactl"

: > "$LIMACTL_LOG"
DVM_FAKE_HAS_VM=1 run_dvm rm app --yes >/dev/null
grep -q "delete --force dvm-app" "$LIMACTL_LOG" || fail "rm didn't delete"
[ ! -f "$TMP/cache/app.vars.yml" ] || fail "rm should delete cached vars file"
ok "rm --yes deletes instance and cached vars file"

# --- sync --all iterates ---------------------------------------------------
rm -f "$TMP/cfg/vms/bad.sh"  # leftover from negative test above
: > "$LIMACTL_LOG"; : > "$ANSIBLE_LOG"
run_dvm sync --all >/dev/null
[ "$(grep -c "start --name " "$LIMACTL_LOG")" -ge 2 ] || fail "sync --all didn't iterate"
[ "$(grep -c "site.yml" "$ANSIBLE_LOG")" -ge 2 ] || fail "sync --all didn't run ansible twice"
ok "sync --all iterates"

# --- cp parsing ------------------------------------------------------------
: > "$LIMACTL_LOG"
run_dvm cp ./local app:/guest >/dev/null
grep -qE "copy ./local dvm-app:/guest" "$LIMACTL_LOG" || fail "cp host->guest rewrite"
ok "cp rewrites vm:path to dvm-vm:path"

if run_dvm cp ./a ./b >/dev/null 2>&1; then fail "cp should reject two local paths"; fi
ok "cp rejects two local paths"

if run_dvm cp app:/a other:/b >/dev/null 2>&1; then fail "cp should reject cross-VM"; fi
ok "cp rejects cross-VM"

# --- invalid VM name -------------------------------------------------------
if run_dvm sync "Bad-Name" >/dev/null 2>&1; then fail "should reject invalid VM name"; fi
ok "rejects invalid VM name"

# --- base build + clone path ----------------------------------------------
cat > "$TMP/cfg/config.sh" <<EOF
DVM_TEMPLATE="template:fedora"
DVM_CPUS=2 DVM_MEMORY=4 DVM_DISK=30
DVM_ANSIBLE_REPO="$TMP/ansible"
DVM_ANSIBLE_PLAYBOOK="site.yml"
DVM_USE_BASE=1
DVM_BASE_NAME=dvm-base
DVM_BASE_TAGS=(base)
EOF
: > "$LIMACTL_LOG"; : > "$ANSIBLE_LOG"
run_dvm base build >/dev/null
grep -q "start --name dvm-dvm-base" "$LIMACTL_LOG" || fail "base build didn't start base VM"
grep -Fxq -- "--tags" "$ANSIBLE_LOG" || fail "base build missing --tags flag"
grep -Fxq -- "base"   "$ANSIBLE_LOG" || fail "base build missing base tag value"
ok "base build starts base VM and runs ansible with base tags"

# Now sync the app VM with DVM_USE_BASE=1 — should clone, not start template.
rm -rf "$HOME_DIR/.lima/dvm-app"
: > "$LIMACTL_LOG"; : > "$ANSIBLE_LOG"
# Mark base as existing in fake limactl list.
cat > "$TMP/bin/limactl" <<EOF
#!/usr/bin/env bash
{ printf '%q ' "\$@"; printf '\n'; } >> "$LIMACTL_LOG"
case "\$1" in
    list)
        case "\$2" in
            -q) printf 'dvm-dvm-base\n' ;;
            --format) printf 'dvm-dvm-base\tStopped\t2\t4GiB\n' ;;
        esac
        ;;
    clone)
        shift
        prev=""
        for a in "\$@"; do prev="\$a"; done
        mkdir -p "$HOME_DIR/.lima/\$prev"
        printf 'all:\n  hosts:\n    %s:\n' "\$prev" > "$HOME_DIR/.lima/\$prev/ansible-inventory.yaml"
        ;;
esac
exit 0
EOF
chmod +x "$TMP/bin/limactl"

run_dvm sync app >/dev/null
grep -q -- "clone" "$LIMACTL_LOG" || fail "sync with DVM_USE_BASE=1 didn't clone"
grep -q "dvm-dvm-base dvm-app" "$LIMACTL_LOG" || fail "clone argv missing source/dest"
ok "DVM_USE_BASE=1 clones from base instead of fresh start"

# --- doctor ---------------------------------------------------------------
# Restore working limactl (so doctor doesn't fail on missing VMs).
cat > "$TMP/bin/limactl" <<EOF
#!/usr/bin/env bash
case "\$1" in
    --version) echo "limactl version 2.1.1 (fake)" ;;
    list) ;;
esac
exit 0
EOF
chmod +x "$TMP/bin/limactl"
out="$(run_dvm doctor 2>&1)" || true
case "$out" in
    *"limactl"*"ok"*"ansible-playbook"*"ok"*) ok "doctor reports limactl and ansible-playbook ok" ;;
    *) fail "doctor output unexpected: $out" ;;
esac
case "$out" in *"$TMP/ansible"*) ok "doctor reports DVM_ANSIBLE_REPO" ;; *) fail "doctor missing repo" ;; esac

# --- dvm ansible <vm> -- forwards args ------------------------------------
mkdir -p "$HOME_DIR/.lima/dvm-app"
printf 'all:\n  hosts:\n    dvm-app:\n' > "$HOME_DIR/.lima/dvm-app/ansible-inventory.yaml"
: > "$ANSIBLE_LOG"
run_dvm ansible app -- --check --diff
grep -q -- "--check" "$ANSIBLE_LOG" || fail "ansible passthrough missing --check"
grep -q -- "--diff" "$ANSIBLE_LOG" || fail "ansible passthrough missing --diff"
ok "dvm ansible forwards extra args"

# --- absolute-target symlink to bin/dvm works ------------------------------
ln -sfn "$ROOT/bin/dvm" "$TMP/bin/dvm-link"
PATH="$TMP/bin:$PATH" HOME="$HOME_DIR" \
    DVM_CONFIG_DIR="$TMP/cfg" DVM_SHARE_DIR="$ROOT/share/dvm" \
    DVM_CACHE_DIR="$TMP/cache" \
    "$TMP/bin/dvm-link" help >/dev/null 2>&1 \
    || fail "dvm broken when launched through absolute-target symlink"
ok "works through absolute-target symlink"

# --- help / ls do not invoke envsubst or flock ----------------------------
trace="$(bash -x "$ROOT/bin/dvm" help 2>&1 >/dev/null || true)"
case "$trace" in *envsubst*|*flock*) fail "help triggered envsubst/flock" ;; esac
ok "help does not invoke envsubst or flock"

printf '\nall tests passed\n'
