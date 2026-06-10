# Design: trust-tier VMs, project containers, and `dvm reset`

Status: implemented on `v3` (commands below). The original sketch follows the
implementation summary for history; where they differ, the summary wins.

## Implemented (v3)

Runtime is **podman** (daemonless), not docker as the sketch assumed - it
removes the rootless-daemon bring-up entirely and gives rootless nesting for
compose projects.

Model: a pool **VM** (separate kernel, protects the host) hosts one
**rootless-podman container per project** (shared kernel, isolates projects from
each other). Projects are addressed `<vm>/<project>`.

Command surface:

- `dvm new <vm>` / `dvm add <vm>/<project>` - scaffold a VM, then projects.
- `dvm sync <vm>` - build the dev-base, bring up every project container.
  `dvm sync <vm>/<project>` for one.
- `dvm sh <vm>/<project>` - shell in (podman exec). `dvm ssh <vm>/<project> --
  cmd` - non-interactive.
- `dvm cp <src> <dst>` - a side may be `vm/proj:path` (file, via podman cp).
- `dvm ls <vm>` - the VM's projects + container state. `dvm logs <vm>/<project>
  [-f]`. `dvm stop <vm>/<project>`.
- `dvm reset <vm>/<project> --yes [--keep-data]` - recreate one container,
  siblings untouched. `dvm reset <vm> --yes` - rebuild the whole VM from base.
- `dvm rm <vm>/<project> --yes [--keep-data] [--config]`.

Nesting (compose): opt-in `NESTED=1` per project adds `--device /dev/fuse` and
`--security-opt label=disable` so a project can run its own rootless
`podman compose` (postgres, redis, ...) inside it. Off by default so non-compose
projects stay SELinux-confined.

dev-base + tool convergence: `dvm base dev-init` scaffolds a dev-base
Containerfile and a shared `packages.txt`. Tools are listed once in
`packages.txt` and installed into BOTH the VM base image and the dev-base
container image. dvm builds `localhost/dvm-dev-base` into each VM on sync (no
per-container tool installs), rebuilding when the dev dir or `packages.txt`
changes (tracked by a hash label) or on `DVM_REBUILD_DEV_BASE=1`. Project
containers default to it.

Ports: `PROJ_PORTS=(3000:3000)` publishes to the VM's loopback; Lima forwards
guest 127.0.0.1 ports to the Mac, so the dev server is reachable at localhost.

Persistence: containers are created `--restart=always` and `podman-restart` is
enabled, so they return on VM reboot; `sh`/`ssh` also start a stopped container.

Verification: `tests/smoke.sh` covers the command surface against a mock
`limactl`. The Lima/podman runtime paths (rootless podman over `sudo`, nested
podman, port forwarding, dev-base build) still need on-Mac validation.

## Motivation

Running one full VM per project is the heaviest point on the isolation
spectrum. With 10+ projects it costs real RAM, battery, and per-VM
configuration, and it makes things like Expo painful because mobile tooling
wants the macOS host (simulator, GPU, native toolchain). The security model is
strong, but the per-project full-OS cost is the friction.

The boundary that actually protects *personal data* (documents, photos,
passwords, browser profiles, Keychain) is the **VM boundary** - the host home
dir is never mounted (`--mount-none`). Containers inside a shared VM protect
*projects from each other* and give per-project disposability, but they share a
kernel, so they are a weaker boundary than VM-per-project. That is fine for
"these are all my own semi-trusted projects" and lets one VM host many projects.

## Two facts that shape the whole design

1. **dvm already bakes rootless Docker into the base image**
   (`bin/dvm:805-820`). The machinery for "one container per project inside a
   VM" already runs in every VM you boot - it just is not addressed from the CLI
   yet. So this is far less of a rewrite than it sounds.

2. **Lima's `limactl snapshot` is QEMU-only. The `vz` driver dvm defaults to on
   Apple Silicon (`bin/dvm:213-217`) does not support VM snapshots.** So "reset"
   cannot mean "revert the VM to a saved snapshot" on the primary platform. That
   pushes toward the better design anyway: **reset = recreate the disposable
   layer from a clean base.** Code is meant to be committed and pushed already
   (`--mount-none`), so this is in-grain.

These converge on one model.

## The model: VMs become trust groups, projects become containers

| Layer | Role | Reset cost | Boundary strength |
|---|---|---|---|
| **VM** (trust group) | durable boundary protecting the *host* | expensive (rebuild) | strong - separate kernel |
| **Container** (project) | disposable boundary protecting *projects from each other* | seconds (`docker rm` + recreate) | weaker - shared kernel |

Instead of 10 VMs, you have ~3 VMs by **trust tier** (`trusted`, `untrusted`,
`clientx`), each running N project containers. The container layer is what makes
reset granular and cheap - which is exactly what the missing vz snapshot forces
you toward. The two features are the same feature.

Addressing becomes `<vm>/<project>`:

```
dvm new   trusted                    # a pool VM for trusted projects (one OS, baked tools)
dvm add   trusted/api                # define a project -> a container spec under that VM
dvm add   trusted/web --port 5173
dvm sync  trusted                    # ensure the VM + every project container in it
dvm sh    trusted/api                # shell INTO the api container (cwd = its workspace)
dvm reset trusted/api --yes          # recreate just that container; web + the VM untouched
dvm reset trusted --yes              # rebuild the whole VM from base (the heavy reset)
dvm rm    trusted/web --yes          # drop one project container
```

Each project container gets:

- its **own writable workspace** (a named Docker volume `dvm-<vm>-<proj>`), so
  its code/node_modules survive container recreation unless you reset the volume
  too;
- its **own user namespace + filesystem** - a poisoned `npm install` in `api`
  cannot read `web`'s source, tokens, or `~/.ssh`, and none of them can touch
  the host;
- its **own port mapping**, plumbed out through the existing `DVM_PORTS` -> Lima
  forward chain.

The VM is rarely reset (it is your durable boundary). Projects are reset
constantly and for free.

## Data model (fits the existing config layout)

Today: `~/.config/dvm/vms/<name>/{config.sh,setup.sh}`. Extend, don't replace:

```
~/.config/dvm/vms/trusted/
  config.sh            # VM-level: DVM_MEMORY, DVM_VM_TYPE, etc. (unchanged)
  setup.sh             # VM-level provisioning (unchanged)
  projects/
    api/
      project.sh       # IMAGE=node:22, PORTS=(3000:3000), WORKDIR=/work
      setup.sh         # per-project: clone repo, npm ci, auth - runs INSIDE the container
    web/
      project.sh
      setup.sh
