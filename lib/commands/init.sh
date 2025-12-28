#!/usr/bin/env bash
# Initialize git-auto-switch configuration

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

  # Initialize empty state
  init_state

  # Prompt for first account
  log_info "Let's set up your first account"

  local account_info
  account_info=$(prompt_account_info)
  parse_account_info "$account_info"

  # Add account to state
  add_account "$ACCOUNT_ID" "$ACCOUNT_NAME" "$ACCOUNT_SSH_ALIAS" \
    "$ACCOUNT_SSH_KEY_PATH" "$ACCOUNT_WORKSPACE" "$ACCOUNT_GIT_NAME" "$ACCOUNT_GIT_EMAIL"

  # Ask if user wants to add more accounts
  while true; do
    echo
    read -rp "Would you like to add another account? [y/N] " add_more
    if [[ "$add_more" != "y" && "$add_more" != "Y" ]]; then
      break
    fi

    account_info=$(prompt_account_info)
    parse_account_info "$account_info"

    add_account "$ACCOUNT_ID" "$ACCOUNT_NAME" "$ACCOUNT_SSH_ALIAS" \
      "$ACCOUNT_SSH_KEY_PATH" "$ACCOUNT_WORKSPACE" "$ACCOUNT_GIT_NAME" "$ACCOUNT_GIT_EMAIL"
  done

  # Set default account before saving and applying
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

  # Save state
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
