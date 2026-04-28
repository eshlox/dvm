# Maintainer Release Process

Run checks before tagging:

```bash
bash scripts/check.sh
```

Create a signed annotated tag:

```bash
git tag -s vX.Y.Z -m "dvm vX.Y.Z"
```

Push the branch and tag:

```bash
git push origin main
git push origin vX.Y.Z
```

Create the GitHub release from the signed `v*` tag.

Release rules:

- publish releases only from signed `v*` tags
- do not move, delete, or replace published release tags
- if a release is bad, publish a new fixed release
- keep GitHub release settings aligned with [github-security.md](github-security.md)
