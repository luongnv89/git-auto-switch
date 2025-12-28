#!/usr/bin/env bats

load test_helper

@test "add_account with multiple workspaces" {
  init_state

  add_account "multi" "Multi Workspace" "gh-multi" "$HOME/.ssh/id_multi" \
    '["'"$HOME"'/workspace/a", "'"$HOME"'/workspace/b", "'"$HOME"'/workspace/c"]' \
    "Multi User" "multi@example.com"

  local account
  account=$(get_account "multi")

  # Check all workspaces are stored
  local ws_count
  ws_count=$(echo "$account" | jq '.workspaces | length')
  [ "$ws_count" -eq 3 ]

  [ "$(echo "$account" | jq -r '.workspaces[0]')" = "$HOME/workspace/a" ]
  [ "$(echo "$account" | jq -r '.workspaces[1]')" = "$HOME/workspace/b" ]
  [ "$(echo "$account" | jq -r '.workspaces[2]')" = "$HOME/workspace/c" ]
}

@test "generate_git_include_block with multiple workspaces" {
  init_state
  add_account "multi" "Multi" "gh-multi" "$HOME/.ssh/id_multi" \
    '["'"$HOME"'/workspace/a", "'"$HOME"'/workspace/b"]' \
    "Multi User" "multi@example.com"

  local include_block
  include_block=$(generate_git_include_block)

  # Check both workspaces have includeIf entries
  echo "$include_block" | grep -q "gitdir:$HOME/workspace/a/"
  echo "$include_block" | grep -q "gitdir:$HOME/workspace/b/"
}

@test "validate_state catches duplicate workspaces" {
  init_state

  # Add two accounts with the same workspace
  STATE_JSON=$(echo "$STATE_JSON" | jq '.accounts = [
    {"id": "a1", "name": "Account 1", "ssh_alias": "gh-1", "workspaces": ["~/workspace"], "git_email": "a@a.com"},
    {"id": "a2", "name": "Account 2", "ssh_alias": "gh-2", "workspaces": ["~/workspace"], "git_email": "b@b.com"}
  ]')

  run validate_state
  [ "$status" -eq 1 ]
}

@test "validate_state catches overlapping workspaces" {
  init_state

  # One workspace is inside another
  STATE_JSON=$(echo "$STATE_JSON" | jq '.accounts = [
    {"id": "a1", "name": "Account 1", "ssh_alias": "gh-1", "workspaces": ["~/workspace"], "git_email": "a@a.com"},
    {"id": "a2", "name": "Account 2", "ssh_alias": "gh-2", "workspaces": ["~/workspace/sub"], "git_email": "b@b.com"}
  ]')

  run validate_state
  [ "$status" -eq 1 ]
}

@test "validate_state passes for non-overlapping workspaces" {
  init_state
  add_account "a1" "Account 1" "gh-1" "$HOME/.ssh/id_1" \
    '["'"$HOME"'/workspace/a"]' "User A" "a@example.com"
  add_account "a2" "Account 2" "gh-2" "$HOME/.ssh/id_2" \
    '["'"$HOME"'/workspace/b"]' "User B" "b@example.com"

  run validate_state
  [ "$status" -eq 0 ]
}
