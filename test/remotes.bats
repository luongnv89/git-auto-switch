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

@test "rewrite_repo_remotes converts ssh:// remote to SSH alias" {
  create_test_state
  save_state

  setup_git_repo_with_remote "$HOME/workspace/personal/repo1" "ssh://git@github.com/user/repo.git"

  cd "$HOME/workspace/personal/repo1"

  rewrite_repo_remotes "$HOME/workspace/personal/repo1" "gh-personal"

  local new_url
  new_url=$(git remote get-url origin)
  [ "$new_url" = "git@gh-personal:user/repo.git" ]
}

@test "rewrite_repo_remotes skips ssh:// non-github remotes" {
  create_test_state
  save_state

  setup_git_repo_with_remote "$HOME/workspace/personal/repo1" "ssh://git@gitlab.com/user/repo.git"

  cd "$HOME/workspace/personal/repo1"

  rewrite_repo_remotes "$HOME/workspace/personal/repo1" "gh-personal"

  local new_url
  new_url=$(git remote get-url origin)
  # Should remain unchanged
  [ "$new_url" = "ssh://git@gitlab.com/user/repo.git" ]
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

@test "find_git_repos walks a workspace only once while the cache is fresh (F-PERF-002)" {
  create_test_state
  save_state
  setup_find_stub

  local ws="$HOME/workspace/personal"
  setup_git_repo_with_remote "$ws/repo1" "git@github.com:user/repo1.git"
  setup_git_repo_with_remote "$ws/repo2" "git@github.com:user/repo2.git"
  cd "$HOME"

  PATH="$STUB_BIN:$PATH" find_git_repos "$ws"
  PATH="$STUB_BIN:$PATH" find_git_repos "$ws"

  [ "$(find_call_count)" -eq 1 ]
}

@test "find_git_repos returns the same repository list from cache" {
  create_test_state
  save_state
  setup_find_stub

  local ws="$HOME/workspace/personal"
  setup_git_repo_with_remote "$ws/repo1" "git@github.com:user/repo1.git"
  setup_git_repo_with_remote "$ws/repo2" "git@github.com:user/repo2.git"
  cd "$HOME"

  local first second
  first=$(PATH="$STUB_BIN:$PATH" find_git_repos "$ws")
  second=$(PATH="$STUB_BIN:$PATH" find_git_repos "$ws")

  [ "$first" = "$second" ]
  echo "$second" | grep -q "repo1"
  echo "$second" | grep -q "repo2"
  [ "$(find_call_count)" -eq 1 ]
}

@test "find_git_repos shares one walk between rewrite_workspace_remotes and a repeat scan" {
  create_test_state
  save_state
  setup_find_stub

  local ws="$HOME/workspace/personal"
  setup_git_repo_with_remote "$ws/repo1" "git@github.com:user/repo1.git"
  cd "$HOME"

  PATH="$STUB_BIN:$PATH" rewrite_workspace_remotes "$ws" "gh-personal"
  PATH="$STUB_BIN:$PATH" find_git_repos "$ws"

  [ "$(find_call_count)" -eq 1 ]
}

@test "find_git_repos rescans when GAS_SCAN_CACHE_TTL=0 disables the cache" {
  create_test_state
  save_state
  setup_find_stub

  local ws="$HOME/workspace/personal"
  setup_git_repo_with_remote "$ws/repo1" "git@github.com:user/repo1.git"
  cd "$HOME"

  GAS_SCAN_CACHE_TTL=0 PATH="$STUB_BIN:$PATH" find_git_repos "$ws"
  GAS_SCAN_CACHE_TTL=0 PATH="$STUB_BIN:$PATH" find_git_repos "$ws"

  [ "$(find_call_count)" -eq 2 ]
}

@test "find_git_repos rescans after the cache TTL expires" {
  create_test_state
  save_state
  setup_find_stub

  local ws="$HOME/workspace/personal"
  setup_git_repo_with_remote "$ws/repo1" "git@github.com:user/repo1.git"
  cd "$HOME"

  PATH="$STUB_BIN:$PATH" find_git_repos "$ws"
  [ "$(find_call_count)" -eq 1 ]

  # Age the cache entry past the TTL by rewriting its header epoch.
  local cache_dir="$HOME/.git-auto-switch/cache/repo-scans"
  local entry
  entry=$(ls "$cache_dir" | head -n 1)
  {
    echo "# gas-repo-scan v1 1000000000"
    tail -n +2 "$cache_dir/$entry"
  } > "$cache_dir/$entry.aged"
  mv "$cache_dir/$entry.aged" "$cache_dir/$entry"

  PATH="$STUB_BIN:$PATH" find_git_repos "$ws"
  [ "$(find_call_count)" -eq 2 ]
}

@test "find_git_repos caches an empty workspace scan" {
  create_test_state
  save_state
  setup_find_stub

  local ws="$HOME/workspace/personal"
  mkdir -p "$ws"
  cd "$HOME"

  local first second
  first=$(PATH="$STUB_BIN:$PATH" find_git_repos "$ws")
  second=$(PATH="$STUB_BIN:$PATH" find_git_repos "$ws")

  [ -z "$first" ]
  [ -z "$second" ]
  [ "$(find_call_count)" -eq 1 ]
}

@test "find_git_repos ignores a cache entry written for another workspace" {
  create_test_state
  save_state
  setup_find_stub

  local ws="$HOME/workspace/personal"
  local other="$HOME/workspace/other"
  setup_git_repo_with_remote "$ws/repo1" "git@github.com:user/repo1.git"
  setup_git_repo_with_remote "$other/repo2" "git@github.com:user/repo2.git"
  cd "$HOME"

  # Forge a cache file for $ws whose recorded dir is $other (collision guard).
  local cache_dir="$HOME/.git-auto-switch/cache/repo-scans"
  mkdir -p "$cache_dir"
  local key
  key=$(printf '%s' "$ws" | cksum | tr ' ' '-')
  {
    printf '# gas-repo-scan v1 %s\n' "$(date +%s)"
    printf '%s\n' "$other"
    printf '%s\n' "$other/repo2"
  } > "$cache_dir/scan-$key"

  local repos
  repos=$(PATH="$STUB_BIN:$PATH" find_git_repos "$ws")

  [ "$(find_call_count)" -eq 1 ]
  echo "$repos" | grep -q "personal/repo1"
  ! echo "$repos" | grep -q "other/repo2"
}
