#!/usr/bin/env bats

load test_helper

setup_list_command() {
  source "$PROJECT_ROOT/lib/commands/list.sh"
}

@test "list fails when git-auto-switch is not initialized" {
  setup_list_command

  run cmd_list
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not initialized"* ]]
}

@test "list reports when no accounts are configured" {
  init_state
  save_state
  setup_list_command

  run cmd_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No accounts configured"* ]]
  [[ "$output" == *"add"* ]]
}

@test "list prints account details" {
  create_test_state
  save_state
  setup_list_command

  run cmd_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Configured accounts (1)"* ]]
  [[ "$output" == *"[personal] Personal"* ]]
  [[ "$output" == *"John Doe <john@personal.com>"* ]]
  [[ "$output" == *"gh-personal"* ]]
  [[ "$output" == *"$HOME/workspace/personal"* ]]
}

@test "list prints every configured account" {
  create_test_state
  add_account "work" "Work" "gh-work" "$HOME/.ssh/id_work" \
    '["'"$HOME"'/workspace/work"]' "John Work" "john@work.com"
  save_state
  setup_list_command

  run cmd_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Configured accounts (2)"* ]]
  [[ "$output" == *"[personal] Personal"* ]]
  [[ "$output" == *"[work] Work"* ]]
  [[ "$output" == *"john@work.com"* ]]
}
