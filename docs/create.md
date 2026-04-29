# Create VMs

```bash
dvm init app
dvm edit app
dvm create app
dvm app
```

Per-VM config:

```text
~/.config/dvm/vms/app.sh
```

Global defaults live in:

```text
~/.config/dvm/config.sh
```

The global config is loaded first, then the per-VM config. Use global config for the
tools/dotfiles you want in most VMs, and clear or override those values in special VMs.

Useful per-VM config:

```bash
DVM_PACKAGES="$DVM_PACKAGES nodejs pnpm"
DVM_PORTS="3000:3000 5173:5173"
```

See [Config](config.md) for append/override/disable examples.

Default size is intentionally small:

```bash
DVM_CPUS="2"
DVM_MEMORY="4GiB"
DVM_DISK="40GiB"
DVM_NETWORK="user-v2"
```

Inline setup runs inside the VM:

```bash
dvm_vm_setup() {
	mkdir -p "$DVM_CODE_DIR"
}
```

After editing config:

```bash
dvm setup app
```

Port changes restart the VM because Lima cannot edit a running instance.

Run one command inside a VM:

```bash
dvm ssh app pwd
dvm ssh app journalctl --user -xe
dvm ssh app sudo journalctl -u dvm-llama.service -f
```

Enter an interactive shell:

```bash
dvm app
```
