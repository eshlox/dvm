# Lima

DVM's job is to render one Lima YAML and then get out of the way.

## Template

The default template lives in the repo:

```text
share/dvm/lima.yaml.in
```

If you need structural Lima changes, create a user override:

```bash
cp share/dvm/lima.yaml.in ~/.config/dvm/lima.yaml.in
```

When `~/.config/dvm/lima.yaml.in` exists, DVM uses it. Otherwise DVM uses the bundled
template from `share/dvm/lima.yaml.in`. `install.sh --init` does not copy the Lima
template into user config, so normal installs do not get stale local templates.

Important defaults:

- Fedora image template.
- `vmType: vz` for macOS virtualization.
- `mounts: []` so host code is not mounted into the guest.
- containerd disabled by default.
- `user-v2` networking for VM-to-VM names.
- port forwards rendered from `DVM_PORTS`.
- guest port `5355` ignored to avoid Fedora LLMNR forwarding noise.
- minimal first-boot provision installs only bootstrap tools.
- user first-boot provision ignores empty or host-looking `/Users/...` code dirs rather
  than failing cloud-init.

DVM sets the guest system hostname to the public VM name during `dvm apply`, so a VM
configured as `eshlox-net` presents itself as `eshlox-net` inside the guest even though
the internal Lima instance remains `dvm-eshlox-net`.

## No Host Mounts

No host project directory is mounted by default. Code lives inside the VM and is cloned
from Git remotes or created there. This is the central isolation choice.

Use:

```bash
dvm enter app
```

Then edit with guest tools installed by your recipes, such as an editor, AI CLI, or
project-local tooling.

## VM To VM

With `user-v2`, Lima gives VM names like:

```text
lima-dvm-llama.internal
lima-dvm-cloudflared.internal
```

From another VM:

```bash
curl http://lima-dvm-llama.internal:8080
```

From a VM to macOS:

```bash
curl http://host.lima.internal:3000
```

## Updating Ports And Template

Editing `DVM_PORTS` in a VM config and running `dvm apply <name>` updates the existing
Lima VM's `portForwards` without recreating the VM. DVM compares the configured ports
with the VM's Lima YAML and asks Lima to edit the VM when they differ.

Editing the bundled template affects future VMs created from this checkout. Editing a
user override affects future VMs for that user. Existing Lima instances keep their
created configuration for structural settings. For those changes, recreate:

```bash
dvm rm app --yes
dvm apply app
```

If an older VM shows failed `cloud-final.service` or `cloud-init-main.service` because
first boot tried to create an empty code directory or a host-looking `/Users/...` path,
the VM can still be usable. Recreate it for the clean template, or clear the stale
failed state after confirming the logs:

```bash
dvm ssh app -- sudo systemctl reset-failed cloud-final.service cloud-init-main.service
```

If Lima briefly reports `instance "dvm-..." already exists` during `dvm apply`, DVM
treats that as a stale existence check and continues with start/apply.
