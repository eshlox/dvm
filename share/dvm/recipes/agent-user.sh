dvm_pkg acl bubblewrap shadow-utils sudo

dvm_ensure_user "$DVM_AGENT_USER"

sudo setfacl -m "u:$DVM_AGENT_USER:rwx" "$DVM_CODE_DIR" || true
sudo setfacl -d -m "u:$DVM_AGENT_USER:rwx" "$DVM_CODE_DIR" || true

sudo install -d -m 0750 /etc/sudoers.d
sudoers_tmp="$(mktemp)"
printf '%s ALL=(%s) NOPASSWD: ALL\n' "$DVM_USER" "$DVM_AGENT_USER" >"$sudoers_tmp"
if ! sudo visudo -cf "$sudoers_tmp" >/dev/null; then
    rm -f "$sudoers_tmp"
    dvm_recipe_die "$DVM_RECIPE" "generated sudoers rule failed validation"
fi
sudo install -m 0440 -o root -g root "$sudoers_tmp" /etc/sudoers.d/dvm-agent
rm -f "$sudoers_tmp"

agent_home="$(dvm_agent_home)"
sudo tee /usr/local/bin/dvm-agent >/dev/null <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
if ! command -v bwrap >/dev/null 2>&1; then
    if [ "\${DVM_AGENT_ALLOW_UNSANDBOXED:-0}" = "1" ]; then
        printf 'dvm-agent: warning: bwrap missing; DVM_AGENT_ALLOW_UNSANDBOXED=1 requested plain sudo guardrail\\n' >&2
        cd "$DVM_CODE_DIR"
        exec sudo -u "$DVM_AGENT_USER" -H bash -lc 'exec "\$@"' bash "\$@"
    fi
    printf 'dvm-agent: bwrap missing; refusing to run without guardrail (set DVM_AGENT_ALLOW_UNSANDBOXED=1 to override)\\n' >&2
    exit 1
fi
network_args=()
if [ "\${DVM_AGENT_NETWORK:-1}" = "1" ]; then
    network_args=(--share-net)
fi
exec sudo -u "$DVM_AGENT_USER" -H bwrap \\
    --unshare-all "\${network_args[@]}" --die-with-parent \\
    --ro-bind / / \\
    --dev /dev \\
    --proc /proc \\
    --tmpfs /tmp \\
    --tmpfs /home \\
    --dir "/home/$DVM_USER" \\
    --dir "/home/$DVM_USER/code" \\
    --dir "$agent_home" \\
    --bind "$DVM_CODE_DIR" "$DVM_CODE_DIR" \\
    --bind "$agent_home" "$agent_home" \\
    --chdir "$DVM_CODE_DIR" \\
    --setenv HOME "$agent_home" \\
    --setenv USER "$DVM_AGENT_USER" \\
    bash -lc 'exec "\$@"' bash "\$@"
EOF
sudo chmod 0755 /usr/local/bin/dvm-agent

sudo tee /usr/local/bin/dvm-agent-shell >/dev/null <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
exec /usr/local/bin/dvm-agent bash -l
EOF
sudo chmod 0755 /usr/local/bin/dvm-agent-shell

printf 'dvm recipe agent-user: guardrail runner installed; use dvm-agent <cmd> or dvm-agent-shell inside the VM\n'
