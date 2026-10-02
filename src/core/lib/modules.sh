# shellcheck shell=bash
# Module metadata and selection.
#
# Every module starts with header comments the engine reads:
#   # @title  <one line shown by macscan --modules>
#   # @quick  skip              left out of --quick scans
#   # @toggle YARA|CLAMAV|LOGS|SUPPLY_CHAIN|EXEC_MONITOR
#                               left out when that feature is turned off

# module_meta <file> <key>: prints the value of "# @key value" from the first 20 lines.
module_meta(){
  awk -v k="# @$2" 'NR>20{exit} index($0,k" ")==1 || $0==k {v=substr($0,length(k)+1); sub(/^[ \t]+/,"",v); print v; exit}' "$1"
}

# module_selected <file>: uses ONLY SKIP QUICK DO_YARA DO_CLAM NO_LOGS.
module_selected(){
  local name num
  name=$(basename "$1" .sh); num=${name%%-*}
  if [ -n "$ONLY" ]; then case ",$ONLY," in *",$num,"*) ;; *) return 1;; esac; fi
  if [ -n "$SKIP" ]; then case ",$SKIP," in *",$num,"*) return 1;; esac; fi
  if [ "$QUICK" = 1 ] && [ "$(module_meta "$1" quick)" = skip ]; then return 1; fi
  case "$(module_meta "$1" toggle)" in
    YARA) [ "$DO_YARA" = yes ] || return 1;;
    CLAMAV) [ "$DO_CLAM" = yes ] || return 1;;
    LOGS) [ "$NO_LOGS" = 1 ] && return 1;;
    SUPPLY_CHAIN) [ "${SUPPLY_CHAIN:-no}" = yes ] || return 1;;
    EXEC_MONITOR) [ "${EXEC_MONITOR:-no}" = yes ] || return 1;;
  esac
  return 0
}
