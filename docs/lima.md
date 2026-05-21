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

Then DVM starts the instance, ensures `DVM_USER` exists, creates
`/home/<DVM_USER>/code/<vm>`, and pipes trusted setup scripts through
`limactl shell`.

## Names

DVM VM `app` maps to Lima instance `dvm-app`. VM names must start with a
lowercase letter and contain only lowercase letters, numbers, and hyphens.

## Template

DVM always creates VMs from Lima's Fedora template:

```text
template:fedora
```

Setup examples assume Fedora with `dnf5`. Other guest distributions are outside
the supported path for this project.

## Host mounts

DVM passes `--mount-none` when it creates instances. This is deliberate: Lima
otherwise commonly mounts host paths, which weakens the host protection goal.

If you need host mounts or advanced Lima YAML, manage that VM directly with
Lima. DVM does not expose a generic extra-args escape hatch.

## Ports

DVM supports two-part port specs:

```bash
DVM_PORTS=(3000:3000 5173:5173)
```

Lima's short `--port-forward host:guest` form is localhost-oriented. Use
Tailscale, Cloudflare Tunnel, or direct Lima networking when you need broader
network access.

## Code location

DVM does not mount host project directories. Code lives inside the guest at:

```text
/home/<DVM_USER>/code/<DVM_NAME>
```
