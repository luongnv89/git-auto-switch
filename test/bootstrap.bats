#!/usr/bin/env bats
# bootstrap.bats — shared launcher bootstrap (lib/bootstrap.sh, F-CLEAN-002).
#
# The single implementation of OS detection, package-manager detection, and
# dependency install flows used by the npm launcher, the pip launcher, and
# install-curl.sh. Tests source it under GAS_SOURCE_ONLY for unit coverage
# and invoke it directly for the --target/--ensure contract.

setup() {
  export GAS_SOURCE_ONLY=true
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export PROJECT_ROOT
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/lib/bootstrap.sh"
}

# --------------------------------------------------------------------------
# Detection helpers
# --------------------------------------------------------------------------

@test "detect_os returns a known value on this machine" {
  run detect_os
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^(macos|debian|redhat|arch|alpine|linux|unknown)$ ]]
}

@test "detect_package_manager maps fixed OS values" {
  [ "$(detect_package_manager debian)" = "apt" ]
  [ "$(detect_package_manager arch)" = "pacman" ]
  [ "$(detect_package_manager alpine)" = "apk" ]
  [ "$(detect_package_manager plan9)" = "none" ]
}

@test "detect_package_manager on macos resolves brew or none" {
  run detect_package_manager macos
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^(brew|none)$ ]]
}

@test "get_os_display_name maps known and passes through unknown" {
  [ "$(get_os_display_name macos)" = "macOS" ]
  [ "$(get_os_display_name debian)" = "Debian/Ubuntu" ]
  [ "$(get_os_display_name plan9)" = "plan9" ]
}

@test "check_command distinguishes present from absent" {
  run check_command sh
  [ "$status" -eq 0 ]
  run check_command gas-definitely-not-a-real-cmd-xyz
  [ "$status" -eq 1 ]
}

@test "get_missing_deps reports a stubbed missing dep" {
  check_command() { if [[ "$1" == "jq" ]]; then return 1; else return 0; fi }
  run get_missing_deps
  [ "$output" = "jq" ]
}

@test "bash_version_ok passes under this suite's bash" {
  run bash_version_ok
  [ "$status" -eq 0 ]
}

@test "get_missing_deps stays set -u safe on an empty array (bash 3.2)" {
  # bash 3.2 (the project floor) errors on "${arr[*]}" when the array is
  # empty under set -u; the expansion must carry a :- default.
  run grep -c 'echo "${missing\[\*\]:-}"' "$PROJECT_ROOT/lib/bootstrap.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  ! grep -q 'echo "${missing\[\*\]}"' "$PROJECT_ROOT/lib/bootstrap.sh"
}

# --------------------------------------------------------------------------
# ensure_dependencies contract: 0 ready / 1 failed / 2 cancelled
# --------------------------------------------------------------------------

@test "ensure_dependencies is silent on the launcher fast path" {
  run ensure_dependencies launcher
  [ "$status" -eq 0 ]
  [[ "$output" != *"Installation Plan"* ]]
}

@test "ensure_dependencies reports satisfied on the installer path" {
  run ensure_dependencies installer
  [ "$status" -eq 0 ]
  [[ "$output" == *"All dependencies satisfied"* ]]
}

@test "ensure_dependencies cancels when the plan is declined" {
  check_command() { return 1; }  # everything missing
  decline() { printf 'n\n' | ensure_dependencies launcher; }
  run decline
  [ "$status" -eq 2 ]
  [[ "$output" == *"Installation cancelled"* ]]
}

@test "ensure_dependencies cancels on closed stdin rather than installing" {
  check_command() { return 1; }
  eof() { ensure_dependencies launcher < /dev/null; }
  run eof
  [ "$status" -eq 2 ]
  [[ "$output" == *"Installation cancelled"* ]]
}

@test "AUTO_INSTALL proceeds without prompting and re-verifies" {
  check_command() { return 1; }
  install_dependencies() { check_command() { return 0; }; return 0; }
  AUTO_INSTALL=true run ensure_dependencies installer
  [ "$status" -eq 0 ]
  [[ "$output" == *"All dependencies satisfied"* ]]
}

@test "ensure_dependencies fails when deps are still missing after install" {
  check_command() { return 1; }
  install_dependencies() { return 0; }  # claims success but nothing installed
  AUTO_INSTALL=true run ensure_dependencies installer
  [ "$status" -eq 1 ]
  [[ "$output" == *"still missing"* ]]
}

# --------------------------------------------------------------------------
# F-SEC-001: the Homebrew install must download-verify-exec, never curl|bash
# --------------------------------------------------------------------------

@test "install_homebrew never pipes a network stream into a shell" {
  # The installer body is downloaded to a file, verified non-empty, then
  # executed as a file argument — no 'curl | bash' anywhere in the module.
  ! grep -q 'curl[^|]*| *bash' "$PROJECT_ROOT/lib/bootstrap.sh"
  grep -q '/bin/bash "\$tmp_file"' "$PROJECT_ROOT/lib/bootstrap.sh"
  grep -q 'mktemp' "$PROJECT_ROOT/lib/bootstrap.sh"
}

# --------------------------------------------------------------------------
# Convergence guards: the logic must not grow back into the shims
# --------------------------------------------------------------------------

@test "npm launcher carries no detection or install copy" {
  ! grep -q 'function detectOS\|function installPackage\|function installHomebrew' \
    "$PROJECT_ROOT/bin/git-auto-switch.js"
}

@test "pip launcher carries no detection or install copy" {
  ! grep -q 'def detect_os\|def install_package\|def install_homebrew' \
    "$PROJECT_ROOT/git_auto_switch/cli.py"
}

@test "install-curl.sh carries no detection or install copy" {
  ! grep -q '^detect_os()\|^detect_package_manager()\|^install_homebrew()' \
    "$PROJECT_ROOT/install-curl.sh"
}

@test "install-curl.sh delegates dep ensure to the shared bootstrap" {
  grep -q 'bootstrap" --ensure' "$PROJECT_ROOT/install-curl.sh"
}

# --------------------------------------------------------------------------
# Entry contract — GAS_SOURCE_ONLY must be off for the child process to run
# main (setup exports it for the sourced unit tests above).
# --------------------------------------------------------------------------

@test "--target execs the CLI and propagates its exit code" {
  run env GAS_SOURCE_ONLY=false bash "$PROJECT_ROOT/lib/bootstrap.sh" --target "$PROJECT_ROOT/git-auto-switch" version
  [ "$status" -eq 0 ]
  [[ "$output" == *"git-auto-switch version"* ]]
}

@test "--target fails on a missing target" {
  run env GAS_SOURCE_ONLY=false bash "$PROJECT_ROOT/lib/bootstrap.sh" --target /nonexistent/git-auto-switch
  [ "$status" -eq 1 ]
}

@test "--ensure exits 0 when deps are satisfied" {
  run env GAS_SOURCE_ONLY=false bash "$PROJECT_ROOT/lib/bootstrap.sh" --ensure
  [ "$status" -eq 0 ]
}

@test "unknown argument fails" {
  run env GAS_SOURCE_ONLY=false bash "$PROJECT_ROOT/lib/bootstrap.sh" --bogus
  [ "$status" -eq 1 ]
}

@test "--help prints usage" {
  run env GAS_SOURCE_ONLY=false bash "$PROJECT_ROOT/lib/bootstrap.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--target"* ]]
}
