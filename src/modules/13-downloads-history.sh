#!/bin/bash
# @title  Download history and file origins
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
QDB="$UH/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
CUT="CAST(strftime('%s','now','-$DAYS days') AS INTEGER)"
section "Download history (quarantine database, last $DAYS days)"
sql -separator ' | ' "$QDB" "select datetime(LSQuarantineTimeStamp+978307200,'unixepoch','localtime'), LSQuarantineAgentName, LSQuarantineDataURLString, LSQuarantineOriginURLString from LSQuarantineEvent where LSQuarantineTimeStamp+978307200 > $CUT order by LSQuarantineTimeStamp" 2>&1 | head -600
section "Installers and downloads from social or file-sharing links"
sql -separator ' | ' "$QDB" "select d, a, u from (select datetime(LSQuarantineTimeStamp+978307200,'unixepoch','localtime') d, LSQuarantineAgentName a, coalesce(LSQuarantineDataURLString,'')||' <- '||coalesce(LSQuarantineOriginURLString,'') u, LSQuarantineTimeStamp ts from LSQuarantineEvent) where ts+978307200 > $CUT and (u LIKE '%t.co/%' or u LIKE '%x.com/%' or u LIKE '%twitter.com%' or u LIKE '%mediafire%' or u LIKE '%mega.nz%' or u LIKE '%dropbox%' or u LIKE '%drive.google%' or u LIKE '%pages.dev%' or u LIKE '%vercel.app%' or u LIKE '%netlify.app%' or u LIKE '%github.io%' or u LIKE '%.dmg%' or u LIKE '%.pkg%')" 2>/dev/null | while read -r l; do echo "$l"; flag "Installer or social/file-share download (verify): $l"; done
section "Files on disk with a download origin (last $DAYS days)"
L=$(tmpf)
mdfind -onlyin "$UH" "kMDItemWhereFroms == '*' && kMDItemFSCreationDate >= \$time.today(-$DAYS)" 2>/dev/null | grep -v "/Library/CloudStorage/" | head -2000 > "$L"
head -300 "$L" | while IFS= read -r f; do
  echo "$f | $(mdls -raw -name kMDItemWhereFroms "$f" 2>/dev/null | tr -d '\n' | tr -s ' ')"
done

section "Programs, installers and archives by origin (last $DAYS days)"
echo "Flags downloads from chat attachments, link shorteners, file shares, GitHub releases and free hosting."
while IFS= read -r f; do
  exec_like "$f" || continue
  # shellcheck disable=SC2046  # one argument per URL is intended
  origin_check "$f" $(mdls -raw -name kMDItemWhereFroms "$f" 2>/dev/null | grep -oE 'https?://[^"[:space:],)]+')
done < "$L"
rm -f "$L"
section "Downloads folder (newest first)"; ls -lTt "$UH/Downloads" | head -80
section "Trash (newest first)"; ls -lTt "$UH/.Trash" 2>/dev/null | head -80
