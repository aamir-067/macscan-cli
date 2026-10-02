# Full Disk Access detection: tries several protected folders, since paths change between macOS versions
FDA=no; FDA_DETAIL=""
for p in "$UH/Library/Safari" "$UH/Library/Mail" "$UH/Library/Messages" "$UH/Library/Application Support/com.apple.TCC"; do
  [ -e "$p" ] || continue
  if ls "$p" >/dev/null 2>&1; then FDA=yes; FDA_DETAIL="$FDA_DETAIL $(basename "$p"):readable"; else FDA_DETAIL="$FDA_DETAIL $(basename "$p"):blocked"; fi
done
FDA_DETAIL="${FDA_DETAIL# } | started by: $(ps -o comm= -p $PPID)"
