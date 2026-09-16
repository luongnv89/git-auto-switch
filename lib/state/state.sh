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
  # State dir holds account identities and key paths — owner-only.
  chmod 700 "$CONFIG_DIR"

  # Update last_applied timestamp
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  STATE_JSON=$(echo "$STATE_JSON" | jq ".metadata.last_applied = \"$timestamp\"")

  # Atomic write via temp file — 0600 before rename so config.json is
  # never left world-readable by the umask.
  local tmp_file="$CONFIG_FILE.tmp"
  echo "$STATE_JSON" | jq '.' > "$tmp_file"
  chmod 600 "$tmp_file"
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
    # Single jq projection: all fields + workspaces in one call (F-PERF-001)
    read_account_fields "$i"
    local id="$ACCT_ID" name="$ACCT_NAME" ssh_alias="$ACCT_SSH_ALIAS" git_email="$ACCT_GIT_EMAIL"

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
    local workspaces_count=${#ACCT_WORKSPACES[@]}
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
    if [[ ${#seen_ids[@]} -gt 0 ]]; then
      for seen_id in "${seen_ids[@]}"; do
        if [[ "$seen_id" == "$id" ]]; then
          log_error "Duplicate account ID: $id"
          ((errors++))
        fi
      done
    fi
    seen_ids+=("$id")

    # Check each workspace in the account
    for ((j=0; j<workspaces_count; j++)); do
      local workspace="${ACCT_WORKSPACES[$j]}"

      if [[ ${#seen_workspaces[@]} -gt 0 ]]; then
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
      fi
      seen_workspaces+=("$workspace")
    done

    if [[ ${#seen_aliases[@]} -gt 0 ]]; then
      for seen_alias in "${seen_aliases[@]}"; do
        if [[ "$seen_alias" == "$ssh_alias" ]]; then
          log_error "Duplicate SSH alias: $ssh_alias"
          ((errors++))
        fi
      done
    fi
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
  echo "$STATE_JSON" | jq --arg id "$id" '.accounts[] | select(.id == $id)'
}

# Get account by ID or SSH alias (matches whichever the user passed in)
get_account_by_id_or_alias() {
  local key="$1"
  echo "$STATE_JSON" | jq --arg key "$key" \
    '.accounts[] | select(.id == $key or .ssh_alias == $key)'
}

# Get account by index
get_account_by_index() {
  local index="$1"
  echo "$STATE_JSON" | jq ".accounts[$index]"
}

# jq program for the single-projection account extraction (F-PERF-001/003).
# Output: line 1 joins the scalar fields with \x1f (ASCII unit separator —
# unlike a tab it is not IFS whitespace, so empty fields survive `IFS= read`);
# each following line is one workspace entry.
GAS_ACCOUNT_PROJECTION='
  ([.id, .name, .ssh_alias, .ssh_key_path, .git_name, .git_email]
    | map(. // "" | tostring) | join("\u001f")),
  (if (.workspaces | type) == "array" then .workspaces[] else empty end)'

# Unpack a projection dump (see GAS_ACCOUNT_PROJECTION) into globals:
# ACCT_ID, ACCT_NAME, ACCT_SSH_ALIAS, ACCT_SSH_KEY_PATH, ACCT_GIT_NAME,
# ACCT_GIT_EMAIL and the ACCT_WORKSPACES array.
_unpack_account_fields() {
  ACCT_ID=""
  ACCT_NAME=""
  ACCT_SSH_ALIAS=""
  ACCT_SSH_KEY_PATH=""
  ACCT_GIT_NAME=""
  ACCT_GIT_EMAIL=""
  ACCT_WORKSPACES=()

  local ws
  {
    IFS=$'\x1f' read -r ACCT_ID ACCT_NAME ACCT_SSH_ALIAS ACCT_SSH_KEY_PATH ACCT_GIT_NAME ACCT_GIT_EMAIL
    while IFS= read -r ws; do
      ACCT_WORKSPACES+=("$ws")
    done
  } <<< "$1"
}

# Populate the ACCT_* globals from .accounts[index] of $STATE_JSON — one jq
# call per account instead of one subprocess per field (the N+1 pattern this
# replaces).
read_account_fields() {
  _unpack_account_fields "$(echo "$STATE_JSON" | jq -r --argjson i "$1" \
    ".accounts[\$i] | ($GAS_ACCOUNT_PROJECTION)")"
}

# Populate the ACCT_* globals from an account JSON object (e.g. the result of
# get_account_by_id_or_alias) — one jq call, same projection.
parse_account_fields() {
  _unpack_account_fields "$(echo "$1" | jq -r "$GAS_ACCOUNT_PROJECTION")"
}

# List all account IDs
list_account_ids() {
  echo "$STATE_JSON" | jq -r '.accounts[].id'
}

# Find account by workspace (for pre-commit hook and `gas current`)
find_account_by_workspace() {
  local repo_path="$1"
  local expanded_repo
  expanded_repo=$(expand_path "$repo_path")

  # Emit one "<account-index>\t<workspace>" pair per stored workspace, then
  # canonicalize each through expand_path — the same helper apply/audit/
  # validate use — so this lookup can never diverge from them.
  local pairs
  pairs=$(echo "$STATE_JSON" | jq -r '
    .accounts as $accounts
    | range(0; $accounts | length) as $i
    | $accounts[$i].workspaces[]
    | "\($i)\t\(.)"
  ')

  local idx ws expanded_ws
  while IFS=$'\t' read -r idx ws; do
    expanded_ws=$(expand_path "$ws")
    if [[ "${expanded_repo}/" == "${expanded_ws}/"* ]]; then
      echo "$STATE_JSON" | jq ".accounts[$idx]"
      return 0
    fi
  done <<< "$pairs"
}

# Check if account ID exists
account_exists() {
  local id="$1"
  local result
  result=$(echo "$STATE_JSON" | jq -r --arg id "$id" '.accounts[] | select(.id == $id) | .id')
  [[ -n "$result" ]]
}
