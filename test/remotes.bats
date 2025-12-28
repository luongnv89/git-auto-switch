#!/usr/bin/env bats

load test_helper

setup_git_repo_with_remote() {
  local repo_path="$1"
  local remote_url="$2"

  mkdir -p "$repo_path"
  cd "$repo_path"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
  git remote add origin "$remote_url"
}

@test "rewrite_repo_remotes converts github.com to SSH alias" {
  create_test_state
  save_state

  setup_git_repo_with_remote "$HOME/workspace/personal/repo1" "git@github.com:user/repo.git"

  cd "$HOME/workspace/personal/repo1"

  rewrite_repo_remotes "$HOME/workspace/personal/repo1" "gh-personal"

  local new_url
  new_url=$(git remote get-url origin)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
}

@test "rewrite_repo_remotes converts HTTPS to SSH" {
  create_test_state
  save_state

  setup_git_repo_with_remote "$HOME/workspace/personal/repo1" "https://github.com/user/repo.git"

  cd "$HOME/workspace/personal/repo1"

  rewrite_repo_remotes "$HOME/workspace/personal/repo1" "gh-personal"

  local new_url
  new_url=$(git remote get-url origin)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
}

@test "rewrite_repo_remotes handles URL without .git suffix" {
  create_test_state
  save_state

  setup_git_repo_with_remote "$HOME/workspace/personal/repo1" "git@github.com:user/repo"

  cd "$HOME/workspace/personal/repo1"

  rewrite_repo_remotes "$HOME/workspace/personal/repo1" "gh-personal"

  local new_url
  new_url=$(git remote get-url origin)
  [ "$new_url" = "git@gh-personal:user/repo" ]
}

@test "rewrite_repo_remotes skips non-github remotes" {
  create_test_state
  save_state

  setup_git_repo_with_remote "$HOME/workspace/personal/repo1" "git@gitlab.com:user/repo.git"

  cd "$HOME/workspace/personal/repo1"

  rewrite_repo_remotes "$HOME/workspace/personal/repo1" "gh-personal"

  local new_url
  new_url=$(git remote get-url origin)
  # Should remain unchanged
  [ "$new_url" = "git@gitlab.com:user/repo.git" ]
}

@test "rewrite_all_remotes processes multiple workspaces" {
  init_state
  add_account "dev" "Developer" "gh-dev" "$HOME/.ssh/id_dev" \
    '["'"$HOME"'/workspace/a", "'"$HOME"'/workspace/b"]' "Dev User" "dev@example.com"
  save_state

  setup_git_repo_with_remote "$HOME/workspace/a/repo1" "git@github.com:user/repo1.git"
  setup_git_repo_with_remote "$HOME/workspace/b/repo2" "git@github.com:user/repo2.git"

  rewrite_all_remotes

  cd "$HOME/workspace/a/repo1"
  local url1
  url1=$(git remote get-url origin)
  [ "$url1" = "git@gh-dev:user/repo1.git" ]

  cd "$HOME/workspace/b/repo2"
  local url2
  url2=$(git remote get-url origin)
  [ "$url2" = "git@gh-dev:user/repo2.git" ]
}
