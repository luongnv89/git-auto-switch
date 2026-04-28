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
