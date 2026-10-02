#!/bin/bash
# mac-triage report delivery. Runs as the target user, never as root.
#
# The engine builds each report in a root-only staging folder and streams it
# here as a tar archive. Writing into the user's report folder with the user's
# own rights means a symlink planted there can only redirect writes to places
# the user could already write, never to system files.
#
# Usage (stdin is a tar stream for "receive"):
#   deliver.sh receive <report dir> <report name> <zip yes|no>
#   deliver.sh clean   <report dir> <keep N> <max age days>
export PATH="/usr/bin:/bin:/usr/sbin:/sbin" LC_ALL=C
umask 077
[ "$EUID" -ne 0 ] || { echo "deliver.sh must not run as root" >&2; exit 1; }

valid_name(){
  case "$1" in */*|*..*|"") return 1;; esac
  case "$1" in scan_[0-9]*) return 0;; esac
  return 1
}

check_dir(){
  case "$1" in /*) ;; *) echo "The report folder must be a full path: $1" >&2; return 2;; esac
  if [ -L "$1" ]; then echo "The report folder is a symlink. Refusing to write there: $1" >&2; return 4; fi
  return 0
}

receive(){
  local out="$1" name="$2" zip="$3"
  check_dir "$out" || return
  valid_name "$name" || { echo "Invalid report name: $name" >&2; return 2; }
  mkdir -p "$out" || return 1
  if [ -e "$out/$name" ] || [ -L "$out/$name" ]; then echo "Already exists: $out/$name" >&2; return 1; fi
  tar -xf - -C "$out" "$name" || return 1
  [ -d "$out/$name" ] && [ ! -L "$out/$name" ] || return 1
  if [ "$zip" = yes ]; then
    rm -f "$out/$name.zip"
    (cd "$out" && ditto -c -k --keepParent "$name" "$name.zip") || echo "Could not create $out/$name.zip" >&2
  fi
  return 0
}

# Retention: drop reports older than <max age> days (always keeping the newest),
# then keep only the newest <keep>; remove zips whose folder is gone.
clean(){
  local out="$1" keep="$2" age="$3" all newest n d z
  case "$keep$age" in *[!0-9]*|"") echo "clean needs numbers" >&2; return 2;; esac
  [ "$keep" -ge 1 ] || keep=1
  check_dir "$out" || return
  [ -d "$out" ] || return 0
  all=$(find "$out" -maxdepth 1 -type d -name 'scan_*' | sort)
  newest=$(echo "$all" | tail -1)
  echo "$all" | while IFS= read -r d; do
    if [ -n "$d" ] && [ "$d" != "$newest" ] && [ -n "$(find "$d" -maxdepth 0 -mtime +"$age")" ]; then rm -rf "$d" "$d.zip"; fi
  done
  all=$(find "$out" -maxdepth 1 -type d -name 'scan_*' | sort); n=$(echo "$all" | grep -c . || true)
  if [ "$n" -gt "$keep" ]; then echo "$all" | head -n $((n-keep)) | while IFS= read -r d; do rm -rf "$d" "$d.zip"; done; fi
  for z in "$out"/scan_*.zip; do if [ -f "$z" ] && [ ! -d "${z%.zip}" ]; then rm -f "$z"; fi; done
  return 0
}

case "${1:-}" in
  receive) [ $# -eq 4 ] || exit 2; receive "$2" "$3" "$4";;
  clean) [ $# -eq 4 ] || exit 2; clean "$2" "$3" "$4";;
  *) echo "Usage: deliver.sh receive DIR NAME ZIP | clean DIR KEEP MAX_AGE" >&2; exit 2;;
esac
