#!/bin/bash
# @title  Supply chain: vulnerable dependencies and committed secrets (opt-in)
# @quick  skip
# @toggle SUPPLY_CHAIN
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
OSV=/opt/homebrew/bin/osv-scanner; GL=/opt/homebrew/bin/gitleaks

section "Code repositories in your home folder"
R=$(tmpf)
find "$UH" -maxdepth 6 "${PRUNE_KEEPGIT[@]}" -type d -name .git -print -prune 2>/dev/null | sed 's#/\.git$##' | sort -u | head -150 > "$R"
echo "$(grep -c . "$R" || true) repositories (at most 150 are checked)"

section "Known-vulnerable dependencies (osv-scanner, offline database, runs as $U)"
if [ -x "$OSV" ]; then
  echo "Lockfiles are checked against a downloaded copy of the OSV database; package lists are not sent anywhere."
  while IFS= read -r repo; do
    out=$(tmo 900 sudo -u "$U" -H "$OSV" --offline-vulnerabilities --download-offline-databases -r "$repo" 2>&1); rc=$?
    case "$rc" in
      0) ;;
      1) sub "$repo"; echo "$out" | head -80; flag "Known-vulnerable dependencies in repository: $repo";;
      128) ;;  # no lockfiles found
      *) sub "$repo"; echo "osv-scanner could not check this repository (exit $rc):"; echo "$out" | tail -5;;
    esac
  done < "$R"
else
  echo "osv-scanner is not installed (brew install osv-scanner), skipped."
fi

section "Secrets committed to repositories (gitleaks, values redacted, runs as $U)"
if [ -x "$GL" ]; then
  while IFS= read -r repo; do
    tmo 900 sudo -u "$U" -H "$GL" dir --redact --no-banner --log-level error --report-format json --report-path /dev/stdout --exit-code 0 "$repo" 2>/dev/null \
      | gitleaks_findings | while IFS= read -r l; do
          echo "$l"; flag "Possible secret committed in repository: $l"
        done
  done < "$R"
else
  echo "gitleaks is not installed (brew install gitleaks), skipped."
fi
rm -f "$R"
