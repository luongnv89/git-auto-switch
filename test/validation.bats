#!/usr/bin/env bats

load test_helper

@test "validate_account_name accepts valid names" {
  run validate_account_name "personal"
  [ "$status" -eq 0 ]

  run validate_account_name "work-project"
  [ "$status" -eq 0 ]

  run validate_account_name "my_account"
  [ "$status" -eq 0 ]

  run validate_account_name "account123"
  [ "$status" -eq 0 ]
}

@test "validate_account_name rejects invalid names" {
  run validate_account_name ""
  [ "$status" -eq 1 ]

  run validate_account_name "has space"
  [ "$status" -eq 1 ]

  run validate_account_name "special@char"
  [ "$status" -eq 1 ]
}

@test "validate_ssh_alias accepts valid aliases" {
  run validate_ssh_alias "gh-personal"
  [ "$status" -eq 0 ]

  run validate_ssh_alias "github_work"
  [ "$status" -eq 0 ]
}

@test "validate_ssh_alias rejects invalid aliases" {
  run validate_ssh_alias ""
  [ "$status" -eq 1 ]

  run validate_ssh_alias "has space"
  [ "$status" -eq 1 ]
}

@test "validate_email accepts valid emails" {
  run validate_email "user@example.com"
  [ "$status" -eq 0 ]

  run validate_email "user.name@company.co.uk"
  [ "$status" -eq 0 ]

  run validate_email "user+tag@example.com"
  [ "$status" -eq 0 ]
}

@test "validate_email rejects invalid emails" {
  run validate_email ""
  [ "$status" -eq 1 ]

  run validate_email "notanemail"
  [ "$status" -eq 1 ]

  run validate_email "@example.com"
  [ "$status" -eq 1 ]

  run validate_email "user@"
  [ "$status" -eq 1 ]
}

@test "validate_state catches missing required fields" {
  init_state

  # Account missing git_email
  STATE_JSON=$(echo "$STATE_JSON" | jq '.accounts = [
    {"id": "test", "name": "Test", "ssh_alias": "gh-test", "workspaces": ["~/workspace"]}
  ]')

  run validate_state
  [ "$status" -eq 1 ]
}

@test "validate_state catches empty workspaces" {
  init_state

  STATE_JSON=$(echo "$STATE_JSON" | jq '.accounts = [
    {"id": "test", "name": "Test", "ssh_alias": "gh-test", "workspaces": [], "git_email": "a@a.com"}
  ]')

  run validate_state
  [ "$status" -eq 1 ]
}

@test "validate_state catches duplicate SSH aliases" {
  init_state

  STATE_JSON=$(echo "$STATE_JSON" | jq '.accounts = [
    {"id": "a1", "name": "Account 1", "ssh_alias": "gh-same", "workspaces": ["~/w1"], "git_email": "a@a.com"},
    {"id": "a2", "name": "Account 2", "ssh_alias": "gh-same", "workspaces": ["~/w2"], "git_email": "b@b.com"}
  ]')

  run validate_state
  [ "$status" -eq 1 ]
}

# --- Non-interactive safety (issue #29) ---

setup_validate_command() {
  source "$PROJECT_ROOT/lib/commands/validate.sh"
}

@test "cmd_validate </dev/null> completes without emitting the SSH prompt" {
  create_test_state
  save_state
  setup_validate_command

  run cmd_validate </dev/null
  # Validation runs to its summary even though errors exist (missing key etc.)
  [[ "$output" == *"Validation"* ]]
  # The interactive prompt must never be emitted on a non-TTY stdin
  [[ "$output" != *"Test SSH connection for"* ]]
  [[ "$output" == *"Skipping SSH connection test"* ]]
}

@test "cmd_validate does not block on a held-open non-TTY stdin" {
  create_test_state
  save_state
  setup_validate_command

  # stdin is a pipe that stays open for 30s without data: a regression to an
  # unguarded `read` would hang here; the watchdog bounds the test.
  run assert_completes_within 10 cmd_validate < <(sleep 30)
  [ "$status" -eq 0 ]
}

@test "cmd_validate --no-prompt skips the SSH connection test" {
  create_test_state
  save_state
  setup_validate_command

  run cmd_validate --no-prompt
  [[ "$output" != *"Test SSH connection for"* ]]
  [[ "$output" == *"Skipping SSH connection test"* ]]
}

@test "cmd_validate --check-ssh runs the SSH test without prompting" {
  create_test_state
  save_state
  setup_validate_command

  # Stub the live ssh call — flag plumbing is under test, not the network.
  validate_ssh_connection() { return 0; }

  run cmd_validate --check-ssh
  [[ "$output" != *"Test SSH connection for"* ]]
  [[ "$output" == *"SSH connection successful"* ]]
}

@test "cmd_validate --yes assumes yes for the SSH test without prompting" {
  create_test_state
  save_state
  setup_validate_command

  validate_ssh_connection() { return 0; }

  run cmd_validate --yes
  [[ "$output" != *"Test SSH connection for"* ]]
  [[ "$output" == *"SSH connection successful"* ]]
}

@test "cmd_validate rejects unknown options" {
  create_test_state
  save_state
  setup_validate_command

  run cmd_validate --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "gas validate </dev/null> still prints the failure summary under set -e" {
  create_test_state
  save_state

  # End-to-end through the real entry point: `set -euo pipefail` is only
  # active there, so a regression to unguarded ((errors++)) would abort the
  # run before the summary — invisible to the sourced-function tests above.
  run bash "$PROJECT_ROOT/git-auto-switch" validate </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Validation failed:"* ]]
  [[ "$output" == *"errors,"* ]]
  [[ "$output" != *"Test SSH connection for"* ]]
}
