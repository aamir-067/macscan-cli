#!/bin/bash
# Bumps VERSION and moves the CHANGELOG "Unreleased" notes under the new version.
# Usage: scripts/bump-version.sh patch|minor|major|X.Y.Z
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cur="$(tr -d '[:space:]' < "$REPO/VERSION")"
IFS=. read -r ma mi pa <<<"$cur"
case "${1:-}" in
  patch) new="$ma.$mi.$((pa+1))";;
  minor) new="$ma.$((mi+1)).0";;
  major) new="$((ma+1)).0.0";;
  [0-9]*.[0-9]*.[0-9]*) new="$1";;
  *) echo "Usage: $0 patch|minor|major|X.Y.Z (current: $cur)" >&2; exit 2;;
esac
[[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Not a version: $new" >&2; exit 2; }
grep -q "^## \[$new\]" "$REPO/CHANGELOG.md" && { echo "CHANGELOG already has $new" >&2; exit 1; }

today="$(date +%Y-%m-%d)"
repo_url="https://github.com/aamir-067/macscan-cli"
perl -0pi -e "
  s/^## \[Unreleased\]\n/## [Unreleased]\n\n## [$new] - $today\n/m;
  s{^\[Unreleased\]: .*\$}{[Unreleased]: $repo_url/compare/v$new...HEAD\n[$new]: $repo_url/compare/v$cur...v$new}m;
" "$REPO/CHANGELOG.md"
echo "$new" > "$REPO/VERSION"
echo "Version $cur -> $new. Review CHANGELOG.md, commit, then run: make release"
