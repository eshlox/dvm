# Dependencies

## Host Support

DVM currently targets macOS hosts.

Linux support is conceptually possible and can still make sense when you want a VM
boundary instead of container isolation from Podman, toolbox, distrobox, or similar
tools. It is not implemented or tested today because DVM currently creates Lima VMs
with macOS `vmType: vz`.

Windows is not supported. Use WSL2, Dev Containers, Hyper-V, or a dedicated Linux VM
instead.

## Host Dependencies

Required:

- macOS
- Bash
- standard Unix tools: `awk`, `grep`, `sed`, `sort`, `paste`, `du`
- Lima, including `limactl`

Install Lima with Homebrew:

```bash
brew install lima
```

DVM creates VMs with Lima `vmType: vz`, so use macOS 13 or newer.

Optional:

- `tar`: required only when `DVM_DOTFILES_DIR` is enabled
- `git`: required to clone/update the DVM repository
- `gpg`: required to verify signed DVM release tags
- `shellcheck`: required only for development checks

## Guest

DVM targets the Lima Fedora template:

```bash
DVM_TEMPLATE="template:fedora"
```

The guest must have:

- Bash
- `sudo`
- `dnf5`
- `systemd`

The default Fedora cloud image provides these. DVM intentionally supports only `dnf5`
instead of supporting both `dnf` and `dnf5`.

Feature-specific guest tools:

- `dvm ssh-key <name>` needs `ssh-keygen`
- `dvm gpg-key <name>` needs `gpg`
- `llama.sh` installs Fedora `llama-cpp` and `curl`
- `agent.sh` installs `bubblewrap`, `acl`, `shadow-utils`, and `npm`
- `cloudflared.sh` installs `curl`, adds the Cloudflare RPM repo, and installs `cloudflared`

References:

- https://lima-vm.io/docs/installation/
- https://lima-vm.io/docs/config/vmtype/vz/
