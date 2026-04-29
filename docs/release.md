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

## Config Compatibility

User config is user-owned. Releases must not require DVM to silently rewrite
`~/.config/dvm/config.sh` or files under `~/.config/dvm/setup.d`.

Rules for config changes:

- New config options must have defaults in `dvm_load_config`.
- New generated config lines must use fallback form, such as
  `DVM_EXAMPLE="${DVM_EXAMPLE:-value}"`.
- Old generated configs should keep working when sourced after current core defaults.
- Changed defaults affect users who did not explicitly pin a value.
- Renaming or removing options requires a deprecation period and `dvm doctor` warnings.
- Add or update a fixture under `tests/fixtures` when changing config compatibility.

Before release, run:

```bash
bash scripts/check.sh
```

That includes upgrade checks against old config fixtures.
