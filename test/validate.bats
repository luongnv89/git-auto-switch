#!/usr/bin/env bats

load test_helper

# cmd_validate drives the command; cmd_apply is sourced so the happy-path
# test can lay down a fully applied configuration first.
setup_validate_command() {
  source "$PROJECT_ROOT/lib/commands/validate.sh"
  source "$PROJECT_ROOT/lib/commands/apply.sh"
}

@test "validate fails when git-auto-switch is not initialized" {
  setup_validate_command

  run cmd_validate <<< ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not initialized"* ]]
}

@test "validate warns when no accounts are configured" {
  init_state
  save_state
  setup_validate_command

  run cmd_validate <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"No accounts configured"* ]]
  [[ "$output" == *"0 errors, 1 warnings"* ]]
}

@test "validate fails when account artifacts were never applied" {
  create_test_state
  save_state
  setup_validate_command

  # Decline the per-account SSH connection test.
  run cmd_validate <<< "n"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SSH key missing"* ]]
  [[ "$output" == *"Validation failed"* ]]
}

@test "validate passes on a fully applied configuration" {
  create_test_state
  save_state
  setup_validate_command

  # Satisfy every cmd_validate check: key file, workspace dir, applied
  # SSH/git configs and the installed pre-commit hook.
  touch "$HOME/.ssh/id_personal"
  mkdir -p "$HOME/workspace/personal"
  cmd_apply

  run cmd_validate <<< "n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Validation passed: 0 errors"* ]]
}
