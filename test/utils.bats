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

@test "expand_path strips a trailing slash" {
  local result
  result=$(expand_path "$HOME/workspace/")
  [ "$result" = "$HOME/workspace" ]
}

@test "expand_path strips repeated trailing slashes" {
  local result
  result=$(expand_path "$HOME/workspace///")
  [ "$result" = "$HOME/workspace" ]
}

@test "expand_path keeps the root slash" {
  local result
  result=$(expand_path "/")
  [ "$result" = "/" ]
}

@test "expand_path expands tilde and strips trailing slash together" {
  local result
  result=$(expand_path "~/workspace/")
  [ "$result" = "$HOME/workspace" ]
}

@test "expand_path leaves a mid-path tilde literal" {
  local result
  result=$(expand_path "/data/~archive")
  [ "$result" = "/data/~archive" ]
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

@test "create_backup keeps backup dir and copies owner-only" {
  echo "user.email=x@y.z" > "$HOME/.gitconfig"
  create_backup "$HOME/.gitconfig" "gitconfig"

  local backup_dir
  backup_dir=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
  [ -n "$backup_dir" ]
  [ "$(file_mode "$backup_dir")" = "700" ]
  [ "$(file_mode "$backup_dir/gitconfig")" = "600" ]
}
