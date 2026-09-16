#!/usr/bin/env bats

load test_helper

# cmd_init is an interactive wizard: every test feeds the full stdin script
# the prompts expect (name, workspace, extra workspace, ssh alias, key path,
# git name, git email, then the follow-up questions).
setup_init_command() {
  source "$PROJECT_ROOT/lib/commands/init.sh"
  source "$PROJECT_ROOT/lib/commands/apply.sh"
}

@test "init cancels when configuration already exists and user declines" {
  create_test_state
  save_state
  setup_init_command

  run cmd_init <<< "n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists"* ]]
  [[ "$output" == *"cancelled"* ]]

  # Existing config is left untouched.
  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 1 ]
  [ "$(jq -r '.accounts[0].id' "$CONFIG_FILE")" = "personal" ]
}

@test "init wizard creates the config file and first account" {
  setup_init_command

  local input
  input=$(printf '%s\n' "first" "" "" "" "" "First User" "first@example.com" "n" "n")
  run cmd_init <<< "$input"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Initialization complete"* ]]

  [ -f "$CONFIG_FILE" ]
  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 1 ]
  [ "$(jq -r '.accounts[0].id' "$CONFIG_FILE")" = "first" ]
  [ "$(jq -r '.accounts[0].ssh_alias' "$CONFIG_FILE")" = "gh-first" ]
  [ "$(jq -r '.accounts[0].git_email' "$CONFIG_FILE")" = "first@example.com" ]

  # The single account becomes the default global Git identity.
  [ "$(git config --global --get user.name)" = "First User" ]
  [ "$(git config --global --get user.email)" = "first@example.com" ]
}

@test "init wizard can add a second account and select the default" {
  setup_init_command

  local input
  input=$(printf '%s\n' \
    "one" "" "" "" "" "User One" "one@example.com" \
    "y" \
    "two" "" "" "" "" "User Two" "two@example.com" \
    "n" "2" "n")
  run cmd_init <<< "$input"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Initialization complete"* ]]

  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 2 ]
  [ "$(jq -r '.accounts[1].id' "$CONFIG_FILE")" = "two" ]

  # Account picked in the default-account menu drives the global identity.
  [ "$(git config --global --get user.email)" = "two@example.com" ]
}
