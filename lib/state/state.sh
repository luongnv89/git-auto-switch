#!/usr/bin/env bash
# State management - load, save, validate JSON config

# Global state variable
STATE_JSON=""

# Initialize empty state
init_state() {
  STATE_JSON=$(cat <<EOF
{
  "version": "$GAS_VERSION",
  "accounts": [],
  "metadata": {
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "last_applied": null
  }
}
EOF
)
}

# Load state from config file
load_state() {
  require_jq

  if [[ ! -f "$CONFIG_FILE" ]]; then
    return 1
  fi

  STATE_JSON=$(cat "$CONFIG_FILE")

  # Validate JSON
  if ! echo "$STATE_JSON" | jq empty 2>/dev/null; then
    die "Invalid JSON in config file: $CONFIG_FILE"
  fi

  return 0
}

# Save state to config file
save_state() {
  require_jq

  mkdir -p "$CONFIG_DIR"

  # Update last_applied timestamp
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  STATE_JSON=$(echo "$STATE_JSON" | jq ".metadata.last_applied = \"$timestamp\"")

  # Atomic write via temp file
  local tmp_file="$CONFIG_FILE.tmp"
  echo "$STATE_JSON" | jq '.' > "$tmp_file"
  mv "$tmp_file" "$CONFIG_FILE"

  log_success "State saved to $CONFIG_FILE"
}

# Validate state structure and data
validate_state() {
  require_jq

  local errors=0

  # Check version field
  local version
  version=$(echo "$STATE_JSON" | jq -r '.version // empty')
  if [[ -z "$version" ]]; then
    log_error "Missing version field in state"
    ((errors++))
  fi

  # Check accounts array
  if ! echo "$STATE_JSON" | jq -e '.accounts | type == "array"' >/dev/null 2>&1; then
    log_error "Missing or invalid accounts array in state"
    ((errors++))
    return 1
  fi

  # Validate each account
  local account_count
  account_count=$(echo "$STATE_JSON" | jq '.accounts | length')

  local seen_ids=()
  local seen_workspaces=()
  local seen_aliases=()

  for ((i=0; i<account_count; i++)); do
    local account
    account=$(echo "$STATE_JSON" | jq ".accounts[$i]")

    local id name ssh_alias git_email
    id=$(echo "$account" | jq -r '.id // empty')
    name=$(echo "$account" | jq -r '.name // empty')
    ssh_alias=$(echo "$account" | jq -r '.ssh_alias // empty')
    git_email=$(echo "$account" | jq -r '.git_email // empty')

    # Required fields
    if [[ -z "$id" ]]; then
      log_error "Account at index $i missing 'id' field"
      ((errors++))
    fi

    if [[ -z "$name" ]]; then
      log_error "Account '$id' missing 'name' field"
      ((errors++))
    fi

    if [[ -z "$ssh_alias" ]]; then
      log_error "Account '$id' missing 'ssh_alias' field"
      ((errors++))
    fi

    # Check workspaces array
    local workspaces_count
    workspaces_count=$(echo "$account" | jq '.workspaces | length // 0')
    if [[ $workspaces_count -eq 0 ]]; then
      log_error "Account '$id' missing 'workspaces' field or empty"
      ((errors++))
    fi

    if [[ -z "$git_email" ]]; then
      log_error "Account '$id' missing 'git_email' field"
      ((errors++))
    elif ! validate_email "$git_email"; then
      log_error "Account '$id' has invalid email: $git_email"
      ((errors++))
    fi

    # Check for duplicates
    for seen_id in "${seen_ids[@]}"; do
      if [[ "$seen_id" == "$id" ]]; then
        log_error "Duplicate account ID: $id"
        ((errors++))
      fi
    done
    seen_ids+=("$id")

    # Check each workspace in the account
    for ((j=0; j<workspaces_count; j++)); do
      local workspace
      workspace=$(echo "$account" | jq -r ".workspaces[$j]")

      for seen_ws in "${seen_workspaces[@]}"; do
        if [[ "$seen_ws" == "$workspace" ]]; then
          log_error "Duplicate workspace: $workspace"
          ((errors++))
        fi
        # Check for overlapping workspaces (one inside another)
        local expanded_ws expanded_seen_ws
        expanded_ws=$(expand_path "$workspace")
        expanded_seen_ws=$(expand_path "$seen_ws")
        if [[ "${expanded_ws}/" == "${expanded_seen_ws}/"* ]] || [[ "${expanded_seen_ws}/" == "${expanded_ws}/"* ]]; then
          log_error "Overlapping workspaces: $workspace and $seen_ws"
          ((errors++))
        fi
      done
      seen_workspaces+=("$workspace")
    done

    for seen_alias in "${seen_aliases[@]}"; do
      if [[ "$seen_alias" == "$ssh_alias" ]]; then
        log_error "Duplicate SSH alias: $ssh_alias"
        ((errors++))
      fi
    done
    seen_aliases+=("$ssh_alias")
  done

  if [[ $errors -gt 0 ]]; then
    return 1
  fi

  return 0
}

# Get account count
get_account_count() {
  echo "$STATE_JSON" | jq '.accounts | length'
}

# Get account by ID
get_account() {
  local id="$1"
  echo "$STATE_JSON" | jq -r ".accounts[] | select(.id == \"$id\")"
}

# Get account by index
get_account_by_index() {
  local index="$1"
  echo "$STATE_JSON" | jq ".accounts[$index]"
}

# List all account IDs
list_account_ids() {
  echo "$STATE_JSON" | jq -r '.accounts[].id'
}

# Find account by workspace (for pre-commit hook)
find_account_by_workspace() {
  local repo_path="$1"
  local expanded_repo
  expanded_repo=$(expand_path "$repo_path")

  # Find account where repo_path starts with any of the workspaces
  echo "$STATE_JSON" | jq -r --arg repo "$expanded_repo" '
    .accounts[] |
    select(.workspaces[] as $ws | ($repo + "/") | startswith(($ws | gsub("~"; env.HOME)) + "/"))
  ' | head -n1
}

# Check if account ID exists
account_exists() {
  local id="$1"
  local result
  result=$(echo "$STATE_JSON" | jq -r ".accounts[] | select(.id == \"$id\") | .id")
  [[ -n "$result" ]]
}
