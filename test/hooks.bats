#!/usr/bin/env bats

load test_helper

@test "generate_pre_commit_hook contains correct config path" {
  local hook_content
  hook_content=$(generate_pre_commit_hook)

  echo "$hook_content" | grep -q "CONFIG_FILE="
  echo "$hook_content" | grep -q ".git-auto-switch/config.json"
}

@test "generate_pre_commit_hook checks workspaces array" {
  local hook_content
  hook_content=$(generate_pre_commit_hook)

  # Should use .workspaces[] not .workspace
  echo "$hook_content" | grep -q ".workspaces\[\]"
}

@test "generate_pre_commit_hook exits 0 for unmanaged repos" {
  local hook_content
  hook_content=$(generate_pre_commit_hook)

  # Check for early exit when no matching workspace
  echo "$hook_content" | grep -q 'if \[\[ -z "\$expected_email" \]\]'
  echo "$hook_content" | grep -q "exit 0"
}

@test "apply_pre_commit_hook creates executable hook" {
  create_test_state

  apply_pre_commit_hook

  # Check hook exists
  [ -f "$HOOKS_DIR/pre-commit" ]

  # Check hook is executable
  [ -x "$HOOKS_DIR/pre-commit" ]
}

@test "apply_pre_commit_hook replaces existing hooks" {
  create_test_state

  # Create existing hook
  mkdir -p "$HOOKS_DIR"
  echo '#!/bin/bash' > "$HOOKS_DIR/pre-commit"
  echo 'echo "existing hook"' >> "$HOOKS_DIR/pre-commit"

  apply_pre_commit_hook

  # Check hook still exists and is our managed version
  [ -f "$HOOKS_DIR/pre-commit" ]
  grep -q "git-auto-switch" "$HOOKS_DIR/pre-commit"
}
