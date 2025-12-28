#!/usr/bin/env bash

# Set up test environment
setup() {
  # Create temporary directory for each test
  TEST_TEMP_DIR="$(mktemp -d)"
  export HOME="$TEST_TEMP_DIR/home"
  mkdir -p "$HOME/.ssh"
  mkdir -p "$HOME/workspace"
  mkdir -p "$HOME/.git-auto-switch"

  # Source the project
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export PROJECT_ROOT

  # Source core modules
  source "$PROJECT_ROOT/lib/core/constants.sh"
  source "$PROJECT_ROOT/lib/core/logger.sh"
  source "$PROJECT_ROOT/lib/core/utils.sh"

  # Source state modules
  source "$PROJECT_ROOT/lib/state/state.sh"
  source "$PROJECT_ROOT/lib/state/account.sh"

  # Source generators
  source "$PROJECT_ROOT/lib/generators/ssh_config.sh"
  source "$PROJECT_ROOT/lib/generators/git_config.sh"
  source "$PROJECT_ROOT/lib/generators/hooks.sh"

  # Source applicators
  source "$PROJECT_ROOT/lib/applicators/ssh.sh"
  source "$PROJECT_ROOT/lib/applicators/git.sh"
  source "$PROJECT_ROOT/lib/applicators/hooks.sh"
  source "$PROJECT_ROOT/lib/applicators/remotes.sh"
}

teardown() {
  # Clean up temp directory
  if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Helper to create a test state
create_test_state() {
  init_state
  add_account "personal" "Personal" "gh-personal" "$HOME/.ssh/id_personal" \
    "$HOME/workspace/personal" "John Doe" "john@personal.com"
}
