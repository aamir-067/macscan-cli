#!/usr/bin/env bats
# The build produces a valid, self-consistent installer.

load ../helpers

setup_file(){
  export OUTDIR="$BATS_FILE_TMPDIR/dist"
  "$BATS_TEST_DIRNAME/../../scripts/build.sh" --out "$OUTDIR" >/dev/null
}

@test "VERSION is semantic (MAJOR.MINOR.PATCH)" {
  [[ "$(cat "$REPO/VERSION")" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
}

@test "installer reports the same version" {
  run bash "$OUTDIR/install-mac-triage.sh" --version
  [ "$output" = "mac-triage installer $(cat "$REPO/VERSION")" ]
}

@test "installer payload is exactly src/ plus VERSION" {
  bash "$OUTDIR/install-mac-triage.sh" --extract-only "$BATS_TEST_TMPDIR/x" >/dev/null
  diff -r -x installer "$SRC" "$BATS_TEST_TMPDIR/x" | grep -v "^Only in $BATS_TEST_TMPDIR/x: VERSION$" && return 1
  [ "$(cat "$BATS_TEST_TMPDIR/x/VERSION")" = "$(cat "$REPO/VERSION")" ]
}

@test "installer refuses to run without root" {
  [ "$EUID" -ne 0 ] || skip "running as root"
  run bash "$OUTDIR/install-mac-triage.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"sudo"* ]] || return 1
}

@test "checksums match the artifacts" {
  (cd "$OUTDIR" && shasum -a 256 -c SHA256SUMS)
}

@test "tarball contains the installable tree" {
  v=$(cat "$REPO/VERSION")
  tar -tzf "$OUTDIR/mac-triage-$v.tar.gz" | grep -qx "mac-triage-$v/core/run.sh"
  tar -tzf "$OUTDIR/mac-triage-$v.tar.gz" | grep -qx "mac-triage-$v/VERSION"
}

@test "the build is reproducible" {
  "$REPO/scripts/build.sh" --out "$BATS_TEST_TMPDIR/again" >/dev/null
  cmp "$OUTDIR/install-mac-triage.sh" "$BATS_TEST_TMPDIR/again/install-mac-triage.sh"
}
