# Shared setup for the bats suite. Nothing here needs root or changes the system.
REPO="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd -P)"
SRC="$REPO/src"

# A throwaway environment that looks like what run.sh gives a module.
make_env(){
  TEST_TMP="$(mktemp -d "${BATS_TMPDIR:-/tmp}/mactriage-test.XXXXXX")"
  export UH="$TEST_TMP/home" RUN="$TEST_TMP/run" INV="$TEST_TMP/inv" OUTBASE="$TEST_TMP/home/Documents/mac-triage-reports"
  export STATE="$TEST_TMP/state" MT_TMP="$TEST_TMP/tmp"
  export U; U="$(id -un)"
  export UID_N; UID_N="$(id -u)"
  export DAYS=60 QUICK=0 CLAM_SCOPE=standard MODULE=test
  mkdir -p "$UH/Library/Application Support" "$UH/Documents" "$RUN/modules" "$INV" "$STATE/inv" "$MT_TMP"
  : > "$RUN/.flags.raw"
}

drop_env(){ [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"; return 0; }

# Load the shared library the same way modules do.
load_common(){
  # shellcheck source=/dev/null
  source "$SRC/core/common.sh"
}

# Run one module as the current user with stubbed privilege tools.
run_module(){
  local m; m=$(ls "$SRC"/modules/"$1"-*.sh)
  MODULE="$(basename "$m" .sh)" PATH="$REPO/tests/stubs:/usr/bin:/bin:/usr/sbin:/sbin" \
    run /bin/bash "$m"
}

flags(){ cat "$RUN/.flags.raw"; }

# Snapshot of every file under a tree with size and mtime, for "wrote nothing" checks.
tree_snapshot(){ find "$1" -print0 2>/dev/null | xargs -0 stat -f '%N %z %m' 2>/dev/null | LC_ALL=C sort; }

# Negative assertion that works on any line (a bare `! cmd` never fails a bats test).
not(){ if "$@"; then echo "expected to fail: $*"; return 1; fi; return 0; }
