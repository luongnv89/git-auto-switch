#!/usr/bin/env bash
# Add a new account

cmd_add() {
  # Check if initialized
  if ! load_state; then
    die "Not initialized. Run 'git-auto-switch init' first."
  fi

  # Loop to allow adding multiple accounts
  while true; do
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

    # Apply configuration automatically
    echo
    log_info "Applying configuration..."
    cmd_apply

    # Show success message
    echo
    echo "========================================"
    log_success "Account '$ACCOUNT_NAME' has been validated and added successfully!"
    echo "========================================"

    # Ask if user wants to add another account
    echo
    read -rp "Would you like to add another account? [y/N] " add_another
    if [[ "$add_another" != "y" && "$add_another" != "Y" ]]; then
      break
    fi
  done
}
