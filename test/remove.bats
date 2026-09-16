#!/usr/bin/env bats

load test_helper

setup_remove_command() {
  source "$PROJECT_ROOT/lib/commands/remove.sh"
  source "$PROJECT_ROOT/lib/commands/apply.sh"
}

@test "remove fails when git-auto-switch is not initialized" {
  setup_remove_command

  run cmd_remove personal <<< ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not initialized"* ]]
}

@test "remove fails when no accounts are configured" {
  init_state
  save_state
  setup_remove_command

  run cmd_remove personal <<< ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"No accounts configured"* ]]
}

@test "remove fails for an unknown account id" {
  create_test_state
  save_state
  setup_remove_command

  run cmd_remove ghost <<< ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]

  # State is untouched.
  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 1 ]
}

@test "remove cancels when the confirmation is declined" {
  create_test_state
  save_state
  setup_remove_command

  run cmd_remove personal <<< "n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cancelled"* ]]

  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 1 ]
}

@test "remove deletes the account and its per-account gitconfig" {
  create_test_state
  save_state
  setup_remove_command
  touch "$HOME/.gitconfig-personal"

  # Confirm removal, decline the reapply prompt.
  run cmd_remove personal <<< "$(printf '%s\n' "y" "n")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed successfully"* ]]

  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 0 ]
  [ ! -f "$HOME/.gitconfig-personal" ]
}

@test "remove prompts for an account when no id is given" {
  create_test_state
  save_state
  setup_remove_command

  # Pick entry 1 from the select menu, confirm, decline reapply.
  run cmd_remove <<< "$(printf '%s\n' "1" "y" "n")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed successfully"* ]]

  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 0 ]
}

@test "remove reapplies configuration when the user accepts" {
  create_test_state
  save_state
  setup_remove_command

  # Confirm removal and accept reapply; with zero accounts left cmd_apply
  # is a no-op that still exercises the reapply branch.
  run cmd_remove personal <<< "$(printf '%s\n' "y" "y")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed successfully"* ]]
  [[ "$output" == *"Nothing to apply"* ]]

  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 0 ]
}
