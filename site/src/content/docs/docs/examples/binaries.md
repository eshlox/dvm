---
title: "Verified binary download"
description: "Download and verify upstream binaries inside the guest."
---

Avoid `curl | sh`. Prefer a pinned versioned URL, a published SHA-256 checked
before install, and a root-owned destination.

## Pattern

```bash
url="https://example.invalid/tool-v1.2.3-linux-aarch64"
sha256="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
tmp="$(mktemp)"

curl --proto '=https' --tlsv1.2 -fsSL \
  --retry 5 --retry-delay 1 --retry-all-errors --connect-timeout 20 \
  "$url" -o "$tmp"
printf '%s  %s\n' "$sha256" "$tmp" | sha256sum -c -
sudo install -m 0755 "$tmp" /usr/local/bin/tool
rm -f "$tmp"
```

`--proto '=https' --tlsv1.2` refuses anything but modern HTTPS, and the
`--retry`/`--connect-timeout` flags let the download survive a flaky network
rather than leaving a truncated file. When you bump the version, also update the
SHA-256 from the release asset page.

## Skip if already installed

Idempotent guard so re-runs are cheap:

```bash
version="0.44.3"
if zellij --version 2>/dev/null | grep -Fq "$version"; then
  echo "zellij $version already installed"
else
  url="https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-aarch64-unknown-linux-musl.tar.gz"
  sha256="15e6534d42644d66973d136c590c49739dcfd6a1a2a0d3d917973f16c81b45fb"
  tmp="$(mktemp -d)"
  curl --proto '=https' --tlsv1.2 -fsSL \
    --retry 5 --retry-delay 1 --retry-all-errors --connect-timeout 20 \
    "$url" -o "$tmp/zellij.tar.gz"
  printf '%s  %s\n' "$sha256" "$tmp/zellij.tar.gz" | sha256sum -c -
  tar -xzf "$tmp/zellij.tar.gz" -C "$tmp" zellij
  sudo install -m 0755 "$tmp/zellij" /usr/local/bin/zellij
  rm -rf "$tmp"
fi
```

The same shape works for `yazi`/`ya` (zip) and `fnm` (zip): download, check
SHA-256, unzip, `sudo install` into `/usr/local/bin`.

## From an upstream RPM

Some tools publish a `.rpm` release asset instead of a bare binary (for example
[`sops`](https://github.com/getsops/sops)). Download it, verify the SHA-256, and
hand the local file to `dnf5` so its dependencies resolve normally:

```bash
version="3.13.1"
if sops --version 2>/dev/null | grep -Fq "$version"; then
  echo "sops $version already installed"
else
  url="https://github.com/getsops/sops/releases/download/v${version}/sops-${version}-1.aarch64.rpm"
  sha256="bc2d83b897102a4640cf1cac708c96c39cbf232360c188124394c48f47120fba"
  tmp="$(mktemp -d)"
  curl --proto '=https' --tlsv1.2 -fsSL \
    --retry 5 --retry-delay 1 --retry-all-errors --connect-timeout 20 \
    "$url" -o "$tmp/sops.rpm"
  printf '%s  %s\n' "$sha256" "$tmp/sops.rpm" | sha256sum -c -
  sudo dnf5 install -y "$tmp/sops.rpm"
  rm -rf "$tmp"
fi
```

`dnf5 install` accepts a local file path and pulls in any dependencies from the
Fedora repos, so this stays cleaner than dropping a binary in `/usr/local/bin`
when the tool actually has RPM dependencies.
