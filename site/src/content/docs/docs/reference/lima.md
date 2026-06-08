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

Without a base image, DVM uses Lima's Fedora template (`template:fedora`) and
provisions it with your setup scripts on every sync. With a
[base image](/docs/reference/base/), DVM instead points Lima at a generated
one-line template referencing the built qcow2, so the VM boots with your tooling
already baked in. Either way the guest is Fedora; setup examples assume Fedora
with `dnf5`, and other guest distributions are outside the supported path.

## VM type

`DVM_VM_TYPE` is passed through as `limactl start --vm-type`. It is empty by
default (Lima picks QEMU). On Apple Silicon, `DVM_VM_TYPE=vz` selects Apple's
Virtualization framework: lighter overhead and friendlier host memory reclaim
when several VMs run at once.

## CPUs

`--cpus` sets how many vCPUs Lima presents to the guest. These are time-shared
host threads, not pinned cores: the host scheduler runs them on physical cores
only when the guest has work, so an idle VM's vCPUs consume effectively no host
CPU and several idle VMs never block a busy one from using every core. The count
is a per-VM ceiling on parallelism, and oversubscribing across VMs is safe; the
only cost is contention (guest "steal time") when multiple VMs are busy at once.

DVM auto-detects the default (host cores minus a small reserve kept free for the
host, floored at 2) and bakes the value into the instance at create time, so it
applies to VMs created afterward and existing VMs keep what they were made with.
Memory, by contrast, is reserved up front. See
[CPUs vs memory](/docs/reference/config/#cpus-vs-memory).

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
