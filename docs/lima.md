# Lima

DVM renders one Lima YAML per VM and lets Lima do the rest.

## Template

`share/dvm/lima.yaml.in` is a tiny `envsubst` template with placeholders
for `${DVM_CPUS}`, `${DVM_MEMORY}`, `${DVM_DISK}`, `${DVM_USER}`,
`${DVM_NAME}`, `${DVM_CODE_DIR_GUEST}`, and `${DVM_PORT_FORWARDS}`.
`bin/dvm` substitutes those vars at sync time and writes the result to
`~/.cache/dvm/<vm>.yaml`. Requires Lima 1.0+.

User override: copy to `~/.config/dvm/lima.yaml.in` if you need structural
Lima changes. `bin/dvm` will prefer that file when it exists.

Defaults baked in:

- Fedora 41 cloud images for `aarch64` and `x86_64`. Lima picks the
  matching arch automatically.
- No `vmType` / `arch` keys — Lima detects them (`vz` on macOS,
  `qemu` on Linux).
- `mounts: []`. Host code is **not** mounted into the guest.
- `containerd: { system: false, user: false }`.
- `ssh.loadDotSSHPubKeys: false` and `forwardAgent: false`. Host SSH
  config never bleeds in.
- Port forwards rendered from `DVM_PORTS` with bind IP `DVM_HOST_IP`.
- One `provision` step (system mode): set hostname to `<vm>.dvm`,
  install bootstrap packages, create the primary user, write a
  `NOPASSWD` sudoers entry, create `DVM_CODE_DIR` owned by that user.

The guest prelude in `bin/dvm` repeats the user/code_dir steps as
idempotent shell on every sync, so changes to those values pick up
without recreating the VM.

## No host mounts

Project code lives **inside** the VM. Clone from your remote with
`dvm sh app` and the recipes you installed. This is the isolation
choice. Add a recipe and a `mounts:` block to the user-override
template only if you really need host code in a specific VM.

## VM-to-VM names

Lima exposes each instance at `lima-<name>.internal` from other Lima
instances. From an app VM:

```bash
curl http://lima-dvm-llama.internal:8080
```

From a VM to the host:

```bash
curl http://host.lima.internal:3000
```

## Updating

- Editing `DVM_PORTS` and re-syncing rewrites the YAML and starts the
  instance with new port forwards. Lima edits the running config.
- Editing the template after a VM exists does **not** rewrite structural
  fields (CPUs, memory, disk, arch, vmType). For those changes:
  `dvm rm <vm> --yes && dvm sync <vm>`.

## Troubleshooting

A failed first boot leaving stale `cloud-final.service`:

```bash
dvm ssh app -- sudo systemctl reset-failed cloud-final.service cloud-init-main.service
```

A Lima instance that exists on disk but `limactl list` doesn't show:
look under `~/.lima/dvm-<vm>/` and clean it up or `limactl delete --force`.
