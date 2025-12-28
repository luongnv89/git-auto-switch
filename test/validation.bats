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
