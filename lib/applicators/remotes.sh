#!/usr/bin/env bash
# Rewrite repository remotes

# Find all git repositories in a directory
find_git_repos() {
  local directory="$1"
  local expanded_dir
  expanded_dir=$(expand_path "$directory")

  if [[ ! -d "$expanded_dir" ]]; then
    return 0
  fi

  # Find .git directories, limit depth for performance
  find "$expanded_dir" -maxdepth 5 -type d -name ".git" 2>/dev/null | while read -r git_dir; do
    dirname "$git_dir"
  done
}

# Rewrite remotes for a single repository
rewrite_repo_remotes() {
  local repo_path="$1"
  local ssh_alias="$2"

  local current_dir
  current_dir=$(pwd)

  cd "$repo_path" || return 1

  # Get current origin URL
  local origin_url
  origin_url=$(git remote get-url origin 2>/dev/null || echo "")

  if [[ -z "$origin_url" ]]; then
    cd "$current_dir" || return 0
    return 0
  fi

  # Only rewrite github.com URLs
  if [[ "$origin_url" == git@github.com:* ]]; then
    local new_url="${origin_url/github.com/$ssh_alias}"
    git remote set-url origin "$new_url"
    log_info "Rewrote remote in $repo_path"
    log_info "  Old: $origin_url"
    log_info "  New: $new_url"
  elif [[ "$origin_url" == https://github.com/* ]]; then
    # Convert HTTPS to SSH
    local repo_part="${origin_url#https://github.com/}"
    local new_url="git@$ssh_alias:$repo_part"
    git remote set-url origin "$new_url"
    log_info "Converted HTTPS to SSH in $repo_path"
    log_info "  Old: $origin_url"
    log_info "  New: $new_url"
  fi

  cd "$current_dir" || return 0
  return 0
}

# Rewrite all remotes in a workspace
rewrite_workspace_remotes() {
  local workspace="$1"
  local ssh_alias="$2"

  log_info "Rewriting remotes in workspace: $workspace"

  local repos
  repos=$(find_git_repos "$workspace")

  if [[ -z "$repos" ]]; then
    log_info "No repositories found in $workspace"
    return 0
  fi

  local count=0
  while IFS= read -r repo; do
    rewrite_repo_remotes "$repo" "$ssh_alias"
    ((count++)) || true
  done <<< "$repos"

  log_success "Processed $count repositories in $workspace"
}

# Rewrite remotes for all accounts
rewrite_all_remotes() {
  require_jq

  local account_count
  account_count=$(get_account_count)

  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")

    local ssh_alias workspaces_count
    ssh_alias=$(echo "$account" | jq -r '.ssh_alias')
    workspaces_count=$(echo "$account" | jq '.workspaces | length')

    for ((j=0; j<workspaces_count; j++)); do
      local workspace
      workspace=$(echo "$account" | jq -r ".workspaces[$j]")
      rewrite_workspace_remotes "$workspace" "$ssh_alias"
    done
  done
}
