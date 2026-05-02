# Networking

DVM exposes services to the host with `DVM_PORTS`:

```bash
DVM_PORTS="8080:8080 3000:3000"
```

Then from macOS:

```text
http://127.0.0.1:8080
```

DVM binds forwarded ports to localhost by default:

```bash
DVM_HOST_IP="127.0.0.1"
```

For testing from another device on your LAN, bind to all host interfaces:

```bash
DVM_HOST_IP="0.0.0.0"
```

Only use that for services you are comfortable exposing to your local network.
Changing `DVM_HOST_IP` requires `dvm setup <name>` so Lima can rewrite the port
forwards.

DVM also tells Lima to ignore guest port `5355` automatically. Fedora may listen on
`5355` for LLMNR, and forwarding it from every VM causes harmless
`address already in use` warnings on macOS.

## VM To VM

DVM creates new VMs with Lima `user-v2` networking by default:

```bash
DVM_NETWORK="user-v2"
```

That gives VM-to-VM names like:

```text
lima-dvm-ai.internal
```

From another DVM VM:

```bash
curl http://lima-dvm-ai.internal:8080
```

From a VM to a service running on macOS:

```bash
curl http://host.lima.internal:3000
```

If you need Lima's VZ NAT instead:

```bash
DVM_NETWORK="vzNAT"
```

Existing VMs keep the network they were created with. To change networking, recreate
the VM or edit the Lima instance manually while it is stopped.

Reference:

- https://lima-vm.io/docs/config/network/user-v2/
