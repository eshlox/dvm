---
title: "Verified binary download"
description: "Install upstream binaries not in dnf as verified, pinned Containerfile layers."
---

For tools not packaged in Fedora, avoid `curl | sh`. Pin a versioned URL, verify
a published SHA-256 before install, and write to a root-owned destination. In a
Containerfile each tool is one `RUN` layer, so a version bump rebuilds only that
layer.

The versions and checksums below are examples. DVM does not track them: pin the
version you want, and update the `SHA256` from the release asset page whenever
you bump it. The URLs are `aarch64`; change the arch for your host.

## Pattern

```dockerfile
ARG TOOL_VERSION=1.2.3
ARG TOOL_SHA256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
RUN url="https://example.invalid/tool-v${TOOL_VERSION}-linux-aarch64" \
 && curl --proto '=https' --tlsv1.2 -fsSL \
      --retry 5 --retry-delay 1 --retry-all-errors --connect-timeout 20 \
      "$url" -o /tmp/tool \
 && printf '%s  %s\n' "$TOOL_SHA256" /tmp/tool | sha256sum -c - \
 && install -m 0755 /tmp/tool /usr/local/bin/tool \
 && rm -f /tmp/tool
```

`--proto '=https' --tlsv1.2` refuses anything but modern HTTPS; the `--retry`
flags survive a flaky network instead of leaving a truncated file. No idempotency
guard is needed: the build caches the layer and skips it until the `ARG` changes.

## Tarball (zellij)

```dockerfile
ARG ZELLIJ_VERSION=0.44.3
ARG ZELLIJ_SHA256=15e6534d42644d66973d136c590c49739dcfd6a1a2a0d3d917973f16c81b45fb
RUN url="https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-aarch64-unknown-linux-musl.tar.gz" \
 && curl --proto '=https' --tlsv1.2 -fsSL \
      --retry 5 --retry-delay 1 --retry-all-errors --connect-timeout 20 \
      "$url" -o /tmp/zellij.tgz \
 && printf '%s  %s\n' "$ZELLIJ_SHA256" /tmp/zellij.tgz | sha256sum -c - \
 && tar -xzf /tmp/zellij.tgz -C /usr/local/bin zellij \
 && rm -f /tmp/zellij.tgz
```

## Zip (yazi, fnm)

`yazi` ships `yazi` and `ya` in a versioned subdirectory; `fnm` ships a bare
binary. Same shape, `unzip` instead of `tar`:

```dockerfile
ARG YAZI_VERSION=26.5.6
ARG YAZI_SHA256=c38b07961e7fc4c76503fd0f4a1b4bd0b379a99835b818cd899b0315c728e1e1
RUN url="https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-aarch64-unknown-linux-gnu.zip" \
 && curl --proto '=https' --tlsv1.2 -fsSL \
      --retry 5 --retry-delay 1 --retry-all-errors --connect-timeout 20 \
      "$url" -o /tmp/yazi.zip \
 && printf '%s  %s\n' "$YAZI_SHA256" /tmp/yazi.zip | sha256sum -c - \
 && unzip -q /tmp/yazi.zip -d /tmp/yazi \
 && install -m 0755 /tmp/yazi/yazi-*/yazi /usr/local/bin/yazi \
 && install -m 0755 /tmp/yazi/yazi-*/ya /usr/local/bin/ya \
 && rm -rf /tmp/yazi /tmp/yazi.zip
```

## Upstream RPM (sops)

Some tools publish a `.rpm` asset (for example
[`sops`](https://github.com/getsops/sops)). Verify it, then hand the local file
to `dnf5` so its dependencies resolve normally:

```dockerfile
ARG SOPS_VERSION=3.13.1
ARG SOPS_SHA256=bc2d83b897102a4640cf1cac708c96c39cbf232360c188124394c48f47120fba
RUN url="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-${SOPS_VERSION}-1.aarch64.rpm" \
 && curl --proto '=https' --tlsv1.2 -fsSL \
      --retry 5 --retry-delay 1 --retry-all-errors --connect-timeout 20 \
      "$url" -o /tmp/sops.rpm \
 && printf '%s  %s\n' "$SOPS_SHA256" /tmp/sops.rpm | sha256sum -c - \
 && dnf5 install -y /tmp/sops.rpm \
 && dnf5 clean all \
 && rm -f /tmp/sops.rpm
```

`dnf5 install` accepts a local path and pulls in dependencies from the Fedora
repos, cleaner than a bare binary when the tool actually has RPM dependencies.
