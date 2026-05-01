# Releases

Recommended DVM release model:

- Develop and commit inside the project VM.
- Use per-VM SSH keys for GitHub auth and commit signing.
- Do not copy personal GPG private keys into project VMs.
- Let GitHub Actions build release artifacts from pushed tags.
- Use artifact attestations or keyless signing instead of personal release keys.

## Daily Flow

Inside the VM:

```bash
git commit -m "change"
git tag v1.2.3
git push origin main v1.2.3
```

GitHub Actions builds the release from the tag. The host does not need project source,
Node, Python, GPG, or GitHub credentials for release work.

## Harden The Repository

Recommended GitHub settings:

- Protect `main`.
- Protect release tags such as `v*` with a repository ruleset.
- Require pull requests or required status checks before merging.
- Restrict who can push release tags.
- Use least-privilege `GITHUB_TOKEN` permissions in workflows.
- Avoid long-lived secrets when GitHub OIDC or trusted publishing is available.
- Pin third-party actions by commit SHA when security matters.

## Release Workflow

`.github/workflows/release.yml`:

```yaml
name: release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: read

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
      attestations: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          persist-credentials: false

      - name: Build
        run: |
          set -euo pipefail
          mkdir -p dist
          tar \
            --exclude=.git \
            --exclude=dist \
            -czf "dist/${GITHUB_REPOSITORY#*/}-${GITHUB_REF_NAME}.tar.gz" \
            .

      - name: Attest artifacts
        uses: actions/attest@v4
        with:
          subject-path: "dist/*"

      - name: Create GitHub release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "$GITHUB_REF_NAME" dist/* \
            --verify-tag \
            --generate-notes
```

Adjust the `Build` step for the project. For Node, Python, Rust, Go, or containers,
build the real release artifacts and attest those files.

## OIDC And Secrets

Prefer OIDC or trusted publishing:

- Use GitHub OIDC for cloud providers.
- Use trusted publishing for registries that support it, such as PyPI.
- Use `GITHUB_TOKEN` for GitHub releases.
- Use `packages: write` only when publishing to GitHub Packages or GHCR.

Avoid putting a personal GPG key into Actions secrets. If a project truly needs GPG
artifact signing, use a dedicated release key with minimal scope, rotate it
deliberately, and store it only as a repository or environment secret.

## GPG Release Tags

For most DVM projects, prefer CI releases and artifact attestations over manually
GPG-signed tags.

Use a personal long-lived GPG key only for important public release tags where humans
or downstream systems explicitly verify that key. If you do that, sign from a trusted
host or offline environment, not from the project VM.

## Verify

Consumers can verify GitHub artifact attestations with:

```bash
gh attestation verify path/to/artifact -R owner/repo
```

Commit and tag badges are useful provenance. Release artifacts and attestations are the
stronger thing to verify before running downloaded software.

References:

- https://docs.github.com/actions/concepts/security/about-security-hardening-with-openid-connect
- https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds
- https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-guides/security-hardening-for-github-actions
