#!/bin/bash
# @title  Code repositories (injected code, auto-run tasks, hooks)
# shellcheck source=../core/common.sh
source "$(dirname "$0")/../core/common.sh"
section "Known injected JavaScript markers"
grep -rlF --exclude-dir=Library --exclude-dir=.Trash --exclude-dir=.git --exclude-dir=.orbstack --exclude-dir=.npm --exclude-dir=.cache --exclude-dir=.rustup --exclude-dir="$(basename "$OUTBASE")" --include="*.js" --include="*.py" --include="*.cjs" --include="*.mjs" --include="*.ts" --include="*.jsx" --include="*.tsx" -e '_$_5ef4' -e '_$jsoIter' -e 'global[_$_' -e '_$_1e42' -e 'rmcej%otb%' -e 'Cot%3t=shtP' -e "global['_V']" -e "global['!']" -e 'lzcdrtfxyqiplpd' "$UH" 2>/dev/null | while IFS= read -r f; do echo "$f"; flag "Injected malware marker found: $f"; done

section "Config files with abnormally long lines"
find "$UH" "${PRUNE[@]}" -type f \( -name "*.config.js" -o -name "*.config.mjs" -o -name "*.config.cjs" -o -name "*.config.ts" -o -name ".eslintrc.js" \) -print 2>/dev/null | while IFS= read -r f; do
  awk 'length > 1000 {print FILENAME; exit}' "$f"
done | while IFS= read -r f; do echo "$f"; flag "Config file with an abnormally long line: $f"; done

section "Obfuscation patterns in project source (review, may include false positives)"
PAT='global\[[_$!]|String\.fromCharCode\(127\)|\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}|eval\(Buffer\.from\(|child_process.{0,40}(curl|wget)'
grep -rlE --exclude-dir=node_modules --exclude-dir=Library --exclude-dir=.git --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=.Trash --exclude-dir=.orbstack --include="*.js" --include="*.cjs" --include="*.mjs" --include="*.ts" -e "$PAT" "$UH" 2>/dev/null | head -150

section "package.json install scripts (run automatically on npm/bun install)"
find "$UH" "${PRUNE[@]}" -type f -name package.json -print 2>/dev/null | while IFS= read -r p; do
  # shellcheck disable=SC2094  # the path is only passed as a name; the file is read once
  perl -MJSON::PP -e 'local $/; my $j=eval{decode_json(<STDIN>)} or exit; my $s=$j->{scripts}; exit unless ref $s eq "HASH"; for (qw(preinstall install postinstall prepare)) { print "$ARGV[0] | $_: $s->{$_}\n" if exists $s->{$_} }' "$p" < "$p"
done | head -250

section "Editor tasks that run automatically when a folder opens"
# PolinRider/TasksJacker (DPRK, 2026) hide a task that runs `node <fake font>` or a
# downloaded script whenever the folder is opened in VS Code, Cursor and similar editors.
find "$UH" "${PRUNE[@]}" -type f -path "*/.vscode/tasks.json" -print 2>/dev/null | while IFS= read -r t; do
  rd "$t" | grep -q "folderOpen" || continue
  echo "$t"; rd "$t" | grep -n -B3 -A3 "folderOpen"
  if rd "$t" | grep -qE '"command"[^"]*"[^"]*(\.woff2?|\.ttf|\bnode |curl |wget |\| *(ba|z)?sh|powershell|bash -c)'; then
    flag "Auto-run task runs code on folder open: $t"
  else
    flag "Task auto-runs on folder open: $t"
  fi
done

section "Projects that turn on automatic tasks without asking"
find "$UH" "${PRUNE[@]}" -type f -path "*/.vscode/settings.json" -print 2>/dev/null | while IFS= read -r f; do
  rd "$f" | grep -qE '"task\.allowAutomaticTasks"[[:space:]]*:[[:space:]]*(true|"on")' && { echo "$f"; flag "Project turns on automatic tasks without asking: $f"; }
done

section "Font files that are really programs"
echo "A real .woff file starts with wOFF and a real .woff2 with wOF2; anything else is suspicious (only 4 bytes are read)."
find "$UH" "${PRUNE[@]}" -type f \( -name "*.woff" -o -name "*.woff2" \) -size -5000k -print 2>/dev/null | head -5000 | while IFS= read -r f; do
  m=$(rd "$f" 2>/dev/null | head -c 4 | LC_ALL=C tr -cd '[:alnum:]')
  case "$m" in wOFF|wOF2) ;; *) echo "$f (starts with: ${m:-?})"; flag "Font file is really a program (fake font): $f";; esac
done

section "Active git hooks in repositories"
# Every hook is checked; only the first 150 are listed.
find "$UH" "${PRUNE_KEEPGIT[@]}" -type d -path "*/.git/hooks" -print 2>/dev/null | while IFS= read -r h; do
  for f in "$h"/*; do [ -f "$f" ] || continue; case "$f" in *.sample) continue;; esac; echo "$f"; done
done | { n=0; while IFS= read -r f; do
  n=$((n + 1)); [ "$n" -le 150 ] && echo "$f"
  hook_runs_hidden_code "$f" && flag "Git hook downloads or runs hidden code: $f"
done; }

section "Repository git configs that can execute commands"
find "$UH" "${PRUNE_KEEPGIT[@]}" -type f -path "*/.git/config" -print 2>/dev/null | while IFS= read -r c; do
  rd "$c" | grep -iE "fsmonitor|hooksPath|sshCommand|pager|textconv|external|askpass" | sed "s|^|$c:|" | while read -r l; do echo "$l"; flag "Repo git config can execute commands: $l"; done
done
