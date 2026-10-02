#!/bin/bash
# @title  Programs started during the scan (eslogger, opt-in)
# @quick  skip
# @toggle EXEC_MONITOR
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"

section "Programs started during the scan (excluding the scan itself)"
T="$MT_TMP/exec.tsv"
if [ ! -s "$T" ]; then
  echo "No exec events were captured. eslogger needs root and Full Disk Access."
  [ -s "$MT_TMP/eslogger.err" ] && head -5 "$MT_TMP/eslogger.err"
  exit 0
fi
echo "Count | program | signing id | team | Apple platform binary"
sort "$T" | uniq -c | sort -rn | head -300 | awk '{c=$1; $1=""; sub(/^ /,""); print c " | " $0}' | tr '\t' '|' | sed 's/|/ | /g'

sort -u "$T" | while IFS="$(printf '\t')" read -r path sid team plat; do
  [ "$plat" = 1 ] && continue
  [ "$sid" = - ] && sid=""; [ "$team" = - ] && team=""
  is_self "$path" && continue
  case "$(canon_path "$path")" in
    /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*|/Users/Shared/*|"$UH"/.*|"$UH/Downloads/"*)
      is_dev_path "$path" && continue
      flag "Program started during the scan from an unusual location: $path (signing id ${sid:-none}, team ${team:-none})";;
    *)
      if [ -z "$team" ] && ! is_dev_path "$path" && ! is_system_path "$path"; then
        flag "Unsigned program started during the scan: $path (signing id ${sid:-none})"
      fi;;
  esac
done
