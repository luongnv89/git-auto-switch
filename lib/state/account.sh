#!/usr/bin/env bash
# Account CRUD operations on state

# Add account to state
add_account() {
  local id="$1"
  local name="$2"
  local ssh_alias="$3"
  local ssh_key_path="$4"
  local workspace="$5"
  local git_name="$6"
  local git_email="$7"

  require_jq

  # Validate inputs
  if ! validate_account_name "$id"; then
    die "Invalid account ID: $id (must be alphanumeric with dashes/underscores)"
  fi

  if ! validate_ssh_alias "$ssh_alias"; then
    die "Invalid SSH alias: $ssh_alias (must be alphanumeric with dashes/underscores)"
  fi

  if ! validate_email "$git_email"; then
    die "Invalid email format: $git_email"
  fi

  # Check for duplicates
  if account_exists "$id"; then
    die "Account with ID '$id' already exists"
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Add account to state
  STATE_JSON=$(echo "$STATE_JSON" | jq \
    --arg id "$id" \
    --arg name "$name" \
    --arg ssh_alias "$ssh_alias" \
    --arg ssh_key_path "$ssh_key_path" \
    --arg workspace "$workspace" \
    --arg git_name "$git_name" \
    --arg git_email "$git_email" \
    --arg created_at "$timestamp" \
    '.accounts += [{
      id: $id,
      name: $name,
      ssh_alias: $ssh_alias,
      ssh_key_path: $ssh_key_path,
      workspace: $workspace,
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

# Update account field
update_account() {
  local id="$1"
  local field="$2"
  local value="$3"

  require_jq

  if ! account_exists "$id"; then
    die "Account with ID '$id' does not exist"
  fi

  STATE_JSON=$(echo "$STATE_JSON" | jq \
    --arg id "$id" \
    --arg field "$field" \
    --arg value "$value" \
    '(.accounts[] | select(.id == $id))[$field] = $value')

  log_success "Updated $field for account: $id"
}

# Interactive prompts to collect account info
# Sets global ACCOUNT_* variables directly instead of returning via stdout
prompt_account_info() {
  local name ssh_alias ssh_key_path workspace git_name git_email

  echo
  read -rp "Account name (e.g., personal, work): " name
  while [[ -z "$name" ]] || ! validate_account_name "$name"; do
    log_warn "Invalid name. Use alphanumeric characters, dashes, or underscores."
    read -rp "Account name: " name
  done

  # Ask for workspace first so we can use it for SSH key default path
  local default_workspace="$HOME/workspace/$name"
  read -rp "Workspace folder [$default_workspace]: " workspace
  workspace="${workspace:-$default_workspace}"

  # Expand workspace path for use in default key path
  local expanded_workspace
  expanded_workspace=$(expand_path "$workspace")

  local default_alias="gh-$name"
  read -rp "SSH alias [$default_alias]: " ssh_alias
  ssh_alias="${ssh_alias:-$default_alias}"
  while ! validate_ssh_alias "$ssh_alias"; do
    log_warn "Invalid SSH alias. Use alphanumeric characters, dashes, or underscores."
    read -rp "SSH alias: " ssh_alias
  done

  # Default SSH key path inside workspace/.ssh folder
  local default_key="$workspace/.ssh/id_ed25519"
  read -rp "SSH key path [$default_key]: " ssh_key_path
  ssh_key_path="${ssh_key_path:-$default_key}"

  read -rp "Git user.name: " git_name
  while [[ -z "$git_name" ]]; do
    log_warn "Git name is required."
    read -rp "Git user.name: " git_name
  done

  read -rp "Git user.email: " git_email
  while [[ -z "$git_email" ]] || ! validate_email "$git_email"; do
    log_warn "Please enter a valid email address."
    read -rp "Git user.email: " git_email
  done

  # Validation and confirmation loop
  while true; do
    echo
    echo "----------------------------------------"
    echo "  Account Summary"
    echo "----------------------------------------"
    echo "  1) Account name:  $name"
    echo "  2) Workspace:     $workspace"
    echo "  3) SSH alias:     $ssh_alias"
    echo "  4) SSH key path:  $ssh_key_path"
    echo "  5) Git user.name: $git_name"
    echo "  6) Git user.email: $git_email"
    echo "----------------------------------------"

    # Run validation checks
    local issues=0
    echo
    log_info "Validating configuration..."

    # Check if workspace exists
    expanded_workspace=$(expand_path "$workspace")
    if [[ -d "$expanded_workspace" ]]; then
      log_success "Workspace exists: $expanded_workspace"
    else
      log_warn "Workspace does not exist (will be created): $expanded_workspace"
    fi

    # Check if SSH key exists
    local expanded_key
    expanded_key=$(expand_path "$ssh_key_path")
    if [[ -f "$expanded_key" ]]; then
      log_success "SSH key exists: $expanded_key"
    else
      log_warn "SSH key does not exist (will be generated): $expanded_key"
    fi

    # Check for duplicate account name
    local account_id
    account_id=$(generate_id "$name")
    if account_exists "$account_id"; then
      log_error "Account '$name' already exists!"
      ((issues++))
    fi

    echo
    if [[ $issues -gt 0 ]]; then
      log_warn "Please fix the issues above before continuing."
      echo
    fi

    echo "Options:"
    echo "  [1-6] Edit a field"
    echo "  [c]   Confirm and save"
    echo "  [a]   Abort this account"
    echo
    read -rp "Your choice: " choice

    case "$choice" in
      1)
        read -rp "Account name [$name]: " new_val
        if [[ -n "$new_val" ]]; then
          if validate_account_name "$new_val"; then
            name="$new_val"
          else
            log_warn "Invalid name. Use alphanumeric characters, dashes, or underscores."
          fi
        fi
        ;;
      2)
        read -rp "Workspace folder [$workspace]: " new_val
        [[ -n "$new_val" ]] && workspace="$new_val"
        ;;
      3)
        read -rp "SSH alias [$ssh_alias]: " new_val
        if [[ -n "$new_val" ]]; then
          if validate_ssh_alias "$new_val"; then
            ssh_alias="$new_val"
          else
            log_warn "Invalid SSH alias. Use alphanumeric characters, dashes, or underscores."
          fi
        fi
        ;;
      4)
        read -rp "SSH key path [$ssh_key_path]: " new_val
        [[ -n "$new_val" ]] && ssh_key_path="$new_val"
        ;;
      5)
        read -rp "Git user.name [$git_name]: " new_val
        [[ -n "$new_val" ]] && git_name="$new_val"
        ;;
      6)
        read -rp "Git user.email [$git_email]: " new_val
        if [[ -n "$new_val" ]]; then
          if validate_email "$new_val"; then
            git_email="$new_val"
          else
            log_warn "Invalid email format."
          fi
        fi
        ;;
      c|C)
        if [[ $issues -gt 0 ]]; then
          log_warn "Cannot confirm with unresolved issues. Please fix them first."
        else
          # Set global variables and exit loop
          ACCOUNT_ID=$(generate_id "$name")
          ACCOUNT_NAME="$name"
          ACCOUNT_SSH_ALIAS="$ssh_alias"
          ACCOUNT_SSH_KEY_PATH="$ssh_key_path"
          ACCOUNT_WORKSPACE="$workspace"
          ACCOUNT_GIT_NAME="$git_name"
          ACCOUNT_GIT_EMAIL="$git_email"
          return 0
        fi
        ;;
      a|A)
        log_info "Account setup aborted."
        return 1
        ;;
      *)
        log_warn "Invalid choice. Please enter 1-6, c, or a."
        ;;
    esac
  done
}
