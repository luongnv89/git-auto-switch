#!/usr/bin/env bash
# Rewrite repository remotes

# Repository scan cache — one `find` walk per workspace is shared by every
# caller (apply's rewrite_all_remotes, audit's cmd_audit) through a short-lived
# file under $CONFIG_DIR/cache/repo-scans/ (F-PERF-002). A cache hit younger
# than GAS_SCAN_CACHE_TTL seconds (default 300; 0 disables) reuses the
# previous list instead of re-walking the workspace.

# Path of the per-workspace scan cache file, keyed on the expanded workspace
# path. cksum keeps the name filesystem-safe; the recorded workspace inside the
# file is what actually validates a hit, so a hash collision only ever costs a
# re-walk, never wrong results.
repo_scan_cache_path() {
  local expanded_dir="$1"
  local key
  key=$(printf '%s' "$expanded_dir" | cksum | tr ' ' '-')
  printf '%s\n' "$CONFIG_DIR/cache/repo-scans/scan-$key"
}

# Emit the cached repository list iff it names this workspace and is younger
# than the TTL. Returns 0 on a hit, 1 on a miss.
repo_scan_cache_read() {
  local cache_file="$1"
  local expanded_dir="$2"
  local ttl="$3"

  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  local header recorded_dir
  {
    IFS= read -r header
    IFS= read -r recorded_dir
  } < "$cache_file" || return 1

  # Header format: "# gas-repo-scan v1 <epoch>"
  if [[ "$header" != "# gas-repo-scan v1 "* ]]; then
    return 1
  fi
  local epoch="${header##* }"
  if [[ ! "$epoch" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  if [[ "$recorded_dir" != "$expanded_dir" ]]; then
    return 1
  fi

  local now
  now=$(date +%s)
  if (( now - epoch >= ttl )); then
    return 1
  fi

  tail -n +3 "$cache_file"
}

# Write the repository list for a workspace atomically (tmp + mv). A cache
# failure never fails the caller — the scan result was already produced.
repo_scan_cache_write() {
  local cache_file="$1"
  local expanded_dir="$2"
  local repos="$3"

  if ! mkdir -p "$(dirname "$cache_file")" 2>/dev/null; then
    return 0
  fi

  local tmp_file="${cache_file}.$$.tmp"
  if {
    printf '# gas-repo-scan v1 %s\n' "$(date +%s)"
    printf '%s\n' "$expanded_dir"
    if [[ -n "$repos" ]]; then
      printf '%s\n' "$repos"
    fi
  } > "$tmp_file" 2>/dev/null && mv -f "$tmp_file" "$cache_file" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp_file" 2>/dev/null
  return 0
}

# Find all git repositories in a directory
find_git_repos() {
  local directory="$1"
  local expanded_dir
  expanded_dir=$(expand_path "$directory")
  expanded_dir="${expanded_dir%/}"

  if [[ ! -d "$expanded_dir" ]]; then
    return 0
  fi

  # Serve the scan from the cache when fresh so apply + audit --fix walk each
  # workspace once (F-PERF-002); GAS_SCAN_CACHE_TTL=0 disables the cache.
  local ttl="${GAS_SCAN_CACHE_TTL:-300}"
  local cache_file=""
  if [[ "$ttl" =~ ^[0-9]+$ ]] && (( ttl > 0 )); then
    cache_file=$(repo_scan_cache_path "$expanded_dir")
    if repo_scan_cache_read "$cache_file" "$expanded_dir" "$ttl"; then
      return 0
    fi
  fi

  local repos
  # Find .git directories, limit depth for performance
  repos=$(find "$expanded_dir" -maxdepth 5 -type d -name ".git" 2>/dev/null | while read -r git_dir; do
    dirname "$git_dir"
  done)

  if [[ -n "$cache_file" ]]; then
    repo_scan_cache_write "$cache_file" "$expanded_dir" "$repos"
  fi

  if [[ -n "$repos" ]]; then
    printf '%s\n' "$repos"
  fi
  return 0
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
  elif [[ "$origin_url" == ssh://git@github.com/* ]]; then
    # Convert explicit ssh:// URLs to the same scp-style alias form
    local repo_part="${origin_url#ssh://git@github.com/}"
    local new_url="git@$ssh_alias:$repo_part"
    git remote set-url origin "$new_url"
    log_info "Converted ssh:// remote in $repo_path"
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
