#!/bin/bash
# @title  Installed applications and packages
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Installed applications (signature, notarization, install date)"
find /Applications "$UH/Applications" -maxdepth 3 -name "*.app" -not -path "*.app/*" 2>/dev/null | sort | while IFS= read -r a; do
  gk=$(spctl -a -vv "$a" 2>&1); src=$(echo "$gk" | awk -F= '/source=/{print $2}')
  if echo "$gk" | grep -q "accepted"; then acc="accepted"; else acc="REJECTED"; fi
  line="$(sig "$a")"
  echo "$line | gatekeeper=$acc $src | created=$(stat -f '%SB' "$a")"
  inv apps "$a | $(echo "$line" | grep -o 'team=[^ |]*')"
  [ "$acc" = "REJECTED" ] && flag "App rejected by Gatekeeper (unsigned or not notarized): $a"
done
section "Apps, installers and archives outside /Applications"
find "$UH" /Users/Shared /private/tmp /private/var/tmp -maxdepth 4 "${PRUNE[@]}" \( -name "*.app" -print -prune \) 2>/dev/null | head -100
find "$UH/Downloads" "$UH/Desktop" "$UH/.Trash" /Users/Shared -maxdepth 3 \( -name "*.dmg" -o -name "*.pkg" -o -name "*.app" -o -name "*.zip" \) -Btime -"$DAYS" 2>/dev/null | head -100
sub "Mounted disk images"; hdiutil info 2>/dev/null | grep -E "image-path|/Volumes/"
section "Installer packages (non-Apple)"
pkgutil --pkgs | grep -v com.apple | while read -r p; do
  t=$(pkgutil --pkg-info "$p" 2>/dev/null | awk -F': ' '/install-time/{print $2}')
  echo "$p | installed $( [ -n "$t" ] && date -r "$t" '+%Y-%m-%d %H:%M')"; inv pkgs "$p"
done
section "Install history"; system_profiler SPInstallHistoryDataType 2>/dev/null | tail -400
section "Homebrew casks and taps"
ls -1 /opt/homebrew/Caskroom 2>/dev/null | while read -r c; do echo "cask: $c"; inv casks "$c"; done
ls -1 /opt/homebrew/Library/Taps 2>/dev/null | while read -r t; do echo "tap owner: $t"; inv taps "$t"; [ "$t" = homebrew ] || flag "Third-party Homebrew tap (verify): $t"; done
section "Applications used in the last $DAYS days"
mdfind "kMDItemContentTypeTree == 'com.apple.application' && kMDItemLastUsedDate >= \$time.today(-$DAYS)" 2>/dev/null | head -200
