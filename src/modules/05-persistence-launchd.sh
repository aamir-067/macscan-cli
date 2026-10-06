#!/bin/bash
# @title  Persistence: launchd items and Background Task Management
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "launchd items: what they run and who signed it"
# A home folder outside /Users (rare, and the test fixtures) is covered too.
case "$UH" in /Users/*) HLA="";; *) HLA="$UH/Library/LaunchAgents";; esac
for d in /Library/LaunchAgents /Library/LaunchDaemons /Users/*/Library/LaunchAgents /var/root/Library/LaunchAgents /Library/StartupItems ${HLA:+"$HLA"}; do
  [ -d "$d" ] || continue
  sub "$d"; ls -laT "$d"
  for f in "$d"/* "$d"/.*; do
    [ -f "$f" ] || continue
    bn=$(basename "$f"); case "$bn" in .DS_Store|.localized) continue;; esac
    echo; echo "[item] $f"
    if is_self "$f"; then echo "  (mac-triage service)"; continue; fi
    echo "  created: $(stat -f '%SB' "$f")  modified: $(stat -f '%Sm' "$f")"
    case "$bn" in .*) flag "Hidden launch item file: $f";; esac
    prog=$(plutil -extract Program raw -o - "$f" 2>/dev/null)
    args=$(plutil -extract ProgramArguments json -o - "$f" 2>/dev/null)
    label=$(plutil -extract Label raw -o - "$f" 2>/dev/null)
    echo "  Label: $label"
    # AMOS backdoor (Moonlock 2025-07, Trend Micro 2025-09) runs ~/.agent from this daemon.
    case "$label|$bn" in com.finder.helper\|*|*\|com.finder.helper.plist) flag "Launch item name used by known Mac stealers: $f";; esac
    echo "  Program: ${prog:-none}"; echo "  Args: ${args:-none}"
    plutil -p "$f" 2>/dev/null | grep -iE "RunAtLoad|KeepAlive|StartInterval|StartCalendarInterval|WatchPaths|QueueDirectories|DYLD|EnvironmentVariables" | sed 's/^/  /'
    plutil -p "$f" 2>/dev/null | grep -q "DYLD_" && flag "DYLD variable in launch item: $f"
    tgt="$prog"
    [ -z "$tgt" ] && tgt=$(echo "$args" | perl -MJSON::PP -e 'local $/; my $x=eval{decode_json(<STDIN>)}; print $x->[0] if ref $x eq "ARRAY"')
    inv launch "$f | ${tgt:-?} | $(sha "$f")"
    if [ -n "$tgt" ]; then
      if [ -e "$tgt" ]; then printf "  target: "; sigf "$tgt"; else echo "  target missing: $tgt"; fi
      case "$(canon_path "$tgt")" in */tmp/*|/Users/Shared/*|/private/var/folders/*|/var/folders/*|"$UH"/.*) flag "Launch item runs from an unusual location: $f -> $tgt";; esac
      case "$tgt" in */osascript|*/bash|*/sh|*/zsh|*/python*|*/node|*/perl|*/curl|*/ruby|*/deno|*/bun) flag "Launch item runs an interpreter directly: $f -> $args";; esac
      # SHub Reaper (SentinelOne, 2026) registers com.google.keystone.agent for a bash script in
      # ~/Library/Application Support/Google/GoogleUpdate.app. Real Google, Apple and Microsoft
      # agents run signed programs, never an interpreter or a script.
      case "$label" in com.google.*|com.apple.*|com.microsoft.*)
        case "$tgt" in
          */osascript|*/bash|*/sh|*/zsh|*/python*|*/node|*/perl|*/ruby) flag "Launch item uses a vendor name but runs a script: $f -> $tgt";;
          *) [ -f "$tgt" ] && ! file -b "$tgt" 2>/dev/null | grep -q "Mach-O" && flag "Launch item uses a vendor name but runs a script: $f -> $tgt";;
        esac;;
      esac
    fi
    [ -n "$(find "$f" -Btime -"$DAYS" 2>/dev/null)" ] && flag "Launch item created in the last $DAYS days: $f"
  done
done

section "Loaded launchd jobs (non-Apple)"
sub "System domain"
launchctl list | awk 'NR>1 && $3 !~ /^com\.apple\./' | while read -r pid st label; do echo "$pid $st $label"; case "$label" in application.*|com.mactriage.*) ;; *) inv jobs "system $label";; esac; done
sub "User domain"
asuser launchctl list | awk 'NR>1 && $3 !~ /^com\.apple\./' | while read -r pid st label; do echo "$pid $st $label"; case "$label" in application.*) ;; *) inv jobs "user $label";; esac; done
sub "Disabled service overrides (non-Apple)"
launchctl print-disabled system 2>/dev/null | grep -v com.apple | head -60
launchctl print-disabled "gui/$UID_N" 2>/dev/null | grep -v com.apple | head -60
sub "launchd environment"
for v in DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH DYLD_FRAMEWORK_PATH; do
  s=$(launchctl getenv "$v"); u=$(asuser launchctl getenv "$v")
  echo "$v system='$s' user='$u'"
  [ -n "$s$u" ] && flag "launchd has $v set: $s $u"
done

section "Background Task Management database (all login and background items)"
sfltool dumpbtm 2>/dev/null | grep -E "^ #|Name:|Developer Name:|Team Identifier:|Type:|Disposition:|Identifier:|URL:|Executable Path:|Last Use:|Parent Identifier:"
sfltool dumpbtm 2>/dev/null | awk '$1=="Identifier:" {print $2}' | sort -u | grep -v "com.mactriage" | while read -r id; do inv btm "$id"; done
