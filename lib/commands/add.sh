#!/usr/bin/env bash
# Add a new account

cmd_add() {
  # Check if initialized
  if ! load_state; then
    die "Not initialized. Run 'git-auto-switch init' first."
  fi

  echo
  echo "========================================"
  echo "  Add New Account"
  echo "========================================"
  echo

  # Prompt for account info
  if ! prompt_account_info; then
    log_info "Account addition cancelled."
    return 0
  fi

  # Add account to state
  add_account "$ACCOUNT_ID" "$ACCOUNT_NAME" "$ACCOUNT_SSH_ALIAS" \
    "$ACCOUNT_SSH_KEY_PATH" "$ACCOUNT_WORKSPACES_JSON" "$ACCOUNT_GIT_NAME" "$ACCOUNT_GIT_EMAIL"

  # Save state
  save_state

  # Ask to apply configuration
  echo
  read -rp "Apply configuration now? [Y/n] " apply_now
  if [[ "$apply_now" != "n" && "$apply_now" != "N" ]]; then
    cmd_apply
  fi

  log_success "Account '$ACCOUNT_ID' added successfully!"
}
