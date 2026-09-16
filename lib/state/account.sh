#!/usr/bin/env bash
# Account CRUD operations on state

# Validate the inputs for a new account; dies on the first invalid field
validate_new_account_inputs() {
  local id="$1"
  local ssh_alias="$2"
  local git_email="$3"

  if ! validate_account_name "$id"; then
    die "Invalid account ID: $id (must be alphanumeric with dashes/underscores)"
  fi

  if ! validate_ssh_alias "$ssh_alias"; then
    die "Invalid SSH alias: $ssh_alias (must be alphanumeric with dashes/underscores)"
  fi

  if ! validate_email "$git_email"; then
    die "Invalid email format: $git_email"
  fi
}

# Add account to state
# workspaces_json should be a JSON array string like '["~/work", "~/projects"]'
add_account() {
  local id="$1"
  local name="$2"
  local ssh_alias="$3"
  local ssh_key_path="$4"
  local workspaces_json="$5"
  local git_name="$6"
  local git_email="$7"

  require_jq

  # Validate inputs
  validate_new_account_inputs "$id" "$ssh_alias" "$git_email"

  # Check for duplicates
  if account_exists "$id"; then
    die "Account with ID '$id' already exists"
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Add account to state with workspaces as array
  STATE_JSON=$(echo "$STATE_JSON" | jq \
    --arg id "$id" \
    --arg name "$name" \
    --arg ssh_alias "$ssh_alias" \
    --arg ssh_key_path "$ssh_key_path" \
    --argjson workspaces "$workspaces_json" \
    --arg git_name "$git_name" \
    --arg git_email "$git_email" \
    --arg created_at "$timestamp" \
    '.accounts += [{
      id: $id,
      name: $name,
      ssh_alias: $ssh_alias,
      ssh_key_path: $ssh_key_path,
      workspaces: $workspaces,
      git_name: $git_name,
      git_email: $git_email,
      created_at: $created_at
    }]')

  log_success "Added account: $id"
}

# Remove account by ID
remove_account() {
  local id="$1"

  require_jq

  if ! account_exists "$id"; then
    die "Account with ID '$id' does not exist"
  fi

  STATE_JSON=$(echo "$STATE_JSON" | jq --arg id "$id" \
    '.accounts |= map(select(.id != $id))')

  log_success "Removed account: $id"
}

# Update account field — allowlisted fields only, with type-preserving
# writes (F-BUG-002): scalar fields stay strings via --arg, workspaces takes
# a JSON array via --argjson so the array type survives the write.
update_account() {
  local id="$1"
  local field="$2"
  local value="$3"

  require_jq

  if ! account_exists "$id"; then
    die "Account with ID '$id' does not exist"
  fi

  case "$field" in
    name|ssh_alias|ssh_key_path|git_name|git_email)
      STATE_JSON=$(echo "$STATE_JSON" | jq \
        --arg id "$id" \
        --arg field "$field" \
        --arg value "$value" \
        '(.accounts[] | select(.id == $id))[$field] = $value')
      ;;
    workspaces)
      if ! echo "$value" | jq -e 'type == "array"' >/dev/null 2>&1; then
        die "Field 'workspaces' requires a JSON array value"
      fi
      STATE_JSON=$(echo "$STATE_JSON" | jq \
        --arg id "$id" \
        --argjson value "$value" \
        '(.accounts[] | select(.id == $id)).workspaces = $value')
      ;;
    *)
      die "Cannot update field '$field' (allowed: name, ssh_alias, ssh_key_path, git_name, git_email, workspaces)"
      ;;
  esac

  log_success "Updated $field for account: $id"
}

# --- Interactive prompt helpers ---------------------------------------------
# prompt_account_info is split into single-responsibility helpers that share
# the in-progress answers through PROMPT_* globals — the same pattern the
# final ACCOUNT_* globals use. prompt_account_info (at the bottom) wires the
# helpers together and is the only entry point called from outside this file.

# Prompt until a non-empty, valid account name is entered
prompt_account_name() {
  echo
  read -rp "Account name (e.g., personal, work): " PROMPT_NAME
  while [[ -z "$PROMPT_NAME" ]] || ! validate_account_name "$PROMPT_NAME"; do
    log_warn "Invalid name. Use alphanumeric characters, dashes, or underscores."
    read -rp "Account name: " PROMPT_NAME
  done
}

