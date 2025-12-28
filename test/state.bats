#!/usr/bin/env bats

load test_helper

@test "init_state creates valid state" {
  init_state

  # Check version is set
  local version
  version=$(echo "$STATE_JSON" | jq -r '.version')
  [ "$version" = "$GAS_VERSION" ]

  # Check accounts is empty array
  local account_count
  account_count=$(echo "$STATE_JSON" | jq '.accounts | length')
  [ "$account_count" -eq 0 ]
}

@test "add_account adds account to state" {
  init_state

  add_account "work" "Work Account" "gh-work" "$HOME/.ssh/id_work" \
    "$HOME/workspace/work" "John Work" "john@work.com"

  local account_count
  account_count=$(get_account_count)
  [ "$account_count" -eq 1 ]

  # Check account details
  local account
  account=$(get_account "work")
  [ "$(echo "$account" | jq -r '.name')" = "Work Account" ]
  [ "$(echo "$account" | jq -r '.git_email')" = "john@work.com" ]
}

@test "account_exists returns true for existing account" {
  create_test_state

  run account_exists "personal"
  [ "$status" -eq 0 ]
}

@test "account_exists returns false for non-existing account" {
  create_test_state

  run account_exists "nonexistent"
  [ "$status" -eq 1 ]
}

@test "remove_account removes account from state" {
  create_test_state

  # Add another account
  add_account "work" "Work" "gh-work" "$HOME/.ssh/id_work" \
    "$HOME/workspace/work" "John Work" "john@work.com"

  local initial_count
  initial_count=$(get_account_count)
  [ "$initial_count" -eq 2 ]

  remove_account "personal"

  local final_count
  final_count=$(get_account_count)
  [ "$final_count" -eq 1 ]

  run account_exists "personal"
  [ "$status" -eq 1 ]
}

@test "validate_state passes for valid state" {
  create_test_state

  run validate_state
  [ "$status" -eq 0 ]
}

@test "validate_state fails for duplicate IDs" {
  init_state

  # Manually add duplicate IDs
  STATE_JSON=$(echo "$STATE_JSON" | jq '.accounts = [
    {"id": "dup", "name": "First", "ssh_alias": "gh-1", "workspace": "~/w1", "git_email": "a@a.com"},
    {"id": "dup", "name": "Second", "ssh_alias": "gh-2", "workspace": "~/w2", "git_email": "b@b.com"}
  ]')

  run validate_state
  [ "$status" -eq 1 ]
}

@test "save_state and load_state round-trip" {
  create_test_state
  save_state

  # Reset state
  STATE_JSON=""

  # Load state
  load_state

  local account_count
  account_count=$(get_account_count)
  [ "$account_count" -eq 1 ]

  local account
  account=$(get_account "personal")
  [ "$(echo "$account" | jq -r '.git_email')" = "john@personal.com" ]
}
