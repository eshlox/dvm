sudo tee /etc/yum.repos.d/cloudflared.repo >/dev/null <<'EOF'
[cloudflared]
name=cloudflared
baseurl=https://pkg.cloudflare.com/cloudflared/rpm
enabled=1
gpgcheck=1
gpgkey=https://pkg.cloudflare.com/cloudflare-main.gpg
EOF
dvm_pkg cloudflared

if systemctl list-unit-files cloudflared.service --no-legend 2>/dev/null | grep -q '^cloudflared.service'; then
    printf 'dvm recipe cloudflared: service already installed\n'
elif [ -r /tmp/dvm-secret-DVM_CLOUDFLARED_TOKEN ]; then
    sudo cloudflared service install "$(cat /tmp/dvm-secret-DVM_CLOUDFLARED_TOKEN)"
else
    printf 'dvm recipe cloudflared: no tunnel token staged; skipping service install\n'
fi
