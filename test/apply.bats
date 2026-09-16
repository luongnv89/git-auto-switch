#!/usr/bin/env bats

load test_helper

# Source the apply command for cmd_apply / apply_to_current_repo
setup_apply_command() {
  source "$PROJECT_ROOT/lib/commands/apply.sh"
}

setup_test_repo() {
  local repo_path="$1"
  local remote_url="$2"

  mkdir -p "$repo_path"
  cd "$repo_path"
  git init -q
  git config user.name "Initial Name"
  git config user.email "initial@example.com"
  if [[ -n "$remote_url" ]]; then
    git remote add origin "$remote_url"
  fi
}

@test "apply <id> sets local git identity in current repository" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@github.com:user/repo.git"
  cd "$HOME/some/repo"

  run apply_to_current_repo "personal"
  [ "$status" -eq 0 ]

  local local_name local_email
  local_name=$(git -C "$HOME/some/repo" config --local --get user.name)
  local_email=$(git -C "$HOME/some/repo" config --local --get user.email)
  [ "$local_name" = "John Doe" ]
  [ "$local_email" = "john@personal.com" ]
}

@test "apply <id> rewrites github.com origin to use SSH alias" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@github.com:user/repo.git"
  cd "$HOME/some/repo"

  run apply_to_current_repo "personal"
  [ "$status" -eq 0 ]

  local new_url
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
}

@test "apply <id> converts HTTPS origin to SSH with alias" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "https://github.com/user/repo.git"
  cd "$HOME/some/repo"

  run apply_to_current_repo "personal"
  [ "$status" -eq 0 ]

  local new_url
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
}

@test "apply <id> succeeds in repository without origin remote" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" ""
  cd "$HOME/some/repo"

  run apply_to_current_repo "personal"
  [ "$status" -eq 0 ]

  local local_email
  local_email=$(git -C "$HOME/some/repo" config --local --get user.email)
  [ "$local_email" = "john@personal.com" ]
}

@test "apply <id> works from a subdirectory of the repository" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@github.com:user/repo.git"
  mkdir -p "$HOME/some/repo/src/nested"
  cd "$HOME/some/repo/src/nested"

  run apply_to_current_repo "personal"
  [ "$status" -eq 0 ]

  local local_email new_url
  local_email=$(git -C "$HOME/some/repo" config --local --get user.email)
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  [ "$local_email" = "john@personal.com" ]
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
}

@test "apply <id> fails when account does not exist" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@github.com:user/repo.git"
  cd "$HOME/some/repo"

  run apply_to_current_repo "nonexistent"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]

  # Local config should not have been touched.
  local local_email
  local_email=$(git -C "$HOME/some/repo" config --local --get user.email)
  [ "$local_email" = "initial@example.com" ]
}

@test "apply <id> fails when not in a git repository" {
  create_test_state
  save_state
  setup_apply_command

  mkdir -p "$HOME/not-a-repo"
  cd "$HOME/not-a-repo"

  run apply_to_current_repo "personal"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not in a git repository"* ]]
}

@test "apply <id> leaves non-github remotes unchanged" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@gitlab.com:user/repo.git"
  cd "$HOME/some/repo"

  run apply_to_current_repo "personal"
  [ "$status" -eq 0 ]

  local new_url
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  [ "$new_url" = "git@gitlab.com:user/repo.git" ]
}

@test "apply accepts ssh_alias instead of account id" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@github.com:user/repo.git"
  cd "$HOME/some/repo"

  # 'gh-personal' is the ssh_alias of the 'personal' account
  run apply_to_current_repo "gh-personal"
  [ "$status" -eq 0 ]

  local new_url local_email
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  local_email=$(git -C "$HOME/some/repo" config --local --get user.email)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
  [ "$local_email" = "john@personal.com" ]
}

@test "cmd_apply <id> dispatches to the per-repo branch" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@github.com:user/repo.git"
  cd "$HOME/some/repo"

  run cmd_apply "personal"
  [ "$status" -eq 0 ]

  local new_url
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
}

@test "cmd_apply <ssh_alias> dispatches and resolves the account" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@github.com:user/repo.git"
  cd "$HOME/some/repo"

  # The documented invocation: pass the SSH alias instead of the id
  run cmd_apply "gh-personal"
  [ "$status" -eq 0 ]

  local new_url local_email
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  local_email=$(git -C "$HOME/some/repo" config --local --get user.email)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
  [ "$local_email" = "john@personal.com" ]
}

