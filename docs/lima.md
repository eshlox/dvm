# Lima

DVM delegates VM lifecycle to Lima and avoids rendering its own YAML.

For a new VM, DVM runs roughly:

```bash
limactl start \
  --name dvm-app \
  --cpus 4 \
  --memory 8 \
  --disk 60 \
  --mount-none \
  --port-forward 3000:3000 \
  template:fedora
```

For base reuse, DVM runs:

```bash
limactl clone --cpus 4 --memory 8 --disk 60 --mount-none dvm-base dvm-app
```

`--mount-none` is deliberate: Lima otherwise mounts the host home read-only by
default. Then DVM starts the instance and pipes the generated Bash guest script
through `limactl shell`. Before staging secrets, DVM runs a small guest setup
step to create `DVM_USER` when the template does not already provide it.

## Names

DVM VM `app` maps to Lima instance `dvm-app`. VM names must start with a
lowercase letter and contain only lowercase letters, numbers, and hyphens.

## Template

The default and supported template is `template:fedora`. This follows Lima's
current Fedora template. Built-in recipes assume Fedora with `dnf5`; other
templates are out of scope for DVM.

## Ports

DVM supports two-part port specs:

```bash
DVM_PORTS=(3000:3000 5173:5173)
```

Lima's short `--port-forward host:guest` form is localhost-oriented. DVM does
not expose a bind-IP setting. Use Tailscale or Cloudflare Tunnel for team
access, or configure Lima networking/YAML directly when you need VM IP access.

## Code location

DVM does not mount host project directories. Code lives inside the guest at:

```text
/home/<DVM_USER>/code/<DVM_NAME>
```

For private repos, create VM-local SSH keys first and clone manually inside the
VM after adding the public key to GitHub/GitLab. `DVM_GIT_REPO` is mainly a
first-clone convenience for public HTTPS repos or VMs that already have working
Git credentials.
