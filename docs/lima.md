# Lima

DVM delegates VM lifecycle to Lima and does not render its own YAML. For a new
VM it runs roughly:

```bash
limactl start \
  --name dvm-app \
  --cpus 4 --memory 8 --disk 60 \
  --mount-none \
  --port-forward 3000:3000 \
  template:fedora
```

Then it ensures `DVM_USER` exists, creates `/home/<DVM_USER>/code/<vm>`,
provisions subordinate uid/gid ranges, and pipes setup scripts through
`limactl shell`.

Lima also creates its own default login account, commonly `<host-user>.guest`.
DVM uses that account for shell access, bootstrap, and sudo-based setup. Project
shells, commands, and copies run as `DVM_USER`.

## Names

VM `app` maps to Lima instance `dvm-app`. Names must start with a lowercase
letter and contain only lowercase letters, numbers, and hyphens.

## Template

DVM always uses Lima's Fedora template (`template:fedora`). Setup examples
assume Fedora with `dnf5`. Other guest distributions are outside the supported
path.

## Host mounts

DVM always passes `--mount-none`. Lima otherwise commonly mounts host paths,
which weakens host protection. If you need host mounts or advanced Lima YAML,
manage that VM directly with Lima; DVM has no extra-args escape hatch.

## Ports

`DVM_PORTS` takes two-part `host:guest` specs. Lima's short form is
localhost-oriented. Use Tailscale, Cloudflare Tunnel, or direct Lima networking
for broader access.
