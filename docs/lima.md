# Lima

DVM drives Lima with `limactl` flags. No YAML rendering, no `envsubst`.

## How `dvm sync` calls Lima

For a fresh VM:

```bash
limactl start \
  --name dvm-app \
  --cpus 4 --memory 8 --disk 60 \
  --port-forward 127.0.0.1:3000:3000 \
  --port-forward 127.0.0.1:5173:5173 \
  template:fedora
```

For an existing VM, only `limactl start dvm-app` is run.

With `DVM_USE_BASE=1` and the base VM already built:

```bash
limactl clone \
  --cpus 4 --memory 8 --disk 60 \
  --port-forward 127.0.0.1:3000:3000 \
  dvm-base dvm-app
```

Requires Lima 2.0+ (for `--port-forward` on `start` and the `clone`
subcommand). Tested against Lima 2.1.1.

## Templates

`DVM_TEMPLATE` defaults to `template:fedora`, which tracks Lima's current
Fedora release. Pin a versioned template (e.g. `template:fedora-44`) if
reproducibility matters more than tracking upstream. Any template Lima
ships works.

## No host mounts

Project code lives **inside** the VM at `/home/<DVM_USER>/code/<vm>`. Your
Ansible role is responsible for cloning the project repository there. DVM
intentionally does not pass `--mount` so a compromised guest cannot reach
back into the host checkout. See
[security-standards.md](security-standards.md).

## Inventory

Every Lima instance writes `~/.lima/dvm-<vm>/ansible-inventory.yaml`. DVM
uses that file directly — there is no DVM-managed SSH config or inventory.
`dvm doctor` checks for this file's existence for each VM.

## VM-to-VM names

Lima exposes each instance at `lima-<name>.internal` from other Lima
instances. From an app VM to a service VM:

```bash
curl http://lima-dvm-llama.internal:8080
```

From a VM to the host:

```bash
curl http://host.lima.internal:3000
```

## Updating

- Editing `DVM_PORTS` and re-syncing only takes effect when the instance is
  recreated. Lima does not edit running port forwards. Run
  `dvm rm <vm> --yes && dvm sync <vm>` to apply.
- The same is true for CPUs, memory, disk, and template — those land on
  fresh instances only. The base-VM clone path makes this cheaper.
