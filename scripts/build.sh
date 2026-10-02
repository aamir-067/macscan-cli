#!/bin/bash
# Builds the release artifacts from src/:
#   dist/install-mac-triage.sh        self-contained installer (payload as readable heredocs)
#   dist/mac-triage-<version>.tar.gz  source tarball of the installable tree
#   dist/SHA256SUMS                   checksums of both
#
# Usage: scripts/build.sh [--out DIR]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/dist"
[ "${1:-}" = "--out" ] && OUT="${2:?--out needs a directory}"

VERSION="$(tr -d '[:space:]' < "$REPO/VERSION")"
case "$VERSION" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "build: VERSION must look like MAJOR.MINOR.PATCH, got '$VERSION'" >&2; exit 1;;
esac

# Installed tree = everything under src/ except the installer itself, plus VERSION.
payload_files(){
  (cd "$REPO/src" && find . -type f ! -path './installer/*' ! -name '.DS_Store' | sed 's#^\./##' | LC_ALL=C sort)
}

rm -rf "$OUT"; mkdir -p "$OUT"
INST="$OUT/install-mac-triage.sh"

{
  sed -n '1,/^# @@PAYLOAD@@$/p' "$REPO/src/installer/install.sh" | sed '$d' | sed "s/@VERSION@/$VERSION/g"
  printf "put_file 'VERSION' <<'MACTRIAGE_EOF_VERSION'\n%s\nMACTRIAGE_EOF_VERSION\n" "$VERSION"
  n=0
  while IFS= read -r rel; do
    n=$((n+1)); marker="MACTRIAGE_EOF_$n"
    f="$REPO/src/$rel"
    if grep -q "^$marker\$" "$f"; then echo "build: $rel contains the heredoc marker $marker" >&2; exit 1; fi
    if [ -n "$(tail -c 1 "$f")" ]; then echo "build: $rel does not end with a newline" >&2; exit 1; fi
    case "$rel" in *"'"*) echo "build: file name with a quote: $rel" >&2; exit 1;; esac
    printf "put_file '%s' <<'%s'\n" "$rel" "$marker"
    cat "$f"
    printf '%s\n' "$marker"
  done < <(payload_files)
  sed -n '/^# @@PAYLOAD@@$/,$p' "$REPO/src/installer/install.sh" | sed '1d' | sed "s/@VERSION@/$VERSION/g"
} > "$INST"
chmod 755 "$INST"
bash -n "$INST"

# Tarball of the installable tree, for people who prefer to inspect files directly.
TREE="$OUT/mac-triage-$VERSION"
mkdir -p "$TREE"
bash "$INST" --extract-only "$TREE" >/dev/null
cp "$REPO/LICENSE" "$REPO/README.md" "$TREE/" 2>/dev/null || true
(cd "$OUT" && COPYFILE_DISABLE=1 tar -czf "mac-triage-$VERSION.tar.gz" "mac-triage-$VERSION")
rm -rf "$TREE"

(cd "$OUT" && shasum -a 256 install-mac-triage.sh "mac-triage-$VERSION.tar.gz" > SHA256SUMS)
echo "Built mac-triage $VERSION:"
sed 's/^/  /' "$OUT/SHA256SUMS"
