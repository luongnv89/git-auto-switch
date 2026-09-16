#!/usr/bin/env bats

load test_helper

setup_current_command() {
  source "$PROJECT_ROOT/lib/commands/current.sh"
}

@test "current fails when git-auto-switch is not initialized" {
  setup_current_command

  run cmd_current
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not initialized"* ]]
}

@test "current reports the account for a directory inside its workspace" {
  create_test_state
  save_state
  setup_current_command

  mkdir -p "$HOME/workspace/personal/project1"
  cd "$HOME/workspace/personal/project1"

  run cmd_current
  [ "$status" -eq 0 ]
  [[ "$output" == *"Current Account: Personal"* ]]
  [[ "$output" == *"Account ID:  personal"* ]]
  [[ "$output" == *"john@personal.com"* ]]
  [[ "$output" == *"gh-personal"* ]]
}

@test "current matches a repo nested below the workspace root" {
  create_test_state
  save_state
  setup_current_command

  mkdir -p "$HOME/workspace/personal/deep/nested/repo"
  cd "$HOME/workspace/personal/deep/nested/repo"

  run cmd_current
  [ "$status" -eq 0 ]
  [[ "$output" == *"Current Account: Personal"* ]]
}

@test "current warns when the directory is outside every workspace" {
  create_test_state
  save_state
  setup_current_command

  mkdir -p "$HOME/elsewhere"
  cd "$HOME/elsewhere"

  run cmd_current
  [ "$status" -eq 1 ]
  [[ "$output" == *"No account configured for this directory"* ]]
  [[ "$output" == *"Global Git identity"* ]]
}

@test "current flags a repo whose git email differs from the account" {
  create_test_state
  save_state
  setup_current_command

  local repo="$HOME/workspace/personal/project1"
  mkdir -p "$repo"
  cd "$repo"
  git init -q
  git config user.name "Wrong User"
  git config user.email "wrong@example.com"

  run cmd_current
  [ "$status" -eq 0 ]
  [[ "$output" == *"Current Account: Personal"* ]]
  [[ "$output" == *"email mismatch"* ]]
  [[ "$output" == *"gas audit --fix"* ]]
}

@test "current flags an origin that bypasses the SSH alias" {
  create_test_state
  save_state
  setup_current_command

  local repo="$HOME/workspace/personal/project1"
  mkdir -p "$repo"
  cd "$repo"
  git init -q
  git config user.email "john@personal.com"
  git remote add origin "git@github.com:user/repo.git"

  run cmd_current
  [ "$status" -eq 0 ]
  [[ "$output" == *"github.com instead of SSH alias"* ]]
}
