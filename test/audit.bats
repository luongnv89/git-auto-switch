#!/usr/bin/env bats

load test_helper

setup_git_repo() {
  local repo_path="$1"
  local email="$2"

  mkdir -p "$repo_path"
  cd "$repo_path"
  git init -q
  git config user.name "Test User"
  git config user.email "$email"
  # Create a dummy remote
  git remote add origin "git@github.com:test/repo.git"
}

@test "audit detects email mismatch in repository" {
  create_test_state
  save_state

  # Create a repo with wrong email
  setup_git_repo "$HOME/workspace/personal/repo1" "wrong@email.com"

  # Source audit command
  source "$PROJECT_ROOT/lib/commands/audit.sh"

  cd "$HOME/workspace/personal/repo1"

  # Check the repo email vs expected
  local repo_email expected_email
  repo_email=$(git config user.email)
  expected_email="john@personal.com"

  [ "$repo_email" = "wrong@email.com" ]
  [ "$repo_email" != "$expected_email" ]
}

@test "audit detects remote not using SSH alias" {
  create_test_state
  save_state

  setup_git_repo "$HOME/workspace/personal/repo1" "john@personal.com"

  cd "$HOME/workspace/personal/repo1"

  local origin_url
  origin_url=$(git remote get-url origin)

  # Remote uses github.com but not the SSH alias
  echo "$origin_url" | grep -q "github.com"
  ! echo "$origin_url" | grep -q "gh-personal"
}

@test "audit fix removes local user.email" {
  create_test_state
  save_state

  setup_git_repo "$HOME/workspace/personal/repo1" "wrong@email.com"

  cd "$HOME/workspace/personal/repo1"

  # Verify local email is set
  local before_email
  before_email=$(git config --local user.email 2>/dev/null || echo "")
  [ "$before_email" = "wrong@email.com" ]

  # Simulate fix by unsetting local email
  git config --unset user.email

  # Verify local email is removed
  local after_email
  after_email=$(git config --local user.email 2>/dev/null || echo "")
  [ -z "$after_email" ]
}

@test "audit reports unreadable repo instead of aborting (F-BUG-003)" {
  create_test_state
  save_state

  setup_git_repo "$HOME/workspace/personal/good" "wrong@email.com"
  touch "$HOME/workspace/personal/bad-is-a-file"

  source "$PROJECT_ROOT/lib/commands/audit.sh"

  # Shadow discovery so one entry cannot be entered (cd fails on a file),
  # exactly like an unreadable repo directory would.
  find_git_repos() {
    echo "$HOME/workspace/personal/good"
    echo "$HOME/workspace/personal/bad-is-a-file"
  }

  run cmd_audit

  unset -f find_git_repos

  [ "$status" -eq 1 ]
  # The unreadable entry is reported ...
  [[ "$output" == *"bad-is-a-file"* ]]
  [[ "$output" == *"Failed to audit"* ]]
  # ... and the audit still ran to completion over the good repo
  [[ "$output" == *"Audit Summary"* ]]
  [[ "$output" == *"good"* ]]
}

@test "audit does not abort when it cannot return to previous directory (F-BUG-003)" {
  create_test_state
  save_state

  setup_git_repo "$HOME/workspace/personal/repo1" "wrong@email.com"

  source "$PROJECT_ROOT/lib/commands/audit.sh"

  # Delete the cwd so the post-repo `cd` back fails: the old code ran
  # `exit 1` here and aborted the whole audit without a summary.
  local doomed="$TEST_TEMP_DIR/doomed-cwd"
  mkdir -p "$doomed"
  cd "$doomed"
  rm -rf "$doomed"

  run cmd_audit
  cd "$HOME" || true

  [ "$status" -eq 1 ]
  [[ "$output" == *"Audit Summary"* ]]
  [[ "$output" == *"repo1"* ]]
  [[ "$output" == *"Failed to audit"* ]]
}
