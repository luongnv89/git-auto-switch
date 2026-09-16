#!/usr/bin/env bats

load test_helper

setup_help() {
  source "$PROJECT_ROOT/lib/cli/help.sh"
}

@test "help output documents every router command" {
  setup_help

  run show_help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE:"* ]]
  [[ "$output" == *"COMMANDS:"* ]]

  local cmd
  for cmd in init add remove list apply validate audit current help version; do
    [[ "$output" == *"  $cmd "* ]]
  done
}

@test "version output reports the package version" {
  setup_help

  run show_version
  [ "$status" -eq 0 ]
  [ "$output" = "git-auto-switch version $GAS_VERSION" ]
}
