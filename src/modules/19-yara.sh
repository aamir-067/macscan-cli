#!/bin/bash
# @title  YARA malware rule scan
# @quick  skip
# @toggle YARA
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
Y=/opt/homebrew/bin/yara; R="$ROOT/rules/all.yarc"
section "YARA malware rule scan (runs as $U, never as root)"
[ -x "$Y" ] || { echo "YARA is not installed, skipped."; exit 0; }
[ -f "$R" ] || { flag "No compiled YARA rules (run: macscan --update-rules)"; exit 0; }
echo "YARA $(sudo -u "$U" "$Y" --version) | rule sets: $(cat "$ROOT/rules/sets.txt" 2>/dev/null)"
T=()
for d in "$UH"/* "$UH"/.[!.]*; do
  case "$(basename "$d")" in Library|Movies|Music|Pictures|.Trash|.orbstack|.npm|.cache|.gradle|.rustup|.cargo|.bun|.android|.m2|.pub-cache|.cocoapods|.docker|go) continue;; esac
  [ -e "$d" ] && T+=("$d")
done
T+=("$UH/Library/LaunchAgents" "$AS" "$UH/Library/Scripts" /Library/LaunchAgents /Library/LaunchDaemons "/Library/Application Support" /Library/PrivilegedHelperTools /Library/Security/SecurityAgentPlugins /Users/Shared /private/tmp /private/var/tmp)
for a in /Applications/* "$UH"/Applications/*; do case "$a" in */Xcode*.app|*/"Android Studio.app"|*Simulator*|*/Utilities|*/Safari.app) continue;; esac; T+=("$a"); done
echo "Scanning ${#T[@]} locations (files over 50 MB skipped)..."
O=$(mktemp /tmp/mactriage.XXXXXX)
for t in "${T[@]}"; do
  [ -e "$t" ] || continue
  tmo 5400 sudo -u "$U" -H "$Y" -C -r -N -w -f -z 50000000 -p 4 "$R" "$t" 2>/dev/null >> "$O"
done
grep -vF "$OUTBASE/" "$O" | grep -vF "$ROOT/" | sort -u > "$O.m"
sub "Matches"
if [ -s "$O.m" ]; then cat "$O.m"; while read -r rule path; do flag "YARA match: $rule -> $path"; done < "$O.m"; else echo "No YARA matches."; fi
rm -f "$O" "$O.m"
