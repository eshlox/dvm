# Commands In VMs

Run a command:

```bash
dvm ssh app pwd
dvm ssh app pnpm test
dvm ssh app sudo dnf5 install -y htop
```

Logs:

```bash
dvm ssh app journalctl --user -xe
dvm ssh ai sudo journalctl -u dvm-llama.service -f
```

Interactive shell:

```bash
dvm app
dvm ssh app
```

Both start in `DVM_CODE_DIR`, which defaults to `~/code`.
