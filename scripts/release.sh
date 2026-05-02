#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
usage: scripts/release.sh <version> [options]

Promote CHANGELOG.md Unreleased entries to a versioned release, then commit and tag.

Version may be vX.Y.Z or X.Y.Z.

Options:
  --date YYYY-MM-DD  Release date. Defaults to today's UTC date.
  --no-commit        Update CHANGELOG.md but do not commit.
  --no-tag           Do not create a Git tag.
  --push             Push the release commit and tag to origin.
  --allow-dirty      Allow unrelated working tree changes.
  -h, --help         Show this help.
USAGE
}

die() {
	printf 'release: error: %s\n' "$*" >&2
	exit 1
}

log() {
	printf 'release: %s\n' "$*" >&2
}

version=""
release_date="${DVM_RELEASE_DATE:-$(date -u +%F)}"
do_commit="1"
do_tag="1"
do_push="0"
allow_dirty="0"

while [ "$#" -gt 0 ]; do
	case "$1" in
	--date)
		[ "$#" -ge 2 ] || die "--date requires YYYY-MM-DD"
		release_date="$2"
		shift 2
		;;
	--no-commit)
		do_commit="0"
		shift
		;;
	--no-tag)
		do_tag="0"
		shift
		;;
	--push)
		do_push="1"
		shift
		;;
	--allow-dirty)
		allow_dirty="1"
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	-*)
		die "unknown option: $1"
		;;
	*)
		[ -z "$version" ] || die "unexpected argument: $1"
		version="$1"
		shift
		;;
	esac
done

[ -n "$version" ] || {
	usage >&2
	exit 2
}

case "$version" in
v*) ;;
*) version="v$version" ;;
esac

printf '%s\n' "$version" | grep -Eq '^v[0-9]+[.][0-9]+[.][0-9]+([-][0-9A-Za-z.-]+)?$' ||
	die "version must look like vX.Y.Z"
printf '%s\n' "$release_date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ||
	die "date must look like YYYY-MM-DD"
if [ "$do_commit" = "0" ] && [ "$do_tag" = "1" ]; then
	die "--no-commit requires --no-tag"
fi
if [ "$do_push" = "1" ] && [ "$do_commit" = "0" ]; then
	die "--push requires a release commit"
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
	die "not inside a Git repository"
cd "$repo_root"

[ -f CHANGELOG.md ] || die "CHANGELOG.md not found"
grep -Fxq '## Unreleased' CHANGELOG.md || die "CHANGELOG.md has no ## Unreleased section"
if grep -Eq "^## ${version}([[:space:]]|$)" CHANGELOG.md; then
	die "CHANGELOG.md already contains $version"
fi
if git rev-parse -q --verify "refs/tags/$version" >/dev/null; then
	die "Git tag already exists: $version"
fi

if [ "$allow_dirty" != "1" ] && [ -n "$(git status --porcelain)" ]; then
	die "working tree is dirty; commit changes first or use --allow-dirty"
fi

unreleased="$(
	awk '
		/^## Unreleased[[:space:]]*$/ { in_unreleased = 1; next }
		in_unreleased && /^## / { exit }
		in_unreleased { print }
	' CHANGELOG.md
)"
if [ -z "$(printf '%s\n' "$unreleased" | tr -d '[:space:]')" ]; then
	die "CHANGELOG.md Unreleased section is empty"
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
awk -v version="$version" -v date="$release_date" '
	/^## Unreleased[[:space:]]*$/ {
		print
		print ""
		print "## " version " - " date
		in_unreleased = 1
		next
	}
	in_unreleased && /^## / {
		in_unreleased = 0
		print ""
		print
		next
	}
	{ print }
' CHANGELOG.md >"$tmp"
mv "$tmp" CHANGELOG.md
trap - EXIT

log "updated CHANGELOG.md for $version"

if [ "$do_commit" = "1" ]; then
	git add CHANGELOG.md
	git commit -m "Release $version"
	log "created release commit"
fi

if [ "$do_tag" = "1" ]; then
	git tag -a "$version" -m "Release $version"
	log "created tag $version"
fi

if [ "$do_push" = "1" ]; then
	branch="$(git symbolic-ref --quiet --short HEAD || true)"
	if [ -n "$branch" ]; then
		git push origin "$branch"
	else
		branch="${DVM_RELEASE_BRANCH:-main}"
		git push origin "HEAD:$branch"
	fi
	if [ "$do_tag" = "1" ]; then
		git push origin "$version"
	fi
	log "pushed release"
fi
