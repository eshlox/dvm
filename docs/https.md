# HTTPS

DVM does not create HTTPS automatically. HTTPS for local development touches trust
stores, private keys, and browser behavior, so DVM keeps it explicit instead of
changing host or VM trust silently.

## When HTTP Is Fine

For simple local tools, plain HTTP on loopback is usually enough:

```text
http://127.0.0.1:8080
```

Browsers treat `localhost` as a potentially trustworthy origin for many development
features. HTTPS is still useful when you need to test production-like behavior, secure
cookies, external callbacks, mixed-content rules, or a service that refuses HTTP.

## Browser On Host

If Safari, Firefox, or another host browser must trust the site, the certificate must
be trusted on macOS. A VM-only setup cannot make the host browser trust HTTPS.

Recommended host-side flow:

```bash
brew install mkcert nss
mkcert -install
mkdir -p "$HOME/.local/share/dvm/certs"
mkcert \
  -cert-file "$HOME/.local/share/dvm/certs/dvm-local.pem" \
  -key-file "$HOME/.local/share/dvm/certs/dvm-local-key.pem" \
  localhost 127.0.0.1 ::1
```

Then configure your dev server or a small reverse proxy to use those two files.

If the HTTPS server runs inside a VM, copy only the leaf certificate and key into that
VM. Do not copy the mkcert root CA key.

```bash
dvm ssh app 'mkdir -p ~/.local/share/dvm/certs'
limactl copy "$HOME/.local/share/dvm/certs/dvm-local.pem" dvm-app:/tmp/dvm-local.pem
limactl copy "$HOME/.local/share/dvm/certs/dvm-local-key.pem" dvm-app:/tmp/dvm-local-key.pem
dvm ssh app 'mv /tmp/dvm-local*.pem ~/.local/share/dvm/certs/ && chmod 600 ~/.local/share/dvm/certs/*-key.pem'
```

If you generate a certificate inside the VM instead, you still need to copy its public
CA certificate to macOS and trust it there. DVM does not automate that because it is a
host security decision.

## VM-To-VM HTTPS

VM-only HTTPS can be done entirely inside VMs, but it only helps VM clients. It will not
make a host browser trust the service.

The server certificate must include the Lima DNS name:

```text
lima-dvm-ai.internal
```

For example, if an `app` VM calls llama in an `ai` VM, issue a certificate for
`lima-dvm-ai.internal`, configure the llama reverse proxy or server to use it, then
install the public CA certificate in every caller VM:

```bash
dvm ssh app 'sudo cp /tmp/dvm-local-ca.crt /etc/pki/ca-trust/source/anchors/dvm-local-ca.crt && sudo update-ca-trust'
```

Keep the CA private key only in the VM or host that issues certificates. Callers only
need the public CA certificate.

## Why This Is Not A DVM Command

Automatic HTTPS sounds convenient, but a safe implementation needs to decide where the
CA lives, which machines trust it, how keys rotate, and whether macOS trust should be
modified. That is too much hidden state for a small VM helper.

DVM's intended model is:

- use HTTP for simple loopback-only tools
- use host `mkcert` when a host browser needs trusted HTTPS
- use Cloudflare Tunnel when you want a public trusted HTTPS URL
- use a VM-local CA only for VM-to-VM HTTPS
- keep all trust changes visible and reversible

For running `cloudflared` from a VM, see [Cloudflared](cloudflared.md).

References:

- https://web.dev/articles/how-to-use-local-https
- https://letsencrypt.org/docs/certificates-for-localhost/
