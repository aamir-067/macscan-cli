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
  case "$(canon_path "$path")" in
    "$ROOT"/*) ;;
    "$UH"/.nvm/*|"$UH"/.bun/*|"$UH"/.cargo/*|"$UH"/.rustup/*|"$UH"/.orbstack/*|"$UH"/.antigravity*|"$UH"/.vscode/*|"$UH"/.cursor/*|"$UH"/.local/*|"$UH"/.opencode/*|"$UH"/.npm/*) echo "dev path: pid $pid $path";;
    /tmp/*|/private/tmp/*|/private/var/folders/*|/var/folders/*|/Users/Shared/*|/var/tmp/*|/private/var/tmp/*) echo "TEMP: pid $pid $path"; flag "Process running from a temp or shared folder: pid $pid $path";;
    "$UH"/.*) echo "HIDDEN: pid $pid $path"; flag "Process running from a hidden folder in home: pid $pid $path";;
    "$UH/Downloads/"*|"$UH/Desktop/"*|"$UH/Documents/"*) echo "user folder: pid $pid $path";;
  esac
done

section "Processes using deleted files or executables"
lsof +L1 2>/dev/null | grep -v "/private/var/db/diagnostics" | head -100

section "Processes with password, cookie or keychain files open"
echo "Trusted only when the program is Apple's (sealed system folder) or a validly signed app in /Applications; a process name alone is never trusted."
T=$(tmpf)
# lsof writes spaces in command names as \x20; decode them for readability.
lsof -n +c 0 2>/dev/null | grep -E "keychain-db|Login Data|Cookies|key4\.db|logins\.json|cookies\.sqlite|Web Data|Local State|wallet|Exodus|Electrum|com\.apple\.TCC" \
  | awk '{n=$9; for(i=10;i<=NF;i++) n=n" "$i; print $2"\t"$1" | "$2" | "$3" | "n}' | sed 's/\\x20/ /g' | sort -u > "$T"
cut -f2- "$T"
cut -f1 "$T" | sort -u | while read -r pid; do
  exe=$(ps -o comm= -p "$pid" 2>/dev/null)
  if trusted_program "$exe"; then continue; fi
  grep "^$pid	" "$T" | cut -f2- | while IFS= read -r l; do flag "Unexpected process has a sensitive file open: $l (program: ${exe:-exited})"; done
done
rm -f "$T"

section "DYLD injection in running processes"
ps -Eaxww -o pid=,command= 2>/dev/null | perl -ne 'print "$1 $2\n" if /^\s*(\d+).*?(DYLD_INSERT_LIBRARIES=\S+)/' | while read -r l; do echo "$l"; flag "Process started with DYLD_INSERT_LIBRARIES: $l"; done

section "Interpreters, scripts and downloaders running now"
ps -axo pid,ppid,user,etime,command | grep -iE "node|python|osascript|curl|wget|perl|ruby|deno|bun|php|java | sh -c| bash -c| zsh -c| nc |ncat|socat" | grep -vE "grep -iE|perl -e|perl -pe|mac-triage"
ps -axo pid=,command= | grep "osascript" | grep -vE "grep|mac-triage" | while read -r l; do flag "osascript is running: $(echo "$l" | cut -c1-200)"; done
ps -axo pid=,command= | grep -E "\-\-load-extension|\-\-remote-debugging-port" | grep -v grep | while read -r l; do flag "Browser with extension loading or remote debugging flag: $(echo "$l" | cut -c1-200)"; done
