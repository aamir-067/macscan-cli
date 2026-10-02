# shellcheck shell=bash
# Install integrity. The installer writes manifest.sha256 (root-owned) listing every
# shipped file. Each scan checks the hashes, looks for files that should not be there,
# and checks ownership and permissions of the install folder and the LaunchDaemons.
#
# Limits, stated honestly: something that already runs as root could rewrite the
# manifest too. This catches tampering by anything less privileged, and mistakes.

# Files that legitimately change after install and are not in the manifest.
integrity_files(){
  (cd "$1" && find . -type f ! -path './state/*' ! -name config ! -name manifest.sha256 \
    ! -path ./rules/all.yarc ! -path ./rules/sets.txt ! -path './rules/*.new' | sed 's#^\./##' | LC_ALL=C sort)
}

# integrity_manifest <root>: prints the manifest (used by the installer).
integrity_manifest(){
  local f
  integrity_files "$1" | while IFS= read -r f; do (cd "$1" && shasum -a 256 "$f"); done
}

# integrity_check <expected owner> <LaunchDaemons folder>: raises flags, returns 1 on problems.
integrity_check(){
  local owner="$1" ld="$2" m="$ROOT/manifest.sha256" f p n=0 prog
  if [ ! -f "$m" ]; then
    flag "Install integrity check failed: manifest.sha256 is missing (reinstall to create it)"; return 1
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue; n=$((n+1)); flag "Install integrity check failed: $f changed since install"
  done < <(cd "$ROOT" && shasum -a 256 -c "$m" 2>/dev/null | grep -v ': OK$' | sed -E 's/: FAILED.*$//')
  while IFS= read -r f; do
    awk -v f="$f" 'substr($0, 67) == f {found=1} END {exit !found}' "$m" && continue
    n=$((n+1)); flag "Unexpected file in install folder: $ROOT/$f"
  done < <(integrity_files "$ROOT")
  while IFS= read -r p; do
    n=$((n+1)); flag "Install file not owned by root or writable by others: $p"
  done < <(find "$ROOT" -path "$ROOT/state" -prune -o \( ! -user "$owner" -o -perm -g+w -o -perm -o+w \) -print 2>/dev/null)
  for p in "$ld/com.mactriage.runner.plist" "$ld/com.mactriage.auto.plist"; do
    [ -f "$p" ] || continue
    prog=$(plutil -extract ProgramArguments.0 raw -o - "$p" 2>/dev/null)
    if [ -n "$(find "$p" \( ! -user "$owner" -o -perm -g+w -o -perm -o+w \) 2>/dev/null)" ]; then
      n=$((n+1)); flag "Service definition changed: $p is not owned by root or is writable by others"
    elif [ "$prog" != "$ROOT/bin/macscan-helper" ] && [ "$prog" != /bin/bash ]; then
      n=$((n+1)); flag "Service definition changed: $p runs $prog"
    fi
  done
  [ "$n" -eq 0 ]
}
