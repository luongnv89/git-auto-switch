#!/usr/bin/env bash
# Audit repositories for identity issues

cmd_audit() {
  local fix_mode=false
  if [[ "${1:-}" == "--fix" || "${1:-}" == "-f" ]]; then
    fix_mode=true
  fi

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

    local id name ssh_alias git_email
    id=$(echo "$account" | jq -r '.id')
    name=$(echo "$account" | jq -r '.name')
    ssh_alias=$(echo "$account" | jq -r '.ssh_alias')
    git_email=$(echo "$account" | jq -r '.git_email')

    echo
    log_info "Auditing account: $name"

    # Process all workspaces for this account
    local workspaces_count
    workspaces_count=$(echo "$account" | jq '.workspaces | length')

    for ((j=0; j<workspaces_count; j++)); do
      local workspace
      workspace=$(echo "$account" | jq -r ".workspaces[$j]")

      local expanded_workspace
      expanded_workspace=$(expand_path "$workspace")

      log_info "  Workspace: $workspace"

      if [[ ! -d "$expanded_workspace" ]]; then
        log_warn "  Workspace directory does not exist"
        continue
      fi

      # Find repositories
      local repos
      repos=$(find_git_repos "$workspace")

      if [[ -z "$repos" ]]; then
        log_info "  No repositories found"
        continue
      fi

      while IFS= read -r repo; do
        ((total_repos++)) || true

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

        # Report and optionally fix issues
        if [[ "$email_ok" == false || "$remote_ok" == false ]]; then
          ((issues++)) || true
          echo
          log_warn "Issues in: $repo"

          if [[ "$email_ok" == false ]]; then
            echo "  Email:"
            echo "    Expected: $git_email"
            echo "    Actual:   ${repo_email:-<not set>}"
            if [[ "$fix_mode" == true ]]; then
              # Remove local user.email to let includeIf take over
              git config --unset user.email 2>/dev/null || true
              log_success "  Fixed: Removed local user.email (will use global includeIf)"
            fi
          fi

          if [[ "$remote_ok" == false ]]; then
            echo "  Remote:"
            echo "    Expected alias: $ssh_alias"
            echo "    Actual URL:     $origin_url"
            if [[ "$fix_mode" == true ]]; then
              # Rewrite remote to use SSH alias
              rewrite_repo_remotes "$repo" "$ssh_alias"
              log_success "  Fixed: Rewrote remote to use $ssh_alias"
            fi
          fi
        fi

        cd "$current_dir" || exit 1
      done <<< "$repos"
    done
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
    if [[ "$fix_mode" == true ]]; then
      log_success "Fixed $issues issue(s)"
    else
      echo "To fix issues, run:"
      echo "  git-auto-switch audit --fix"
    fi
    return 1
  else
    log_success "All repositories are correctly configured!"
    return 0
  fi
}
