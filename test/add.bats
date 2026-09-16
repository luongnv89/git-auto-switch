#!/usr/bin/env bats

load test_helper

# cmd_add runs the interactive prompt_account_info wizard and then calls
# cmd_apply, so tests feed stdin and pre-create key files where a real
# ssh-keygen pause would otherwise be required.
setup_add_command() {
  source "$PROJECT_ROOT/lib/commands/add.sh"
  source "$PROJECT_ROOT/lib/commands/apply.sh"
}

@test "add fails when git-auto-switch is not initialized" {
  setup_add_command

  run cmd_add <<< ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not initialized"* ]]
}

@test "add aborts cleanly when the account wizard is aborted" {
  create_test_state
  save_state
  setup_add_command

  # 'personal' already exists, so the wizard hits the fix-it menu; 'a' aborts.
  local input
  input=$(printf '%s\n' "personal" "" "" "" "" "Dup User" "dup@example.com" "a")
  run cmd_add <<< "$input"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cancelled"* ]]

  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 1 ]
}

@test "add wizard creates the account and applies configuration" {
  create_test_state
  save_state
  setup_add_command

  # Pre-create the existing account's key so cmd_apply only pauses once
  # (for the freshly generated key of the new account).
  touch "$HOME/.ssh/id_personal"

  local input
  input=$(printf '%s\n' "second" "" "" "" "" "Second User" "second@example.com" "" "n")
  run cmd_add <<< "$input"
  [ "$status" -eq 0 ]
  [[ "$output" == *"added successfully"* ]]

  [ "$(jq '.accounts | length' "$CONFIG_FILE")" -eq 2 ]
  [ "$(jq -r '.accounts[1].id' "$CONFIG_FILE")" = "second" ]
  [ "$(jq -r '.accounts[1].git_email' "$CONFIG_FILE")" = "second@example.com" ]

  # cmd_apply ran: SSH host alias, per-account gitconfig and the hook exist.
  grep -q "^Host gh-second" "$SSH_CONFIG"
  [ -f "$HOME/.gitconfig-second" ]
  [ -x "$HOOKS_DIR/pre-commit" ]
}
