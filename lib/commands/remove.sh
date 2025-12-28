#!/usr/bin/env bash
# Remove an account

cmd_remove() {
  local account_id="$1"

  # Check if initialized
  if ! load_state; then
    die "Not initialized. Run 'git-auto-switch init' first."
  fi

  local account_count
  account_count=$(get_account_count)

  if [[ $account_count -eq 0 ]]; then
    die "No accounts configured"
  fi

  # If no ID provided, show list and prompt
  if [[ -z "$account_id" ]]; then
    echo
    echo "Select account to remove:"
    local ids=()
    while IFS= read -r id; do
      ids+=("$id")
    done < <(list_account_ids)

    select id in "${ids[@]}"; do
      if [[ -n "$id" ]]; then
        account_id="$id"
        break
      fi
    done
  fi

  # Check if account exists
  if ! account_exists "$account_id"; then
    die "Account '$account_id' not found"
  fi

  # Get account details for confirmation
  local account
  account=$(get_account "$account_id")
  local name git_email
  name=$(echo "$account" | jq -r '.name')
  git_email=$(echo "$account" | jq -r '.git_email')

  echo
  echo "Account to remove:"
  echo "  ID: $account_id"
  echo "  Name: $name"
  echo "  Email: $git_email"
  echo

  read -rp "Are you sure you want to remove this account? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Removal cancelled"
    return 0
  fi

  # Remove account
  remove_account "$account_id"

  # Remove per-account gitconfig file
  local config_file="$HOME/.gitconfig-$account_id"
  if [[ -f "$config_file" ]]; then
    rm "$config_file"
    log_info "Removed $config_file"
  fi

  # Save state
  save_state

  # Ask to reapply configuration
  echo
  read -rp "Reapply configuration to update SSH and Git configs? [Y/n] " reapply
  if [[ "$reapply" != "n" && "$reapply" != "N" ]]; then
    cmd_apply
  fi

  log_success "Account '$account_id' removed successfully!"
}