```

`project.sh` is sourced Bash exactly like `config.sh` - same `assert_safe_path`
ownership/permission checks (`bin/dvm:156-174`), same convention, no new config
language. A new `load_project <vm>/<proj>` mirrors `load_vm`
(`bin/dvm:241-261`):

```bash
load_project() {
    local spec="$1" vm proj
    vm="${spec%%/*}"; proj="${spec#*/}"
    load_vm "$vm"                                   # reuse: name validation, base image, locks
    valid_name "$proj" || die "invalid project name: $proj"
    local d="$DVM_CONFIG_DIR/vms/$vm/projects/$proj"
    [ -f "$d/project.sh" ] || die "no project \"$proj\" in VM \"$vm\" ($d)"
    assert_safe_path "$d" "project directory"
    assert_safe_path "$d/project.sh" "project config"
    # project defaults, then override
    PROJ_IMAGE=dvm-base; PROJ_PORTS=(); PROJ_WORKDIR=/work
    . "$d/project.sh"
    DVM_PROJECT="$proj"
    DVM_PROJ_VOLUME="dvm-${vm}-${proj}"             # durable workspace volume
    DVM_PROJ_CONTAINER="dvm-${proj}"                # container name inside the VM
    PROJ_SETUP="$d/setup.sh"; [ -f "$PROJ_SETUP" ] || PROJ_SETUP=
    assert_setup_script "$PROJ_SETUP" "project setup script"
}
```

## How the commands compile down

Every project command is "run a docker command inside the VM as `DVM_USER`" -
which is exactly the existing `ensure_running_quiet` +
`limactl shell ... sudo -u "$DVM_USER"` pattern from `cmd_sh`/`cmd_ssh`
(`bin/dvm:494-521`). No new transport, just a new payload.

A one-line helper wraps the call dvm already makes:

```bash
guest_docker() {
    "$LIMACTL" shell "$DVM_LIMA_NAME" sudo -u "$DVM_USER" -H bash -lc \
        'exec "$@"' bash docker "$@"
}
```

**`dvm sync trusted/api`** - ensure VM up, then ensure the container exists
(idempotent; workspace volume persists):

```bash
project_up() {
    local ports=() p
    for p in "${PROJ_PORTS[@]:-}"; do ports+=(-p "$p"); done
    guest_docker bash -lc '
        name="$1"; image="$2"; vol="$3"; wd="$4"; shift 4
        docker container inspect "$name" >/dev/null 2>&1 || \
          docker create --name "$name" -v "$vol":"$wd" -w "$wd" "${@}" "$image" sleep infinity
        docker start "$name"
    ' bash "$DVM_PROJ_CONTAINER" "$PROJ_IMAGE" "$DVM_PROJ_VOLUME" "$PROJ_WORKDIR" "${ports[@]}"
    [ -n "$PROJ_SETUP" ] && run_step "setup $DVM_PROJECT" "$(vm_log setup)" project_exec_setup
}
```

**`dvm sh trusted/api`** - same as `cmd_sh` but the exec target is
`docker exec` instead of a login shell:

```bash
exec "$LIMACTL" shell "$DVM_LIMA_NAME" sudo -u "$DVM_USER" -H bash -lc \
    'exec docker exec -it -w "$2" "$1" bash -l' bash "$DVM_PROJ_CONTAINER" "$PROJ_WORKDIR"
