#!/bin/bash
# @title  Running processes
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Process tree"
ps -axo pid=,ppid=,user=,etime=,command= | perl -e '
  while(<STDIN>){ my($p,$pp,$u,$e,$c)=/^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(.*)$/ or next; $cmd{$p}="$u [$e] ".substr($c,0,170); push @{$k{$pp}},$p; }
  sub walk { my($p,$d)=@_; for my $c (sort {$a<=>$b} @{$k{$p}||[]}) { next if $c==$p; print "  " x $d, "$c $cmd{$c}\n"; walk($c,$d+1) if $d<15; } }
  walk(0,0);' | head -1200

section "Signatures of all non-Apple running executables"
ps -axo comm= | sort -u | while IFS= read -r p; do is_system_path "$p" && continue; [ -e "$p" ] && sigf "$p"; done

section "Processes running from unusual locations"
ps -axo pid=,user=,comm= | while read -r pid _ path; do
  case "$path" in
    "$ROOT"/*) ;;
    "$UH"/.nvm/*|"$UH"/.bun/*|"$UH"/.cargo/*|"$UH"/.rustup/*|"$UH"/.orbstack/*|"$UH"/.antigravity*|"$UH"/.vscode/*|"$UH"/.cursor/*|"$UH"/.local/*|"$UH"/.opencode/*|"$UH"/.npm/*) echo "dev path: pid $pid $path";;
    /tmp/*|/private/tmp/*|/private/var/folders/*|/Users/Shared/*|/var/tmp/*|/private/var/tmp/*) echo "TEMP: pid $pid $path"; flag "Process running from a temp or shared folder: pid $pid $path";;
    "$UH"/.*) echo "HIDDEN: pid $pid $path"; flag "Process running from a hidden folder in home: pid $pid $path";;
    "$UH/Downloads/"*|"$UH/Desktop/"*|"$UH/Documents/"*) echo "user folder: pid $pid $path";;
  esac
done

section "Processes using deleted files or executables"
lsof +L1 2>/dev/null | grep -v "/private/var/db/diagnostics" | head -100

section "Processes with password, cookie or keychain files open"
T=$(tmpf)
lsof -n +c 0 2>/dev/null | grep -E "keychain-db|Login Data|Cookies|key4\.db|logins\.json|cookies\.sqlite|Web Data|Local State|wallet|Exodus|Electrum|com\.apple\.TCC" | awk '{n=$9; for(i=10;i<=NF;i++) n=n" "$i; print $1" | "$2" | "$3" | "n}' | sort -u > "$T"
cat "$T"
grep -vE "^(Google Chrome|Google Chrome Helper|firefox|Firefox|Brave Browser|Arc|Microsoft Edge|Safari|com\.apple|securityd|secd|trustd|tccd|Bitwarden|cfprefsd|mds|mds_stores|mdworker|mdworker_shared|loginwindow|accountsd|Electron|Code|Cursor|Slack|Discord|Spotify|Notion|Postman|Claude|Antigravity|Zed|WhatsApp|Telegram|Raycast|Blip|Google Drive|Google Docs|Google Sheets|Google Slides|OpenCode|Anki)" "$T" | while read -r l; do flag "Unexpected process has a sensitive file open: $l"; done
rm -f "$T"

section "DYLD injection in running processes"
ps -Eaxww -o pid=,command= 2>/dev/null | perl -ne 'print "$1 $2\n" if /^\s*(\d+).*?(DYLD_INSERT_LIBRARIES=\S+)/' | while read -r l; do echo "$l"; flag "Process started with DYLD_INSERT_LIBRARIES: $l"; done

section "Interpreters, scripts and downloaders running now"
ps -axo pid,ppid,user,etime,command | grep -iE "node|python|osascript|curl|wget|perl|ruby|deno|bun|php|java | sh -c| bash -c| zsh -c| nc |ncat|socat" | grep -vE "grep -iE|perl -e|perl -pe|mac-triage"
ps -axo pid=,command= | grep "osascript" | grep -vE "grep|mac-triage" | while read -r l; do flag "osascript is running: $(echo "$l" | cut -c1-200)"; done
ps -axo pid=,command= | grep -E "\-\-load-extension|\-\-remote-debugging-port" | grep -v grep | while read -r l; do flag "Browser with extension loading or remote debugging flag: $(echo "$l" | cut -c1-200)"; done
