#!/usr/bin/env bats

load test_helper

# Mirror the entry point: router + every command module it can dispatch to.
setup_router() {
  source "$PROJECT_ROOT/lib/cli/help.sh"
  source "$PROJECT_ROOT/lib/cli/router.sh"
  local cmd
  for cmd in init add remove list apply validate audit current; do
    source "$PROJECT_ROOT/lib/commands/$cmd.sh"
  done
}

@test "router shows help when invoked without arguments" {
  setup_router

  run route_command
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE:"* ]]
}

@test "router shows help for help, --help and -h" {
  setup_router

  run route_command help
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMMANDS:"* ]]

  run route_command --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMMANDS:"* ]]

  run route_command -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMMANDS:"* ]]
}

@test "router prints the version for version, --version and -v" {
  setup_router

  run route_command version
  [ "$status" -eq 0 ]
  [[ "$output" == *"git-auto-switch version"* ]]

  run route_command --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"git-auto-switch version"* ]]

  run route_command -v
  [ "$status" -eq 0 ]
  [[ "$output" == *"git-auto-switch version"* ]]
}

@test "router rejects an unknown command and shows help" {
  setup_router

  run route_command bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown command: bogus"* ]]
  [[ "$output" == *"USAGE:"* ]]
}

@test "router dispatches list to cmd_list" {
  create_test_state
  save_state
  setup_router

  run route_command list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Configured accounts (1)"* ]]
}

@test "router dispatches the ls alias to cmd_list" {
  create_test_state
  save_state
  setup_router

  run route_command ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"Configured accounts (1)"* ]]
}

@test "router dispatches whoami to cmd_current" {
  create_test_state
  save_state
  setup_router

  mkdir -p "$HOME/workspace/personal/project1"
  cd "$HOME/workspace/personal/project1"

  run route_command whoami
  [ "$status" -eq 0 ]
  [[ "$output" == *"Current Account: Personal"* ]]
}

@test "router dispatches check to cmd_validate" {
  create_test_state
  save_state
  setup_router

  run route_command check <<< "n"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Configuration Validation"* ]]
}

@test "router dispatches init to cmd_init" {
  create_test_state
  save_state
  setup_router

  # Existing config: decline the reinitialize prompt to prove dispatch.
  run route_command init <<< "n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists"* ]]
}
