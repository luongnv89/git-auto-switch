#!/usr/bin/env bash
# List all configured accounts

cmd_list() {
  # Check if initialized
  if ! load_state; then
    die "Not initialized. Run 'git-auto-switch init' first."
  fi

  local account_count
  account_count=$(get_account_count)

  if [[ $account_count -eq 0 ]]; then
    log_info "No accounts configured"
    echo "Run 'git-auto-switch add' to add an account"
    return 0
  fi

  echo
  echo "Configured accounts ($account_count):"
  echo

  # Print header
  printf "%-15s %-20s %-25s %-30s\n" "ID" "NAME" "EMAIL" "WORKSPACE"
  printf "%-15s %-20s %-25s %-30s\n" "---------------" "--------------------" "-------------------------" "------------------------------"

  # Print accounts
  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")

    local id name git_email workspace
    id=$(echo "$account" | jq -r '.id')
    name=$(echo "$account" | jq -r '.name')
    git_email=$(echo "$account" | jq -r '.git_email')
    workspace=$(echo "$account" | jq -r '.workspace')

    printf "%-15s %-20s %-25s %-30s\n" "$id" "$name" "$git_email" "$workspace"
  done

  echo
}
