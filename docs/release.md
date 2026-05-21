# Release Process

DVM has no stable tagged release yet. Before v1.0, use `main` as the maintained
line and run:

```bash
bash scripts/check
```

## v1.0 Gate

A security-focused v1.0 release should include:

- a clean `bash scripts/check` run with ShellCheck installed
- at least one real Lima/Fedora lifecycle validation outside the fake smoke test
- an updated changelog
- a signed Git tag
- published checksums for release archives or installer artifacts
- release notes that list any recipes that intentionally track upstream latest

## Tagging

```bash
git tag -s v1.0.0 -m "DVM v1.0.0"
git push origin v1.0.0
```

Publish source archives from that tag and generate SHA-256 checksums:

```bash
sha256sum dvm-v1.0.0.tar.gz > dvm-v1.0.0.tar.gz.sha256
```

Do not call a release security-hardened unless the threat model, security
standards, and recipe supply-chain notes match the shipped code.