# Collect one or more workspace folders into the PROMPT_WORKSPACES array
prompt_account_workspaces() {
  local workspace_input
  local default_workspace="$HOME/workspace/$PROMPT_NAME"

  echo
  log_info "Add workspace folders for this account (you can add multiple)"
  read -rp "Workspace folder [$default_workspace]: " workspace_input
  workspace_input="${workspace_input:-$default_workspace}"
  PROMPT_WORKSPACES+=("$workspace_input")

  # Ask for additional workspaces
  while true; do
    read -rp "Add another workspace? (leave empty to continue): " workspace_input
    if [[ -z "$workspace_input" ]]; then
      break
    fi
    PROMPT_WORKSPACES+=("$workspace_input")
  done
}

# Prompt until a valid SSH alias is entered (default: gh-<name>)
prompt_account_ssh_alias() {
  local default_alias="gh-$PROMPT_NAME"

  read -rp "SSH alias [$default_alias]: " PROMPT_SSH_ALIAS
  PROMPT_SSH_ALIAS="${PROMPT_SSH_ALIAS:-$default_alias}"
  while ! validate_ssh_alias "$PROMPT_SSH_ALIAS"; do
    log_warn "Invalid SSH alias. Use alphanumeric characters, dashes, or underscores."
    read -rp "SSH alias: " PROMPT_SSH_ALIAS
  done
}

# Prompt for the SSH key path (default: <first workspace>/.ssh/id_ed25519)
prompt_account_ssh_key() {
  # Default SSH key path inside first workspace/.ssh folder
  local default_key="${PROMPT_WORKSPACES[0]}/.ssh/id_ed25519"

  read -rp "SSH key path [$default_key]: " PROMPT_SSH_KEY_PATH
  PROMPT_SSH_KEY_PATH="${PROMPT_SSH_KEY_PATH:-$default_key}"
}

# Prompt for the git identity (name required, email validated)
prompt_account_git_identity() {
  read -rp "Git user.name: " PROMPT_GIT_NAME
  while [[ -z "$PROMPT_GIT_NAME" ]]; do
    log_warn "Git name is required."
    read -rp "Git user.name: " PROMPT_GIT_NAME
  done

  read -rp "Git user.email: " PROMPT_GIT_EMAIL
  while [[ -z "$PROMPT_GIT_EMAIL" ]] || ! validate_email "$PROMPT_GIT_EMAIL"; do
    log_warn "Please enter a valid email address."
    read -rp "Git user.email: " PROMPT_GIT_EMAIL
  done
}

# Collect every account field into the PROMPT_* globals
prompt_account_fields() {
  prompt_account_name
  prompt_account_workspaces
  prompt_account_ssh_alias
  prompt_account_ssh_key
  prompt_account_git_identity
}

# Render the numbered account summary the fix-menu options refer to
render_account_summary() {
  local ws_idx=0
  local ws

  echo
  echo "----------------------------------------"
  echo "  Account Summary"
  echo "----------------------------------------"
  echo "  1) Account name:   $PROMPT_NAME"
  echo "  2) Workspaces:"
  for ws in "${PROMPT_WORKSPACES[@]}"; do
    echo "       [$ws_idx] $ws"
    ws_idx=$((ws_idx + 1))
  done
  echo "  3) SSH alias:      $PROMPT_SSH_ALIAS"
  echo "  4) SSH key path:   $PROMPT_SSH_KEY_PATH"
  echo "  5) Git user.name:  $PROMPT_GIT_NAME"
  echo "  6) Git user.email: $PROMPT_GIT_EMAIL"
  echo "----------------------------------------"
}

# Warn for each collected workspace that does not exist yet
check_prompt_workspaces() {
  local ws expanded_ws

  for ws in "${PROMPT_WORKSPACES[@]}"; do
    expanded_ws=$(expand_path "$ws")
    if [[ -d "$expanded_ws" ]]; then
      log_success "Workspace exists: $expanded_ws"
    else
      log_warn "Workspace does not exist (will be created): $expanded_ws"
    fi
  done
}

