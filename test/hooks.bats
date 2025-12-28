#!/usr/bin/env bats

load test_helper

@test "install_commit_guard creates pre-commit hook" {
  # Set up required arrays
  NAMES=("work")
  GIT_EMAILS=("work@example.com")

  source "$PROJECT_ROOT/lib/hooks.sh"

  install_commit_guard 0

  [ -f "$HOME/.git-hooks/pre-commit" ]
  [ -x "$HOME/.git-hooks/pre-commit" ]
}

@test "pre-commit hook contains expected email" {
  NAMES=("work")
  GIT_EMAILS=("work@example.com")

  source "$PROJECT_ROOT/lib/hooks.sh"

  install_commit_guard 0

  grep -q "work@example.com" "$HOME/.git-hooks/pre-commit"
}

@test "pre-commit hook is executable" {
  NAMES=("personal")
  GIT_EMAILS=("personal@example.com")

  source "$PROJECT_ROOT/lib/hooks.sh"

  install_commit_guard 0

  # Verify it's executable
  [[ -x "$HOME/.git-hooks/pre-commit" ]]
}

@test "install_commit_guard creates git-hooks directory" {
  NAMES=("test")
  GIT_EMAILS=("test@example.com")

  # Ensure directory doesn't exist
  rm -rf "$HOME/.git-hooks"

  source "$PROJECT_ROOT/lib/hooks.sh"

  install_commit_guard 0

  [ -d "$HOME/.git-hooks" ]
}
