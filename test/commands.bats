#!/usr/bin/env bats

load test_helper

# Test current command helper
test_find_account_for_directory() {
  local dir="$1"
  echo "$STATE_JSON" | jq --arg dir "$dir" '
    [.accounts[] |
    select(.workspaces[] as $ws | ($dir + "/") | startswith(($ws | gsub("~"; env.HOME)) + "/"))] |
    first // empty
  '
}

@test "current finds account for directory inside workspace" {
  create_test_state
  mkdir -p "$HOME/workspace/personal/project1"

  local account
  account=$(test_find_account_for_directory "$HOME/workspace/personal/project1")

  [ -n "$account" ]
  [ "$(echo "$account" | jq -r '.id')" = "personal" ]
}

@test "current returns empty for directory outside workspace" {
  create_test_state
  mkdir -p "$HOME/other/project"

  local account
  account=$(test_find_account_for_directory "$HOME/other/project")

  [ -z "$account" ] || [ "$account" = "null" ]
}

@test "current finds correct account with multiple accounts" {
  create_test_state
  add_account "work" "Work" "gh-work" "$HOME/.ssh/id_work" \
    '["'"$HOME"'/workspace/work"]' "John Work" "john@work.com"

  mkdir -p "$HOME/workspace/personal/myproject"
  mkdir -p "$HOME/workspace/work/company"

  # Check personal workspace
  local account1
  account1=$(test_find_account_for_directory "$HOME/workspace/personal/myproject")
  [ "$(echo "$account1" | jq -r '.id')" = "personal" ]

  # Check work workspace
  local account2
  account2=$(test_find_account_for_directory "$HOME/workspace/work/company")
  [ "$(echo "$account2" | jq -r '.id')" = "work" ]
}

@test "current finds account with multiple workspaces" {
  init_state
  add_account "dev" "Developer" "gh-dev" "$HOME/.ssh/id_dev" \
    '["'"$HOME"'/workspace/main", "'"$HOME"'/projects"]' "Dev User" "dev@example.com"

  mkdir -p "$HOME/workspace/main/repo1"
  mkdir -p "$HOME/projects/repo2"

  # Check first workspace
  local account1
  account1=$(test_find_account_for_directory "$HOME/workspace/main/repo1")
  [ "$(echo "$account1" | jq -r '.id')" = "dev" ]

  # Check second workspace
  local account2
  account2=$(test_find_account_for_directory "$HOME/projects/repo2")
  [ "$(echo "$account2" | jq -r '.id')" = "dev" ]
}
