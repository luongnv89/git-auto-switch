#!/usr/bin/env bash
# Audit repositories for identity issues

cmd_audit() {
  # Check if initialized
  if ! load_state; then
    die "Not initialized. Run 'git-auto-switch init' first."
  fi

  local account_count
  account_count=$(get_account_count)

  if [[ $account_count -eq 0 ]]; then
    log_warn "No accounts configured"
    return 0
  fi

  echo
  echo "========================================"
  echo "  Repository Audit"
  echo "========================================"
  echo

  local total_repos=0
  local issues=0

  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")

    local id name ssh_alias workspace git_email
    id=$(echo "$account" | jq -r '.id')
    name=$(echo "$account" | jq -r '.name')
    ssh_alias=$(echo "$account" | jq -r '.ssh_alias')
    workspace=$(echo "$account" | jq -r '.workspace')
    git_email=$(echo "$account" | jq -r '.git_email')

    local expanded_workspace
    expanded_workspace=$(expand_path "$workspace")

    echo
    log_info "Auditing workspace: $name ($workspace)"

    if [[ ! -d "$expanded_workspace" ]]; then
      log_warn "Workspace directory does not exist"
      continue
    fi

    # Find repositories
    local repos
    repos=$(find_git_repos "$workspace")

    if [[ -z "$repos" ]]; then
      log_info "No repositories found"
      continue
    fi

    while IFS= read -r repo; do
      ((total_repos++))

      local current_dir
      current_dir=$(pwd)

      cd "$repo" || continue

      # Check email configuration
      local repo_email
      repo_email=$(git config user.email 2>/dev/null || echo "")

      # Check remote URL
      local origin_url
      origin_url=$(git remote get-url origin 2>/dev/null || echo "")

      local email_ok=true
      local remote_ok=true

      # Validate email
      if [[ -z "$repo_email" ]]; then
        email_ok=false
      elif [[ "$repo_email" != "$git_email" ]]; then
        email_ok=false
      fi

      # Validate remote (should use SSH alias)
      if [[ -n "$origin_url" ]]; then
        if [[ "$origin_url" != *"$ssh_alias"* ]]; then
          if [[ "$origin_url" == *"github.com"* ]]; then
            remote_ok=false
          fi
        fi
      fi

      # Report issues
      if [[ "$email_ok" == false || "$remote_ok" == false ]]; then
        ((issues++))
        echo
        log_warn "Issues in: $repo"

        if [[ "$email_ok" == false ]]; then
          echo "  Email:"
          echo "    Expected: $git_email"
          echo "    Actual:   ${repo_email:-<not set>}"
        fi

        if [[ "$remote_ok" == false ]]; then
          echo "  Remote:"
          echo "    Expected alias: $ssh_alias"
          echo "    Actual URL:     $origin_url"
        fi
      fi

      cd "$current_dir" || exit 1
    done <<< "$repos"
  done

  # Summary
  echo
  echo "========================================"
  echo "Audit Summary"
  echo "========================================"
  echo "  Total repositories: $total_repos"
  echo "  Issues found: $issues"

  if [[ $issues -gt 0 ]]; then
    echo
    echo "To fix issues, run:"
    echo "  git-auto-switch apply"
    return 1
  else
    log_success "All repositories are correctly configured!"
    return 0
  fi
}