# Check the SSH key exists and authenticates against GitHub.
# Returns 1 when the github.com host key cannot be verified or the key
# exists but authentication fails.
check_prompt_ssh_key() {
  local expanded_key ssh_output
  local ssh_auth_ok=false

  expanded_key=$(expand_path "$PROMPT_SSH_KEY_PATH")
  if [[ ! -f "$expanded_key" ]]; then
    log_warn "SSH key does not exist (will be generated): $expanded_key"
    return 0
  fi

  log_success "SSH key exists: $expanded_key"

  # Test SSH authentication with GitHub using this key — only on an
  # interactive terminal. The live check can block on passphrase or
  # host-key prompts, so a non-TTY stdin (scripted setup) skips it.
  if [[ ! -t 0 ]]; then
    log_info "Skipping SSH authentication test (non-interactive stdin)"
    return 0
  fi

  # First verify github.com host keys against the published fingerprints
  # (never blindly trust via accept-new); abort the check on mismatch.
  log_info "Testing SSH authentication with GitHub..."
  if ! ensure_github_known_hosts; then
    log_error "Refusing SSH authentication test: github.com host key could not be verified."
    return 1
  fi

  if ssh_output=$(ssh -i "$expanded_key" -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 -T git@github.com 2>&1); then
    # SSH returns 1 on success with GitHub (it's expected)
    ssh_auth_ok=true
  elif echo "$ssh_output" | grep -q "successfully authenticated"; then
    ssh_auth_ok=true
  fi

  if [[ "$ssh_auth_ok" == "true" ]]; then
    log_success "SSH authentication successful"
  else
    log_error "SSH authentication failed. Have you added the public key to GitHub?"
    echo "  Public key: ${expanded_key}.pub"
    echo "  Add it at: https://github.com/settings/ssh/new"
    return 1
  fi
}

# Check the generated account ID is not already taken
check_prompt_duplicate() {
  local account_id
  account_id=$(generate_id "$PROMPT_NAME")

  if account_exists "$account_id"; then
    log_error "Account '$PROMPT_NAME' already exists!"
    return 1
  fi
}

# Run all candidate checks; leaves the blocking-issue count in PROMPT_ISSUES
validate_account_candidate() {
  PROMPT_ISSUES=0

  echo
  log_info "Validating configuration..."
  check_prompt_workspaces
  check_prompt_ssh_key || ((PROMPT_ISSUES += 1))
  check_prompt_duplicate || ((PROMPT_ISSUES += 1))
}

# Render the collected workspaces as a JSON array on stdout
build_workspaces_json() {
  local json="["
  local first=true
  local ws

  for ws in "${PROMPT_WORKSPACES[@]}"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      json+=","
    fi
    json+="\"$ws\""
  done
  json+="]"
  printf '%s' "$json"
}

# Publish the validated PROMPT_* values into the ACCOUNT_* globals
publish_account_info() {
  ACCOUNT_ID=$(generate_id "$PROMPT_NAME")
  ACCOUNT_NAME="$PROMPT_NAME"
  ACCOUNT_SSH_ALIAS="$PROMPT_SSH_ALIAS"
  ACCOUNT_SSH_KEY_PATH="$PROMPT_SSH_KEY_PATH"
  ACCOUNT_WORKSPACES_JSON=$(build_workspaces_json)
  ACCOUNT_GIT_NAME="$PROMPT_GIT_NAME"
  ACCOUNT_GIT_EMAIL="$PROMPT_GIT_EMAIL"
}

# Fix menu: edit the account name
fix_menu_edit_name() {
  local new_val
  read -rp "Account name [$PROMPT_NAME]: " new_val
  if [[ -n "$new_val" ]]; then
    if validate_account_name "$new_val"; then
      PROMPT_NAME="$new_val"
    else
      log_warn "Invalid name. Use alphanumeric characters, dashes, or underscores."
    fi
  fi
}

# Fix menu: edit the SSH alias
fix_menu_edit_alias() {
  local new_val
  read -rp "SSH alias [$PROMPT_SSH_ALIAS]: " new_val
  if [[ -n "$new_val" ]]; then
    if validate_ssh_alias "$new_val"; then
      PROMPT_SSH_ALIAS="$new_val"
    else
      log_warn "Invalid SSH alias. Use alphanumeric characters, dashes, or underscores."
    fi
  fi
}

# Fix menu: edit the SSH key path
fix_menu_edit_key() {
  local new_val
  read -rp "SSH key path [$PROMPT_SSH_KEY_PATH]: " new_val
  if [[ -n "$new_val" ]]; then
    PROMPT_SSH_KEY_PATH="$new_val"
  fi
}

# Fix menu: edit the Git user.name
fix_menu_edit_git_name() {
  local new_val
  read -rp "Git user.name [$PROMPT_GIT_NAME]: " new_val
  if [[ -n "$new_val" ]]; then
    PROMPT_GIT_NAME="$new_val"
  fi
}

