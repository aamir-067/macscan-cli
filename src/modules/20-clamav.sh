#!/bin/bash
# @title  ClamAV antivirus scan
# @quick  skip
# @toggle CLAMAV
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
C=/opt/homebrew/bin/clamscan
section "ClamAV antivirus scan (runs as $U, never as root)"
[ -x "$C" ] || { echo "ClamAV is not installed, skipped."; exit 0; }
ls /opt/homebrew/var/lib/clamav/*.c[lv]d >/dev/null 2>&1 || { flag "ClamAV has no signature database (run: macscan --update-rules)"; exit 0; }
echo "$(sudo -u "$U" "$C" --version) | scope: $CLAM_SCOPE"
EX=(--exclude-dir='/Library/CloudStorage' --exclude-dir='/\.orbstack' --exclude-dir='orbstack' --exclude-dir='/\.Trash' --exclude-dir="^$OUTBASE" --exclude-dir="^$ROOT" --exclude-dir='/Xcode[^/]*\.app' --exclude-dir='/Android Studio\.app' --exclude-dir='Simulator' --exclude-dir='/\.git$' --exclude-dir='/Library/Caches')
if [ "$CLAM_SCOPE" = full ]; then
  TG=("$UH" /Applications /Library /Users/Shared /private/tmp /private/var/tmp)
else
  EX+=(--exclude-dir='node_modules')
  TG=("$UH/Downloads" "$UH/Desktop" "$UH/Documents" "$UH/Library/LaunchAgents" "$AS" /Applications /Library/LaunchAgents /Library/LaunchDaemons "/Library/Application Support" /Library/PrivilegedHelperTools /Users/Shared /private/tmp /private/var/tmp)
fi
O=$(tmpf)
tmo 14400 sudo -u "$U" -H "$C" -r -i --max-filesize=100M --max-scansize=400M "${EX[@]}" "${TG[@]}" > "$O" 2>/dev/null
cat "$O"
grep " FOUND$" "$O" | while IFS= read -r l; do flag "ClamAV detection: $l"; done
grep -q " FOUND$" "$O" || echo "No ClamAV detections."
rm -f "$O"
