---
title: "Lima behavior"
description: "How DVM drives Lima, instance naming, and the limits you should know about."
---

DVM delegates VM lifecycle to Lima and does not render its own YAML. For a new
VM it runs roughly:

```bash
limactl --log-level warn start \
  --yes \
  --name dvm-app \
  --cpus 4 --memory 8 --disk 60 \
  --mount-none \
  --port-forward 3000:3000 \
  template:fedora
```

`--yes` proceeds with the generated configuration non-interactively, so the
first `dvm sync` does not stop to ask whether to proceed, edit, or exit.

DVM captures this output to a per-VM log and shows a spinner with a `✓`/`✗` per
step instead. On the first run the image download and boot happen behind the
spinner (a minute or more) rather than streaming to the terminal; on failure DVM
prints the log path and its last lines. Set `DVM_VERBOSE=1` to stream the full
output live. See [logs and environment](/docs/reference/config/#logs).

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

Lima already forwards guest ports to `localhost` on the host automatically, so
leaving `DVM_PORTS` empty still reaches a dev server on its bound port.
`DVM_PORTS` adds explicit two-part `host:guest` specs on top, mainly to remap a
guest port to a different host port. Lima's short form is localhost-oriented; use
Tailscale, Cloudflare Tunnel, or direct Lima networking for broader access.