@test "apply <id> switches an already-aliased remote to a different alias" {
  init_state
  add_account "personal" "Personal" "gh-personal" "$HOME/.ssh/id_personal" \
    '["'"$HOME"'/workspace/personal"]' "John Doe" "john@personal.com"
  add_account "work" "Work" "gh-work" "$HOME/.ssh/id_work" \
    '["'"$HOME"'/workspace/work"]' "John Work" "john@work.com"
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@gh-personal:user/repo.git"
  cd "$HOME/some/repo"

  run apply_to_current_repo "work"
  [ "$status" -eq 0 ]

  local new_url local_email
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  local_email=$(git -C "$HOME/some/repo" config --local --get user.email)
  [ "$new_url" = "git@gh-work:user/repo.git" ]
  [ "$local_email" = "john@work.com" ]
}

setup_ssh_keygen_mock() {
  export SSH_KEYGEN_ARGS_FILE="$HOME/ssh-keygen-args"
  rm -f "$SSH_KEYGEN_ARGS_FILE"
  ssh-keygen() {
    local prev="" n="__UNSET__" f=""
    local a
    for a in "$@"; do
      if [[ "$prev" == "-N" ]]; then
        n="$a"
      fi
      if [[ "$prev" == "-f" ]]; then
        f="$a"
      fi
      prev="$a"
    done
    echo "N=[$n]" >> "$SSH_KEYGEN_ARGS_FILE"
    if [[ -n "$f" ]]; then
      mkdir -p "$(dirname "$f")"
      echo "PRIVATE" > "$f"
      chmod 600 "$f"
      echo "ssh-ed25519 FAKE $f" > "$f.pub"
    fi
    return 0
  }
  export -f ssh-keygen
}

@test "ensure_ssh_key generates encrypted key when GAS_SSH_PASSPHRASE is set" {
  create_test_state
  export GAS_SSH_PASSPHRASE="s3cr3t-pass"
  unset GAS_NO_PASSPHRASE || true
  setup_ssh_keygen_mock

  local account
  account=$(get_account "personal")

  run ensure_ssh_key "$account"
  [ "$status" -eq 0 ]
  grep -q "N=\[s3cr3t-pass\]" "$SSH_KEYGEN_ARGS_FILE"
  [[ "$output" == *"encrypted"* ]]
}

@test "ensure_ssh_key generates unencrypted key only with explicit --no-passphrase" {
  create_test_state
  unset GAS_SSH_PASSPHRASE || true
  unset GAS_NO_PASSPHRASE || true
  setup_ssh_keygen_mock

  local account
  account=$(get_account "personal")

  run ensure_ssh_key "$account" "--no-passphrase"
  [ "$status" -eq 0 ]
  grep -q "N=\[\]" "$SSH_KEYGEN_ARGS_FILE"
  [[ "$output" == *"NENCRYPTED"* ]]
}

@test "ensure_ssh_key refuses unencrypted key without explicit opt-out when non-interactive" {
  create_test_state
  unset GAS_SSH_PASSPHRASE || true
  unset GAS_NO_PASSPHRASE || true
  setup_ssh_keygen_mock

  local account
  account=$(get_account "personal")

  run ensure_ssh_key "$account"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--no-passphrase"* ]]
  [ ! -f "$SSH_KEYGEN_ARGS_FILE" ]
}

@test "apply <id> converts ssh:// origin to SSH alias" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "ssh://git@github.com/user/repo.git"
  cd "$HOME/some/repo"

  run apply_to_current_repo "personal"
  [ "$status" -eq 0 ]

  local new_url
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
}

@test "apply <id> normalizes an ssh:// aliased remote to the target alias" {
  init_state
  add_account "personal" "Personal" "gh-personal" "$HOME/.ssh/id_personal" \
    '["'"$HOME"'/workspace/personal"]' "John Doe" "john@personal.com"
  add_account "work" "Work" "gh-work" "$HOME/.ssh/id_work" \
    '["'"$HOME"'/workspace/work"]' "John Work" "john@work.com"
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "ssh://git@gh-personal/user/repo.git"
  cd "$HOME/some/repo"

  run apply_to_current_repo "work"
  [ "$status" -eq 0 ]

  local new_url local_email
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  local_email=$(git -C "$HOME/some/repo" config --local --get user.email)
  [ "$new_url" = "git@gh-work:user/repo.git" ]
  [ "$local_email" = "john@work.com" ]
}

