# Node Supply Chain Security

DVM keeps Node installs away from the host. It does not make npm packages safe. A
malicious install script can still read the project, read VM environment variables, and
use the network.

Put package-manager policy in the project repo.

## pnpm Policy

`pnpm-workspace.yaml`:

```yaml
minimumReleaseAge: 10080
trustPolicy: no-downgrade
strictDepBuilds: true

allowBuilds:
  esbuild: true
```

Adjust `allowBuilds` for the packages your project intentionally lets run build
scripts.

What this does:

- `minimumReleaseAge`: waits before installing newly published packages
- `trustPolicy: no-downgrade`: blocks package versions with weaker provenance
- `strictDepBuilds`: fails when a dependency wants to run a build script that is not allowed
- `allowBuilds`: explicitly lists packages allowed to run build scripts

## npm Config

`.npmrc`:

```ini
save-exact=true
save-prefix=''
```

This avoids accidental semver drift when adding packages.

## Install

Inside the VM:

```bash
pnpm install --frozen-lockfile
```

In CI:

```yaml
- name: Install
  run: pnpm install --frozen-lockfile
```

## Optional Firewall

Socket Firewall can block known-bad npm packages before install. Use it as a project
or user choice, not DVM core policy.

Example user recipe:

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y nodejs npm
sudo npm install -g @socketsecurity/cli
```

Then install with:

```bash
socket npm pnpm install --frozen-lockfile
```

## Releases

For npm packages, prefer trusted publishing or OIDC where supported. Avoid long-lived
npm tokens in project VMs. See [Releases](../releases.md).

## DVM Scope

Keep this in project files:

- `pnpm-workspace.yaml`
- `.npmrc`
- lockfiles
- CI install policy

Keep this in DVM recipes:

- Node, npm, pnpm, and tool installation

Do not make DVM mutate package-manager policy automatically. Different Node projects
need different build-script allowlists.

References:

- https://eshlox.net/npm-supply-chain-security
- https://pnpm.io/settings
