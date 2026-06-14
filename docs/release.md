# Release process

Releases are cut from `main` and tagged `vX.Y.Z`. `main` is the maintained line;
development happens on feature branches that merge into it via pull request.

Before tagging a release:

```bash
bash scripts/check
```

## Release gate

A release should include:

- a clean `bash scripts/check` run with ShellCheck installed
- the base-image upstreams pinned to real sha256 digests (`scripts/update-pins`),
  which `scripts/check` enforces
- an updated `CHANGELOG.md` with the version and date
- the version bumped in `bin/dvm` (`DVM_VERSION`)
- at least one real Lima lifecycle validation outside the fake smoke test
- a signed Git tag
- published SHA-256 checksums for the source archive
- release notes describing notable command/config behavior

## Tagging

```bash
git tag -s v3.0.0 -m "DVM v3.0.0"
git push origin v3.0.0
```

Publish a source archive from that tag and its SHA-256 checksum:

```bash
git archive --format=tar.gz --prefix=dvm-3.0.0/ -o dvm-v3.0.0.tar.gz v3.0.0
sha256sum dvm-v3.0.0.tar.gz > dvm-v3.0.0.tar.gz.sha256
```

Do not call a release security-hardened unless the threat model, security
standards, and setup-script guidance match the shipped code.