# Fix menu: edit the Git user.email
fix_menu_edit_git_email() {
  local new_val
  read -rp "Git user.email [$PROMPT_GIT_EMAIL]: " new_val
  if [[ -n "$new_val" ]]; then
    if validate_email "$new_val"; then
      PROMPT_GIT_EMAIL="$new_val"
    else
      log_warn "Invalid email format."
    fi
  fi
}

# Fix menu (workspaces): add a workspace
fix_menu_workspace_add() {
  local new_ws
  read -rp "New workspace folder: " new_ws
  if [[ -n "$new_ws" ]]; then
    PROMPT_WORKSPACES+=("$new_ws")
    log_success "Added workspace: $new_ws"
  fi
}

# Fix menu (workspaces): remove a workspace by index
fix_menu_workspace_remove() {
  local rm_idx

  if [[ ${#PROMPT_WORKSPACES[@]} -le 1 ]]; then
    log_warn "Cannot remove the last workspace. At least one is required."
    return 0
  fi

  read -rp "Index to remove (0-$((${#PROMPT_WORKSPACES[@]}-1))): " rm_idx
  if [[ "$rm_idx" =~ ^[0-9]+$ ]] && [[ $rm_idx -lt ${#PROMPT_WORKSPACES[@]} ]]; then
    log_info "Removed workspace: ${PROMPT_WORKSPACES[$rm_idx]}"
    unset 'PROMPT_WORKSPACES[rm_idx]'
    # Re-index array
    PROMPT_WORKSPACES=("${PROMPT_WORKSPACES[@]}")
  else
    log_warn "Invalid index."
  fi
}

# Fix menu (workspaces): add/remove submenu loop
fix_menu_workspaces() {
  local ws_idx ws ws_action

  while true; do
    echo
    echo "Current workspaces:"
    ws_idx=0
    for ws in "${PROMPT_WORKSPACES[@]}"; do
      echo "  [$ws_idx] $ws"
      ws_idx=$((ws_idx + 1))
    done
    echo
    echo "  [a] Add new workspace"
    echo "  [r] Remove workspace by index"
    echo "  [d] Done"
    echo
    read -rp "Workspace action: " ws_action
    case "$ws_action" in
      a|A)
        fix_menu_workspace_add
        ;;
      r|R)
        fix_menu_workspace_remove
        ;;
      d|D)
        break
        ;;
      *)
        log_warn "Invalid choice."
        ;;
    esac
  done
}

# Show the fix menu and apply the chosen edit.
# Returns 1 when the user aborts, 0 otherwise (validation re-runs).
fix_account_menu() {
  local choice

  log_warn "Please fix the issues above before continuing."
  echo
  echo "Options:"
  echo "  [1]   Edit account name"
  echo "  [2]   Manage workspaces (add/remove)"
  echo "  [3]   Edit SSH alias"
  echo "  [4]   Edit SSH key path"
  echo "  [5]   Edit Git user.name"
  echo "  [6]   Edit Git user.email"
  echo "  [t]   Test SSH authentication again"
  echo "  [a]   Abort this account"
  echo
  read -rp "Your choice: " choice

  case "$choice" in
    1)
      fix_menu_edit_name
      ;;
    2)
      fix_menu_workspaces
      ;;
    3)
      fix_menu_edit_alias
      ;;
    4)
      fix_menu_edit_key
      ;;
    5)
      fix_menu_edit_git_name
      ;;
    6)
      fix_menu_edit_git_email
      ;;
    t|T)
      # Re-run validation by continuing the loop
      log_info "Re-testing SSH authentication..."
      ;;
    a|A)
      log_info "Account setup aborted."
      return 1
      ;;
    *)
      log_warn "Invalid choice. Please enter 1-6, t, or a."
      ;;
  esac
  return 0
}

# Interactive prompts to collect account info
# Sets global ACCOUNT_* variables directly instead of returning via stdout
prompt_account_info() {
  PROMPT_WORKSPACES=()
  prompt_account_fields

  # Validation and confirmation loop
  while true; do
    render_account_summary
    validate_account_candidate
    echo
    if [[ $PROMPT_ISSUES -eq 0 ]]; then
      publish_account_info
      return 0
    fi
    # There are issues - show menu to fix them
    fix_account_menu || return 1
  done
}
