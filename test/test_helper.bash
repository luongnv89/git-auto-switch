#!/usr/bin/env bash

# Set up test environment
setup() {
  # Create temporary directory for each test
  TEST_TEMP_DIR="$(mktemp -d)"
  export HOME="$TEST_TEMP_DIR/home"
  mkdir -p "$HOME/.ssh"
  mkdir -p "$HOME/workspace"

  # Source the project
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export PROJECT_ROOT
  export INSTALL_DIR="$PROJECT_ROOT"
  export BACKUP_DIR="$TEST_TEMP_DIR/backup"
  mkdir -p "$BACKUP_DIR"
}

teardown() {
  # Clean up temp directory
  if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}
