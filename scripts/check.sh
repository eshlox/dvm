#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for file in bin/dvm lib/*.sh install.sh recipes/*.sh tests/*.sh; do
	bash -n "$file"
done

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck bin/dvm lib/*.sh install.sh recipes/*.sh tests/*.sh
fi

find . -path ./.git -prune -o -type f -print0 |
	xargs -0 perl -ne 'if (/[ \t]$/) { print "$ARGV:$.: trailing whitespace\n"; $bad = 1 } END { exit($bad ? 1 : 0) }'

bash tests/smoke.sh
