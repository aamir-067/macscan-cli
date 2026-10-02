#!/usr/bin/env bats
# Module metadata, structure rules and selection.

load ../helpers

setup(){
  # shellcheck source=/dev/null
  source "$SRC/core/lib/modules.sh"
  ONLY=""; SKIP=""; QUICK=0; DO_YARA=yes; DO_CLAM=yes; NO_LOGS=0
}

selected(){ local m out=""; for m in "$SRC"/modules/*.sh; do module_selected "$m" && out="$out $(basename "$m" | cut -c1-2)"; done; echo "${out# }"; }

@test "every module has a title and loads common.sh relative to itself" {
  for m in "$SRC"/modules/*.sh; do
    [ -n "$(module_meta "$m" title)" ] || { echo "no @title: $m"; return 1; }
    grep -qx 'source "$(dirname "$0")/../core/common.sh"' "$m" || { echo "bad source line: $m"; return 1; }
  done
}

@test "module file names are NN-name.sh with unique numbers" {
  dupes=$(for m in "$SRC"/modules/*.sh; do basename "$m" | cut -c1-2; done | sort | uniq -d)
  [ -z "$dupes" ]
  for m in "$SRC"/modules/*.sh; do [[ "$(basename "$m")" =~ ^[0-9]{2}-[a-z0-9-]+\.sh$ ]] || return 1; done
}

@test "modules never write outside the run folder: no rm, mv, chmod, chown, kill or launchctl changes" {
  run bash -c 'grep -nE "$0" "$@" | grep -v -e ":[[:space:]]*grep " -e "| grep -"' '(^|[;&|[:space:]])(rm -rf? [^"]*"\$(UH|HOME)|mv |chmod |chown |kill |pkill |launchctl (load|unload|bootout|bootstrap|remove|kickstart)|defaults write|tccutil|xattr -[cdw])' "$SRC"/modules/*.sh
  [ "$status" -eq 1 ]
}

@test "module_meta reads header values" {
  [ "$(module_meta "$SRC/modules/19-yara.sh" toggle)" = YARA ]
  [ "$(module_meta "$SRC/modules/14-filesystem.sh" quick)" = skip ]
  [ -z "$(module_meta "$SRC/modules/01-system.sh" quick)" ]
}

@test "with opt-in features on, a full scan selects every module" {
  SUPPLY_CHAIN=yes; EXEC_MONITOR=yes
  [ "$(selected | wc -w | tr -d ' ')" = "$(ls "$SRC"/modules/*.sh | wc -l | tr -d ' ')" ]
}

@test "--quick leaves out the slow modules" {
  QUICK=1
  for n in 14 18 19 20; do [[ " $(selected) " != *" $n "* ]] || return 1; done
  [[ " $(selected) " == *" 01 "* ]] || return 1
}

@test "--only and --skip pick modules by number" {
  ONLY="05,15"; [ "$(selected)" = "05 15" ]
  ONLY=""; SKIP="19,20"; [[ " $(selected) " != *" 19 "* && " $(selected) " != *" 20 "* ]] || return 1
}

@test "--no-yara, --no-clamav and --no-logs drop their modules" {
  DO_YARA=no; DO_CLAM=no; NO_LOGS=1
  for n in 18 19 20; do [[ " $(selected) " != *" $n "* ]] || return 1; done
}

@test "opt-in modules run only when their setting is yes" {
  [[ " $(selected) " != *" 22 "* ]] || return 1
  SUPPLY_CHAIN=yes
  [[ " $(selected) " == *" 22 "* ]] || return 1
}
