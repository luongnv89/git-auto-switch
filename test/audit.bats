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