@test "apply <id> is idempotent when run twice" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@github.com:user/repo.git"
  cd "$HOME/some/repo"

  run apply_to_current_repo "personal"
  [ "$status" -eq 0 ]

  run apply_to_current_repo "personal"
  [ "$status" -eq 0 ]

  local new_url local_email
  new_url=$(git -C "$HOME/some/repo" remote get-url origin)
  local_email=$(git -C "$HOME/some/repo" config --local --get user.email)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
  [ "$local_email" = "john@personal.com" ]
}

@test "apply + audit --fix performs one workspace walk on a 50-repo fixture (F-PERF-002)" {
  create_test_state
  save_state
  setup_apply_command
  source "$PROJECT_ROOT/lib/commands/audit.sh"
  setup_find_stub

  # 50 repositories inside the single configured workspace.
  local ws="$HOME/workspace/personal"
  local i
  for i in $(seq 1 50); do
    setup_test_repo "$ws/repo$i" "git@github.com:user/repo$i.git"
  done
  cd "$HOME"

  # ensure_ssh_key skips generation (and its prompt) when the file exists.
  touch "$HOME/.ssh/id_personal"

  PATH="$STUB_BIN:$PATH" run cmd_apply
  [ "$status" -eq 0 ]

  # audit --fix reports (and fixes) the initial email mismatches -> exit 1.
  PATH="$STUB_BIN:$PATH" run cmd_audit --fix
  [ "$status" -eq 1 ]
  [[ "$output" == *"Audit Summary"* ]]

  # One find(1) invocation total: apply's walk is reused by audit --fix.
  [ "$(find_call_count)" -eq 1 ]
}

# --- Non-interactive safety (issue #29) ---
# Since #47, key generation non-interactively requires an explicit
# unencrypted-key opt-out — GAS_NO_PASSPHRASE=true is the test hook.

@test "ensure_ssh_key </dev/null> generates the key and returns 0 without pausing" {
  create_test_state
  export GAS_NO_PASSPHRASE=true
  local account
  account=$(get_account_by_index 0)

  run ensure_ssh_key "$account" </dev/null
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_personal" ]
  [[ "$output" != *"Press Enter"* ]]
}

@test "ensure_ssh_key does not block on a held-open non-TTY stdin" {
  create_test_state
  export GAS_NO_PASSPHRASE=true
  local account
  account=$(get_account_by_index 0)

  run assert_completes_within 15 ensure_ssh_key "$account" < <(sleep 30)
  [ "$status" -eq 0 ]
}

@test "cmd_apply </dev/null> completes a full system apply without prompting" {
  create_test_state
  export GAS_NO_PASSPHRASE=true
  save_state
  setup_apply_command

  run cmd_apply </dev/null
  [ "$status" -eq 0 ]
  # A missing key was generated without the interactive pause
  [ -f "$HOME/.ssh/id_personal" ]
  [[ "$output" != *"Press Enter"* ]]
  [[ "$output" == *"Non-interactive mode"* ]]
  [[ "$output" == *"Configuration applied successfully"* ]]
}

@test "cmd_apply does not block on a held-open non-TTY stdin" {
  create_test_state
  export GAS_NO_PASSPHRASE=true
  save_state
  setup_apply_command

  run assert_completes_within 15 cmd_apply < <(sleep 30)
  [ "$status" -eq 0 ]
}

@test "cmd_apply --no-prompt completes without the confirmation pause" {
  create_test_state
  export GAS_NO_PASSPHRASE=true
  save_state
  setup_apply_command

  run cmd_apply --no-prompt
  [ "$status" -eq 0 ]
  [[ "$output" != *"Press Enter"* ]]
  [[ "$output" == *"Configuration applied successfully"* ]]
}

@test "cmd_apply --yes completes without the confirmation pause" {
  create_test_state
  export GAS_NO_PASSPHRASE=true
  save_state
  setup_apply_command

  run cmd_apply --yes
  [ "$status" -eq 0 ]
  [[ "$output" != *"Press Enter"* ]]
  [[ "$output" == *"Configuration applied successfully"* ]]
}

@test "cmd_apply accepts flags around the positional account key" {
  create_test_state
  save_state
  setup_apply_command

  setup_test_repo "$HOME/some/repo" "git@github.com:user/repo.git"
  cd "$HOME/some/repo"

  run cmd_apply --yes "personal"
  [ "$status" -eq 0 ]
  [ "$(git -C "$HOME/some/repo" config --local --get user.email)" = "john@personal.com" ]

  run cmd_apply "personal" --no-prompt
  [ "$status" -eq 0 ]
}

@test "cmd_apply rejects unknown options and extra arguments" {
  create_test_state
  save_state
  setup_apply_command

  run cmd_apply --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option"* ]]

  run cmd_apply one two
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unexpected extra argument"* ]]
}
