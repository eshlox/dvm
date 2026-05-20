dvm_pkg acl bubblewrap shadow-utils sudo

if ! id "$DVM_AGENT_USER" >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash "$DVM_AGENT_USER"
fi

sudo setfacl -m "u:$DVM_AGENT_USER:rwx" "$DVM_CODE_DIR" || true
sudo setfacl -d -m "u:$DVM_AGENT_USER:rwx" "$DVM_CODE_DIR" || true

sudo install -d -m 0750 /etc/sudoers.d
printf '%s ALL=(%s) NOPASSWD: ALL\n' "$DVM_USER" "$DVM_AGENT_USER" \
    | sudo tee /etc/sudoers.d/dvm-agent >/dev/null
sudo chmod 0440 /etc/sudoers.d/dvm-agent

agent_home="$(dvm_agent_home)"
sudo tee /usr/local/bin/dvm-agent >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
if command -v bwrap >/dev/null 2>&1; then
    exec sudo -u "$DVM_AGENT_USER" -H bwrap \\
        --unshare-all --share-net --die-with-parent \\
        --ro-bind / / \\
        --dev-bind /dev /dev \\
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
fi
printf 'dvm-agent: warning: bwrap missing; running without sandbox\\n' >&2
cd "$DVM_CODE_DIR"
exec sudo -u "$DVM_AGENT_USER" -H bash -lc 'exec "\$@"' bash "\$@"
EOF
sudo chmod 0755 /usr/local/bin/dvm-agent

sudo tee /usr/local/bin/dvm-agent-shell >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /usr/local/bin/dvm-agent bash -l
EOF
sudo chmod 0755 /usr/local/bin/dvm-agent-shell

printf 'dvm recipe agent-user: restricted runner installed; use dvm-agent <cmd> or dvm-agent-shell inside the VM\n'
