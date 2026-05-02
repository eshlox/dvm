#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
git init -q
git config user.name "DVM Test"
git config user.email "dvm-test@example.invalid"

cat >CHANGELOG.md <<'CHANGELOG'
# Changelog

## Unreleased

- Added release helper.

## v0.1.0 - 2026-01-01

- Older release.
CHANGELOG

git add CHANGELOG.md
git commit -qm "Initial changelog"

"$ROOT/scripts/release.sh" 1.2.3 --date 2026-05-02 >/dev/null 2>&1

grep -Fq '## Unreleased' CHANGELOG.md
grep -Fq '## v1.2.3 - 2026-05-02' CHANGELOG.md
grep -Fq -- '- Added release helper.' CHANGELOG.md
[ "$(git log -1 --format=%s)" = "Release v1.2.3" ]
git rev-parse -q --verify refs/tags/v1.2.3 >/dev/null
