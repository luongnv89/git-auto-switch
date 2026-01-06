#!/usr/bin/env bash
# Show current active account based on working directory

cmd_current() {
  # Check if initialized
  if ! load_state; then
    die "Not initialized. Run 'git-auto-switch init' first."
  fi

  local current_dir
  current_dir=$(pwd)

  # Find matching account by checking if current dir is inside any workspace
  local account
  account=$(echo "$STATE_JSON" | jq --arg dir "$current_dir" '
    [.accounts[] |
    select(.workspaces[] as $ws | ($dir + "/") | startswith(($ws | gsub("~"; env.HOME)) + "/"))] |
    first // empty
  ')

  if [[ -z "$account" || "$account" == "null" ]]; then
    echo
    log_warn "No account configured for this directory"
    echo "  Current directory: $current_dir"
    echo
    echo "This directory is not inside any configured workspace."
    echo "Default global Git identity will be used."
    echo

    # Show global git config
    local global_name global_email
    global_name=$(git config --global user.name 2>/dev/null || echo "<not set>")
    global_email=$(git config --global user.email 2>/dev/null || echo "<not set>")
    echo "Global Git identity:"
    echo "  Name:  $global_name"
    echo "  Email: $global_email"
    return 1
  fi

  local id name ssh_alias git_name git_email
  id=$(echo "$account" | jq -r '.id')
  name=$(echo "$account" | jq -r '.name')
  ssh_alias=$(echo "$account" | jq -r '.ssh_alias')
  git_name=$(echo "$account" | jq -r '.git_name')
  git_email=$(echo "$account" | jq -r '.git_email')

  echo
  echo "========================================"
  echo "  Current Account: $name"
  echo "========================================"
  echo
  echo "  Account ID:  $id"
  echo "  Git Name:    $git_name"
  echo "  Git Email:   $git_email"
  echo "  SSH Alias:   $ssh_alias"
  echo
  echo "  Directory:   $current_dir"
  echo

  # Show workspaces for this account
  echo "  Workspaces:"
  local workspaces_count
  workspaces_count=$(echo "$account" | jq '.workspaces | length')
  for ((i=0; i<workspaces_count; i++)); do
    local ws
    ws=$(echo "$account" | jq -r ".workspaces[$i]")
    echo "    - $ws"
  done
  echo

  # Verify actual git config in current directory (only if inside a git repo)
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local actual_email
    actual_email=$(git config user.email 2>/dev/null || echo "")
    if [[ -n "$actual_email" && "$actual_email" != "$git_email" ]]; then
      log_warn "Git email mismatch detected!"
      echo "  Expected: $git_email"
      echo "  Actual:   $actual_email"
      echo
      echo "Run 'gas audit --fix' to fix this issue."
    fi
  fi
}
