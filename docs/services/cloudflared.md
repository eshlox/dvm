# Cloudflared

Use a separate VM when you want Cloudflare Tunnel without installing `cloudflared` on
macOS.

Good uses:

- expose a macOS dev server through your existing Cloudflare domain
- expose a service in another DVM VM
- keep Cloudflare credentials out of project VMs

## Static Domain

Create or reuse a Cloudflare Tunnel in the Cloudflare Zero Trust dashboard. Add a public
hostname and set its service URL to one of these:

```text
http://host.lima.internal:3000
http://lima-dvm-app.internal:3000
http://lima-dvm-ai.internal:8080
```

Use `host.lima.internal` for a service running on macOS. Use `lima-dvm-<name>.internal`
for another DVM VM.

Create a small cloudflared VM:

```bash
dvm init cloudflared
```

`~/.config/dvm/vms/cloudflared.sh`:

```bash
DVM_CPUS="1"
DVM_MEMORY="1GiB"
DVM_DISK="10GiB"
DVM_SETUP_SCRIPTS="cloudflared.sh"
DVM_CLOUDFLARED_TOKEN="${CLOUDFLARED_TOKEN:-}"
```

Run setup once with the token from the Cloudflare dashboard:

```bash
read -rsp 'Cloudflare token: ' CLOUDFLARED_TOKEN
echo
export CLOUDFLARED_TOKEN
dvm create cloudflared
unset CLOUDFLARED_TOKEN
```

The token is written inside the VM as `/etc/cloudflared/dvm.env`. It does not need to
stay in the DVM config file.

Check logs:

```bash
dvm ssh cloudflared sudo systemctl status dvm-cloudflared.service
dvm ssh cloudflared sudo journalctl -u dvm-cloudflared.service -f
```

Rotate the token:

```bash
read -rsp 'Cloudflare token: ' CLOUDFLARED_TOKEN
echo
export CLOUDFLARED_TOKEN
dvm setup cloudflared
unset CLOUDFLARED_TOKEN
```

## Quick Tunnel

For a temporary public URL without a Cloudflare domain:

```bash
dvm create cloudflared
dvm ssh cloudflared cloudflared tunnel --url http://host.lima.internal:3000
```

Quick tunnels are useful for testing. Use a named/static tunnel for daily work.

## Security

A Cloudflare Tunnel makes the origin reachable through your public hostname. Protect the
site with Cloudflare Access or application auth if it is not meant to be public.

Keep the token only in the cloudflared VM. If the VM is compromised, revoke or rotate
the token in Cloudflare.

References:

- https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/
- https://developers.cloudflare.com/tunnel/advanced/local-management/as-a-service/linux/
- https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/
- https://lima-vm.io/docs/config/network/user/
