#!/bin/bash
# @title  File system sweep
# @quick  skip
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
PL=( \( -path "$UH/Library/CloudStorage" -o -path "$UH/Library/Caches" -o -path "$UH/Library/Containers" -o -path "$UH/Library/Group Containers" -o -path "$UH/Library/Developer" -o -path /Library/Caches -o -path /Library/Developer -o -path "$UH/.orbstack" -o -path "$TRASHP" -o -path "$OUTBASE" -o -name node_modules -o -name .git -o -path "$UH/.npm" -o -path "$UH/.cache" -o -path "$UH/.rustup" -o -path "$UH/.cargo" -o -path "$UH/.nvm" -o -path "$UH/.bun" -o -path "$UH/.gradle" -o -path "$UH/go" -o -name "*.app" -o -name DerivedData -o -name .next \) -prune -o )

section "Hidden files and folders in home"
ls -laT "$UH" | grep -E ' \.[^. ]'
for n in .helper .agent .pass .username; do [ -e "$UH/$n" ] && flag "File name used by known Mac stealers present: $UH/$n"; done

section "Recently created items in key Library folders"
for d in "$AS" "/Library/Application Support" "$UH/Library/Containers" "$UH/Library/Group Containers" "$UH/Library" /Library /Users/Shared /private/var/root; do
  echo "[$d]"
  find "$d" -maxdepth 1 -mindepth 1 -Btime -"$DAYS" 2>/dev/null | while IFS= read -r x; do echo "$(stat -f '%SB' "$x") $x"; done | sort
done

section "Recently created Mach-O binaries outside apps and dev folders"
find "$UH" /Users/Shared /Library /usr/local /private/tmp /private/var/tmp /private/var/root "${PL[@]}" -type f -Btime -"$DAYS" -perm -u+x -print 2>/dev/null | grep -vE "/target/(debug|release)/|/build/|/dist/" | head -2000 | while IFS= read -r f; do
  t=$(file -b "$f" 2>/dev/null)
  case "$t" in *Mach-O*) echo "$(stat -f '%SB' "$f") | $t"; sigf "$f";; esac
done | head -400

section "Recently created scripts, plists and libraries outside dev folders"
find "$UH" /Users/Shared /Library /private/tmp /private/var/tmp "${PL[@]}" -type f -Btime -"$DAYS" \( -name "*.sh" -o -name "*.command" -o -name "*.py" -o -name "*.scpt" -o -name "*.applescript" -o -name "*.plist" -o -name "*.dylib" -o -name "*.js" \) -print 2>/dev/null \
  | grep -vE "/Library/Preferences/|/Library/Saved Application State/|/Library/HTTPStorages/|/Library/WebKit/|/Library/Application Support/(Google|Code|Cursor|Slack|Microsoft|Zed|Antigravity|Firefox|BraveSoftware|Arc|Claude|Postman)|/Documents/projects/|/\.local/share/nvim/" | head -400

section "Temp folders and archives (possible data staging before upload)"
ls -laT /private/tmp/ /private/var/tmp/ /Users/Shared/ 2>/dev/null
find /private/var/folders -maxdepth 4 -type f \( -name "*.zip" -o -name "*.tar*" -o -name "*.7z" \) -Btime -"$DAYS" 2>/dev/null | head -60
find /private/tmp /private/var/tmp /Users/Shared "$UH" -maxdepth 2 -type f \( -name "*.zip" -o -name "*.tar.gz" -o -name "*.7z" \) -Btime -"$DAYS" 2>/dev/null | grep -vF "$OUTBASE/" | head -60

section "SUID and SGID files outside system paths"
find /Users /Library /usr/local /opt /private/tmp /private/var/tmp /Applications -path "$UH/Library/CloudStorage" -prune -o \( -perm -4000 -o -perm -2000 \) -type f -print 2>/dev/null | while IFS= read -r f; do echo "$f"; flag "SUID/SGID file outside system paths: $f"; done
