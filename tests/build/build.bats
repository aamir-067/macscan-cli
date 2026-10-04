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

@test "installer checks that the install path is root-owned and not writable by others" {
  grep -q 'safe_dir "$d" || return 1' "$OUTDIR/install-mac-triage.sh"
  grep -q 'Refusing to install: $d is writable by group or others' "$OUTDIR/install-mac-triage.sh"
}

@test "installer edits the user's .zshrc as the user, never as root" {
  not grep -nE '^[^#]*sed -i .*\.zshrc' <(grep -v 'sudo -u "\$U" sed -i' "$OUTDIR/install-mac-triage.sh")
}

@test "CHANGELOG has an entry for the current version" {
  grep -q "^## \[$(cat "$REPO/VERSION")\] - [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$" "$REPO/CHANGELOG.md"
}

@test "bump-version moves unreleased notes under the new version" {
  cp -R "$REPO/scripts" "$REPO/VERSION" "$REPO/CHANGELOG.md" "$BATS_TEST_TMPDIR/"
  mkdir -p "$BATS_TEST_TMPDIR/r"; mv "$BATS_TEST_TMPDIR/scripts" "$BATS_TEST_TMPDIR/VERSION" "$BATS_TEST_TMPDIR/CHANGELOG.md" "$BATS_TEST_TMPDIR/r/"
  echo "1.2.3" > "$BATS_TEST_TMPDIR/r/VERSION"
  perl -0pi -e 's/## \[Unreleased\]\n/## [Unreleased]\n### Fixed\n- thing\n/' "$BATS_TEST_TMPDIR/r/CHANGELOG.md"
  "$BATS_TEST_TMPDIR/r/scripts/bump-version.sh" minor >/dev/null
  [ "$(cat "$BATS_TEST_TMPDIR/r/VERSION")" = 1.3.0 ]
  grep -q '^## \[1.3.0\] - ' "$BATS_TEST_TMPDIR/r/CHANGELOG.md"
  [ "$(grep -A3 '^## \[1.3.0\]' "$BATS_TEST_TMPDIR/r/CHANGELOG.md" | grep -c 'thing')" = 1 ]
  grep -q '^\[Unreleased\]: .*compare/v1.3.0...HEAD$' "$BATS_TEST_TMPDIR/r/CHANGELOG.md"
}

@test "links point at the published repository (aamir-067/macscan-cli)" {
  run bash -c 'cd "$1" && git ls-files ":!tests/build/build.bats" | xargs grep -nE "github\.com/aamir-067/|--repo aamir-067/" | grep -vE "aamir-067/(macscan-cli|homebrew-tap)"' _ "$REPO"
  [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "the Homebrew formula template renders to valid Ruby with no placeholders left" {
  command -v ruby >/dev/null || skip "ruby is not available"
  sed -e 's/@VERSION@/9.9.9/g' -e "s/@SHA256@/$(printf '%064d' 0)/g" "$REPO/packaging/homebrew/macscan.rb.in" > "$BATS_TEST_TMPDIR/macscan.rb"
  ruby -c "$BATS_TEST_TMPDIR/macscan.rb" >/dev/null
  not grep -q '@[A-Z0-9]*@' "$BATS_TEST_TMPDIR/macscan.rb"
  grep -q 'releases/download/v9.9.9/install-mac-triage.sh' "$BATS_TEST_TMPDIR/macscan.rb"
  not grep -qE 'sudo macscan-setup' "$BATS_TEST_TMPDIR/macscan.rb"
}
