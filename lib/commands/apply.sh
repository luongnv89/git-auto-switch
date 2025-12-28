#!/usr/bin/env bash
# Apply configuration from state to system

cmd_apply() {
  # Check if initialized
  if ! load_state; then
    die "Not initialized. Run 'git-auto-switch init' first."
  fi

  # Validate state before applying
  if ! validate_state; then
    die "Invalid state. Fix errors and try again."
  fi

  local account_count
  account_count=$(get_account_count)

  if [[ $account_count -eq 0 ]]; then
    log_warn "No accounts configured. Nothing to apply."
    return 0
  fi

  echo
  log_info "Applying configuration for $account_count account(s)..."
  echo

  # Step 1: Ensure SSH keys exist
  log_info "Step 1/5: Checking SSH keys..."
  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")
    ensure_ssh_key "$account"
  done

  # Step 2: Apply SSH config
  log_info "Step 2/5: Updating SSH config..."
  apply_ssh_config

  # Step 3: Apply Git config
  log_info "Step 3/5: Updating Git config..."
  apply_git_config

  # Step 4: Install pre-commit hook
  log_info "Step 4/5: Installing pre-commit hook..."
  apply_pre_commit_hook
  configure_global_hooks

  # Step 5: Rewrite remotes
  log_info "Step 5/5: Rewriting repository remotes..."
  rewrite_all_remotes

  # Update last_applied in state
  save_state

  echo
  log_success "Configuration applied successfully!"
  echo
  echo "Summary:"
  echo "  - SSH config updated with $account_count host alias(es)"
  echo "  - Git includeIf blocks configured for $account_count workspace(s)"
  echo "  - Pre-commit hook installed at $HOOKS_DIR/pre-commit"
  echo
  echo "Test SSH connections with:"
  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")
    local ssh_alias
    ssh_alias=$(echo "$account" | jq -r '.ssh_alias')
    echo "  ssh -T git@$ssh_alias"
  done
  echo
}
