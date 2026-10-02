#!/bin/bash
# @title  Code repositories (injected code, auto-run tasks, hooks)
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Known injected JavaScript markers"
grep -rlF --exclude-dir=Library --exclude-dir=.Trash --exclude-dir=.git --exclude-dir=.orbstack --exclude-dir=.npm --exclude-dir=.cache --exclude-dir=.rustup --exclude-dir="$(basename "$OUTBASE")" --include="*.js" --include="*.cjs" --include="*.mjs" --include="*.ts" --include="*.jsx" --include="*.tsx" -e '_$_5ef4' -e '_$jsoIter' -e 'global[_$_' "$UH" 2>/dev/null | while IFS= read -r f; do echo "$f"; flag "Injected malware marker found: $f"; done

section "Config files with abnormally long lines"
find "$UH" "${PRUNE[@]}" -type f \( -name "*.config.js" -o -name "*.config.mjs" -o -name "*.config.cjs" -o -name "*.config.ts" -o -name ".eslintrc.js" \) -print 2>/dev/null | while IFS= read -r f; do
  awk 'length > 1000 {print FILENAME; exit}' "$f"
done | while IFS= read -r f; do echo "$f"; flag "Config file with an abnormally long line: $f"; done

section "Obfuscation patterns in project source (review, may include false positives)"
PAT='global\[[_$!]|String\.fromCharCode\(127\)|\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}|eval\(Buffer\.from\(|child_process.{0,40}(curl|wget)'
grep -rlE --exclude-dir=node_modules --exclude-dir=Library --exclude-dir=.git --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=.Trash --exclude-dir=.orbstack --include="*.js" --include="*.cjs" --include="*.mjs" --include="*.ts" -e "$PAT" "$UH" 2>/dev/null | head -150

section "package.json install scripts (run automatically on npm/bun install)"
find "$UH" "${PRUNE[@]}" -name package.json -print 2>/dev/null | while IFS= read -r p; do
  perl -MJSON::PP -e 'local $/; my $j=eval{decode_json(<STDIN>)} or exit; my $s=$j->{scripts}; exit unless ref $s eq "HASH"; for (qw(preinstall install postinstall prepare)) { print "$ARGV[0] | $_: $s->{$_}\n" if exists $s->{$_} }' "$p" < "$p"
done | head -250

section "Editor tasks that run automatically when a folder opens"
find "$UH" "${PRUNE[@]}" -path "*/.vscode/tasks.json" -print 2>/dev/null | while IFS= read -r t; do
  grep -q "folderOpen" "$t" && { echo "$t"; grep -n -B3 -A3 "folderOpen" "$t"; flag "Task auto-runs on folder open: $t"; }
done

section "Active git hooks in repositories"
find "$UH" "${PRUNE_KEEPGIT[@]}" -type d -path "*/.git/hooks" -print 2>/dev/null | while IFS= read -r h; do
  for f in "$h"/*; do [ -f "$f" ] || continue; case "$f" in *.sample) continue;; esac; echo "$f"; done
done | head -150

section "Repository git configs that can execute commands"
find "$UH" "${PRUNE_KEEPGIT[@]}" -path "*/.git/config" -print 2>/dev/null | while IFS= read -r c; do
  grep -HiE "fsmonitor|hooksPath|sshCommand|pager|textconv|external|askpass" "$c" | while read -r l; do echo "$l"; flag "Repo git config can execute commands: $l"; done
done
