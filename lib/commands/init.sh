#!/usr/bin/env bash
# Initialize git-auto-switch configuration

# Cleanup handler for Ctrl+C during init
_init_cleanup() {
  echo
  local account_count
  account_count=$(get_account_count)

  if [[ $account_count -gt 0 ]]; then
    log_warn "Interrupted! Saving $account_count account(s) configured so far..."
    save_state
    log_success "Progress saved to: $CONFIG_FILE"
    echo "Run 'gas add' to add more accounts, or 'gas apply' to apply configuration."
  else
    log_warn "Interrupted! No accounts were configured."
  fi

  # Remove trap and exit
  trap - INT
  exit 130
}

cmd_init() {
  # Check if already initialized
  if [[ -f "$CONFIG_FILE" ]]; then
    log_warn "Configuration already exists at $CONFIG_FILE"
    read -rp "Do you want to reinitialize? This will overwrite existing config. [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      log_info "Initialization cancelled"
      return 0
    fi
  fi

  echo
  echo "========================================"
  echo "  Git Auto Switch - Initial Setup"
  echo "========================================"
  echo
  echo "This wizard will help you configure multiple GitHub accounts"
  echo "with automatic identity switching based on workspace folders."
  echo
  log_info "Tip: Press Ctrl+C anytime to save progress and quit."
  echo

  # Initialize empty state
  init_state

  # Set up interrupt handler
  trap '_init_cleanup' INT

  # Prompt for first account (required)
  log_info "Let's set up your first account"

  while true; do
    if prompt_account_info; then
      # Add account to state and save immediately
      add_account "$ACCOUNT_ID" "$ACCOUNT_NAME" "$ACCOUNT_SSH_ALIAS" \
        "$ACCOUNT_SSH_KEY_PATH" "$ACCOUNT_WORKSPACES_JSON" "$ACCOUNT_GIT_NAME" "$ACCOUNT_GIT_EMAIL"
      save_state
      break
    else
      # User aborted - ask if they want to try again or quit
      echo
      read -rp "Would you like to try again? [Y/n] " retry
      if [[ "$retry" == "n" || "$retry" == "N" ]]; then
        log_warn "At least one account is required. Initialization cancelled."
        trap - INT
        return 1
      fi
    fi
  done

  # Ask if user wants to add more accounts
  while true; do
    echo
    read -rp "Would you like to add another account? [y/N] " add_more
    if [[ "$add_more" != "y" && "$add_more" != "Y" ]]; then
      break
    fi

    if prompt_account_info; then
      # Add account to state and save immediately
      add_account "$ACCOUNT_ID" "$ACCOUNT_NAME" "$ACCOUNT_SSH_ALIAS" \
        "$ACCOUNT_SSH_KEY_PATH" "$ACCOUNT_WORKSPACES_JSON" "$ACCOUNT_GIT_NAME" "$ACCOUNT_GIT_EMAIL"
      save_state
    fi
    # If aborted, just continue the loop (user can add another or exit)
  done

  # Remove interrupt handler - we're in the final phase
  trap - INT

  # Set default account
  local account_count
  account_count=$(get_account_count)

  if [[ $account_count -gt 1 ]]; then
    echo
    log_info "Select default account (used outside workspaces):"
    local ids
    mapfile -t ids < <(list_account_ids)

    select default_id in "${ids[@]}"; do
      if [[ -n "$default_id" ]]; then
        local account
        account=$(get_account "$default_id")
        set_default_git_identity "$account"
        break
      fi
    done
  elif [[ $account_count -eq 1 ]]; then
    local account
    account=$(get_account_by_index 0)
    set_default_git_identity "$account"
  fi

  # Save final state
  save_state

  # Ask to apply configuration
  echo
  read -rp "Apply configuration now? [Y/n] " apply_now
  if [[ "$apply_now" != "n" && "$apply_now" != "N" ]]; then
    cmd_apply
  fi

  echo
  echo "========================================"
  log_success "Initialization complete!"
  echo "========================================"
  echo
  echo "Quick reference:"
  echo "  gas list      - Show all accounts"
  echo "  gas add       - Add a new account"
  echo "  gas remove    - Remove an account"
  echo "  gas audit     - Check for identity issues"
  echo "  gas validate  - Validate configuration"
  echo
  echo "Config saved to: $CONFIG_FILE"
  echo
}
