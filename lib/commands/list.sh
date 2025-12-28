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

  # Print accounts with details
  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")

    local id name git_name git_email ssh_alias
    id=$(echo "$account" | jq -r '.id')
    name=$(echo "$account" | jq -r '.name')
    git_name=$(echo "$account" | jq -r '.git_name')
    git_email=$(echo "$account" | jq -r '.git_email')
    ssh_alias=$(echo "$account" | jq -r '.ssh_alias')

    echo "[$id] $name"
    echo "  Git:    $git_name <$git_email>"
    echo "  SSH:    $ssh_alias"
    echo "  Workspaces:"

    local workspaces_count
    workspaces_count=$(echo "$account" | jq '.workspaces | length')
    for ((j=0; j<workspaces_count; j++)); do
      local workspace
      workspace=$(echo "$account" | jq -r ".workspaces[$j]")
      echo "    - $workspace"
    done
    echo
  done
}
