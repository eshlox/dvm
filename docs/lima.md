# Lima

DVM's job is to render one Lima YAML and then get out of the way.

## Template

The template lives at:

```text
~/.config/dvm/lima.yaml.in
```

If that file is missing, DVM falls back to the bundled `share/dvm/lima.yaml.in`.

Important defaults:

- Fedora image template.
- `vmType: vz` for macOS virtualization.
- `mounts: []` so host code is not mounted into the guest.
- containerd disabled by default.
- `user-v2` networking for VM-to-VM names.
- port forwards rendered from `DVM_PORTS`.
- guest port `5355` ignored to avoid Fedora LLMNR forwarding noise.
- minimal first-boot provision installs only bootstrap tools.

## No Host Mounts

No host project directory is mounted by default. Code lives inside the VM and is cloned
from Git remotes or created there. This is the central isolation choice.

Use:

```bash
dvm enter app
```

Then edit with guest tools such as Helix, lazygit, Codex, Claude, or project-local
tooling.

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

Editing other parts of `lima.yaml.in` affects newly created VMs. Existing Lima
instances keep their created configuration for structural settings. For those changes,
recreate:

```bash
dvm rm app --yes
dvm apply app
```