```

**`dvm reset trusted/api --yes`** - the headline. No VM rebuild, no snapshot
needed:

```bash
cmd_reset() {
    local spec="$1"; shift
    require_yes "$@"
    if [[ "$spec" == */* ]]; then               # project reset - the cheap path
        load_project "$spec"
        lock_vm "${spec%%/*}"
        ensure_running_quiet
        local keep_data=0; [[ " $* " == *" --keep-data "* ]] && keep_data=1
        run_step "resetting $spec" "$(vm_log lima)" project_reset "$keep_data"
        step_ok "$spec reset"
    else                                         # VM reset - recreate from base image
        load_vm "$spec"
        # = cmd_rm (keep config) + cmd_sync. Works on vz precisely because it
        #   rebuilds from $DVM_BASE_IMAGE rather than reverting a snapshot.
        remove_lima_instance
        cmd_sync "$spec"
    fi
}

project_reset() {
    local keep_data="$1"
    guest_docker bash -lc 'docker rm -f "$1" 2>/dev/null || true' bash "$DVM_PROJ_CONTAINER"
    [ "$keep_data" = "1" ] || guest_docker bash -lc \
        'docker volume rm "$1" 2>/dev/null || true' bash "$DVM_PROJ_VOLUME"
    project_up                                    # recreate clean, re-run project setup.sh
}
```

`--keep-data` recreates the container (fresh OS/tools, drops any malware that
hooked the runtime) but keeps the workspace volume (repo + node_modules). Omit
it for a total wipe that re-clones from scratch. That is the "I think something
is off, give me a clean runtime in 5 seconds" button - what vz snapshots would
have given you, except scoped to one project and faster.

**Dispatch** (`bin/dvm:1084-1097`) gains `add`, `reset`, and `sh`/`ssh`/`rm`/
`sync` learn to branch on whether the arg contains `/`. That branch is the only
change to existing commands.

## Honest tradeoffs

1. **Shared kernel between a VM's projects.** Containers in one VM share the
   guest kernel. A kernel-level escape from `api`'s container could reach
   `web`'s. Fine for "all my own semi-trusted projects"; **not** for genuinely
   hostile code - that still gets its own VM (`dvm new untrusted` with one
   project, or no container at all). The rule: trust tier = VM, never mix tiers
   in one VM.

2. **Rootless-docker storage cost.** Each project image/layer lives in the VM's
   disk (`DVM_DISK`, default 30G). Ten Node projects sharing one `node:22` base
   is far cheaper than ten VMs, but tune `DVM_DISK` up per pool and add a
   `dvm prune` for dangling images/volumes.

3. **Two reset semantics.** `reset <vm>/<proj>` (cheap, common) vs `reset <vm>`
   (rebuild, rare). Make the project form the default mental model and the VM
   form clearly heavier in `--help`.

4. **More surface area.** dvm's AGENTS.md says keep core focused. This roughly
   doubles the command set. Reasonable to gate behind being genuinely sold on
   the trust-tier model first.

## Suggested phasing

Ship in order of value-per-risk; each step is independently useful:

1. **`dvm reset <vm> --yes`** (VM-level, recreate-from-base). ~30 lines, reuses
   `remove_lima_instance` + `cmd_sync`, zero new concepts, works on vz today.
   Gives disposability immediately, before any container work.
2. **Project layer**: `add` / `load_project` / `sync` / `sh` for containers. The
   bulk.
3. **`dvm reset <vm>/<proj>`** with `--keep-data`. The granular reset - the goal.
4. **`dvm prune`** + docs on the trust-tier model.

Step 1 is small, safe, and felt the same day.

## Appendix: the host-side practices this complements

dvm covers the isolation boundary. The full "safely develop 10+ projects on one
macOS laptop" picture also wants, roughly in order of leverage:

1. Put dependency execution behind a boundary that cannot see your home dir
   (this is what dvm does).
2. Kill install scripts by default (`npm config set ignore-scripts true`; `uv` /
   `pip --require-hashes`).
3. No long-lived secrets in plaintext on disk (1Password CLI `op run`, Keychain).
4. Scope credentials per project, least-privilege, throwaway (per-context SSH
   keys, fine-grained PATs, separate cloud roles).
5. A second macOS user account for dev, separate from personal data.
6. Slow down and vet the dependency stream (lockfiles, pin versions, minimum
   release age, Socket.dev, `npm audit`).
7. Separate browser profiles for dev vs life.
8. Watch/control outbound traffic (Little Snitch / LuLu).
9. Run AI coding agents inside the same boundary as dependencies.
10. Make compromise survivable (FileVault, encrypted backups, disposability).
