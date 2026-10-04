#!/bin/bash
# Renders the Homebrew formula for a published release into a tap checkout.
# Usage: scripts/update-tap.sh <tap checkout dir> [version]   (default: VERSION)
# The checksum is taken from the release's SHA256SUMS on GitHub.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TAP="${1:?usage: scripts/update-tap.sh <tap checkout dir> [version]}"
V="${2:-$(tr -d '[:space:]' < "$REPO/VERSION")}"
SUMS=$(curl -fsSL "https://github.com/aamir-067/macscan-cli/releases/download/v$V/SHA256SUMS")
SHA=$(printf '%s\n' "$SUMS" | awk '$2 == "install-mac-triage.sh" { print $1 }')
[[ "$SHA" =~ ^[0-9a-f]{64}$ ]] || { echo "No checksum for install-mac-triage.sh in release v$V" >&2; exit 1; }
mkdir -p "$TAP/Formula"
sed -e "s/@VERSION@/$V/g" -e "s/@SHA256@/$SHA/g" "$REPO/packaging/homebrew/macscan.rb.in" > "$TAP/Formula/macscan.rb"
ruby -c "$TAP/Formula/macscan.rb" >/dev/null
echo "Formula updated to $V ($SHA) in $TAP/Formula/macscan.rb"
