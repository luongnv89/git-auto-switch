#!/usr/bin/env bats

load test_helper

# Interactive prompt helpers feed stdin via herestrings, which keeps the call
# in the current shell so the PROMPT_*/ACCOUNT_* globals stay observable.

@test "prompt_account_name sets PROMPT_NAME for a valid name" {
  init_state

  prompt_account_name <<< "myacct" >/dev/null 2>&1
  [ "$PROMPT_NAME" = "myacct" ]
}

@test "prompt_account_name retries until a valid name is given" {
  init_state

  prompt_account_name <<< $'bad name!\nmyacct' >/dev/null 2>&1
  [ "$PROMPT_NAME" = "myacct" ]
}

@test "prompt_account_workspaces collects default plus extras until empty" {
  init_state
  PROMPT_NAME="testy"
  PROMPT_WORKSPACES=()

  prompt_account_workspaces <<< $'\n~/extra\n\n' >/dev/null 2>&1
  [ "${#PROMPT_WORKSPACES[@]}" -eq 2 ]
  [ "${PROMPT_WORKSPACES[0]}" = "$HOME/workspace/testy" ]
  [ "${PROMPT_WORKSPACES[1]}" = "~/extra" ]
}

@test "prompt_account_ssh_alias defaults to gh-<name>" {
  init_state
  PROMPT_NAME="testy"

  prompt_account_ssh_alias <<< "" >/dev/null 2>&1
  [ "$PROMPT_SSH_ALIAS" = "gh-testy" ]
}

@test "prompt_account_ssh_alias retries on invalid input" {
  init_state
  PROMPT_NAME="testy"

  prompt_account_ssh_alias <<< $'bad alias!\ngh-ok' >/dev/null 2>&1
  [ "$PROMPT_SSH_ALIAS" = "gh-ok" ]
}

@test "prompt_account_ssh_key defaults inside the first workspace" {
  init_state
  PROMPT_WORKSPACES=("~/ws")

  prompt_account_ssh_key <<< "" >/dev/null 2>&1
  [ "$PROMPT_SSH_KEY_PATH" = "~/ws/.ssh/id_ed25519" ]
}

@test "prompt_account_git_identity requires name and validates email" {
  init_state

  prompt_account_git_identity <<< $'\nJane\nbad-email\njane@example.com' >/dev/null 2>&1
  [ "$PROMPT_GIT_NAME" = "Jane" ]
  [ "$PROMPT_GIT_EMAIL" = "jane@example.com" ]
}

@test "render_account_summary lists every collected field" {
  init_state
  PROMPT_NAME="testy"
  PROMPT_WORKSPACES=("~/a" "~/b")
  PROMPT_SSH_ALIAS="gh-testy"
  PROMPT_SSH_KEY_PATH="~/a/.ssh/id_ed25519"
  PROMPT_GIT_NAME="Jane"
  PROMPT_GIT_EMAIL="jane@example.com"

  run render_account_summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Account name:   testy"* ]]
  [[ "$output" == *"[0] ~/a"* ]]
  [[ "$output" == *"[1] ~/b"* ]]
  [[ "$output" == *"SSH alias:      gh-testy"* ]]
  [[ "$output" == *"Git user.email: jane@example.com"* ]]
}

@test "build_workspaces_json renders a JSON array" {
  init_state
  PROMPT_WORKSPACES=("~/a" "~/b")

  local result
  result=$(build_workspaces_json)
  [ "$result" = '["~/a","~/b"]' ]
  echo "$result" | jq -e 'length == 2 and .[1] == "~/b"' >/dev/null
}

@test "validate_account_candidate counts a duplicate account as an issue" {
  create_test_state
  PROMPT_NAME="personal"
  PROMPT_WORKSPACES=("$HOME/ws")
  PROMPT_SSH_KEY_PATH="$HOME/.ssh/missing_key"

  validate_account_candidate >/dev/null 2>&1
  [ "$PROMPT_ISSUES" -eq 1 ]
}

@test "validate_account_candidate reports zero issues for a fresh account" {
  init_state
  PROMPT_NAME="newacct"
  PROMPT_WORKSPACES=("$HOME/ws")
  PROMPT_SSH_KEY_PATH="$HOME/.ssh/missing_key"

  validate_account_candidate >/dev/null 2>&1
  [ "$PROMPT_ISSUES" -eq 0 ]
}

@test "fix_menu_workspace_remove refuses to drop the last workspace" {
  init_state
  PROMPT_WORKSPACES=("~/only")

  fix_menu_workspace_remove <<< "0" >/dev/null 2>&1
  [ "${#PROMPT_WORKSPACES[@]}" -eq 1 ]
}

@test "fix_menu_workspace_remove drops a workspace by index" {
  init_state
  PROMPT_WORKSPACES=("~/a" "~/b" "~/c")

  fix_menu_workspace_remove <<< "1" >/dev/null 2>&1
  [ "${#PROMPT_WORKSPACES[@]}" -eq 2 ]
  [ "${PROMPT_WORKSPACES[0]}" = "~/a" ]
  [ "${PROMPT_WORKSPACES[1]}" = "~/c" ]
}

@test "fix_menu_workspaces adds a workspace then finishes" {
  init_state
  PROMPT_WORKSPACES=("~/a")

  fix_menu_workspaces <<< $'a\n~/added\nd' >/dev/null 2>&1
  [ "${#PROMPT_WORKSPACES[@]}" -eq 2 ]
  [ "${PROMPT_WORKSPACES[1]}" = "~/added" ]
}

@test "fix_menu_edit_name rejects an invalid replacement" {
  init_state
  PROMPT_NAME="old"

  fix_menu_edit_name <<< "bad name!" >/dev/null 2>&1
  [ "$PROMPT_NAME" = "old" ]
}

@test "fix_account_menu returns 1 on abort" {
  init_state

  run fix_account_menu <<< "a"
  [ "$status" -eq 1 ]
}

@test "prompt_account_info sets ACCOUNT_* globals on clean input" {
  init_state

  prompt_account_info <<EOF >/dev/null 2>&1
e2eacct

~/extra



E2E User
e2e@example.com
EOF

  [ "$ACCOUNT_ID" = "e2eacct" ]
  [ "$ACCOUNT_NAME" = "e2eacct" ]
  [ "$ACCOUNT_SSH_ALIAS" = "gh-e2eacct" ]
  [ "$ACCOUNT_SSH_KEY_PATH" = "$HOME/workspace/e2eacct/.ssh/id_ed25519" ]
  [ "$ACCOUNT_WORKSPACES_JSON" = "[\"$HOME/workspace/e2eacct\",\"~/extra\"]" ]
  [ "$ACCOUNT_GIT_NAME" = "E2E User" ]
  [ "$ACCOUNT_GIT_EMAIL" = "e2e@example.com" ]
}

@test "prompt_account_info fix-menu path repairs a duplicate name" {
  create_test_state

  prompt_account_info <<EOF >/dev/null 2>&1
personal




Jane
jane@example.com
1
newacct
EOF

  [ "$ACCOUNT_NAME" = "newacct" ]
  [ "$ACCOUNT_ID" = "newacct" ]
}

@test "prompt_account_info returns 1 when aborted from the fix menu" {
  create_test_state

  run prompt_account_info <<EOF
personal




Jane
jane@example.com
a
EOF
  [ "$status" -eq 1 ]
}
