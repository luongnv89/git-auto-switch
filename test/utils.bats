#!/usr/bin/env bats

load test_helper

@test "expand_path expands tilde" {
  local result
  result=$(expand_path "~/test")
  [ "$result" = "$HOME/test" ]
}

@test "expand_path handles absolute paths" {
  local result
  result=$(expand_path "/absolute/path")
  [ "$result" = "/absolute/path" ]
}

@test "validate_email accepts valid emails" {
  run validate_email "user@example.com"
  [ "$status" -eq 0 ]

  run validate_email "user.name+tag@sub.domain.com"
  [ "$status" -eq 0 ]
}

@test "validate_email rejects invalid emails" {
  run validate_email "not-an-email"
  [ "$status" -eq 1 ]

  run validate_email "@missing-local.com"
  [ "$status" -eq 1 ]

  run validate_email "missing@domain"
  [ "$status" -eq 1 ]
}

@test "validate_ssh_alias accepts valid aliases" {
  run validate_ssh_alias "gh-work"
  [ "$status" -eq 0 ]

  run validate_ssh_alias "github_personal"
  [ "$status" -eq 0 ]
}

@test "validate_ssh_alias rejects invalid aliases" {
  run validate_ssh_alias "123invalid"
  [ "$status" -eq 1 ]

  run validate_ssh_alias "has spaces"
  [ "$status" -eq 1 ]
}

@test "generate_id creates safe ID from label" {
  local result
  result=$(generate_id "Work Account")
  [ "$result" = "work-account" ]

  result=$(generate_id "Personal GitHub")
  [ "$result" = "personal-github" ]
}
