#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

shell_files() {
	find bin install.sh scripts tests share/dvm -type f \
		\( -name '*.sh' -o -path 'bin/dvm' -o -path 'install.sh' \) |
		sort
}

shell_files | while IFS= read -r file; do
	bash -n "$file"
done

if command -v shellcheck >/dev/null 2>&1; then
	shell_files | xargs shellcheck
fi

find . -path ./.git -prune -o -type f -print0 |
	xargs -0 perl -ne 'if (/[ \t]$/) { print "$ARGV:$.: trailing whitespace\n"; $bad = 1 } END { exit($bad ? 1 : 0) }'

for test in tests/*.sh; do
	bash "$test"
done
