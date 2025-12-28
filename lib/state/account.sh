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
prompt_account_info() {
  local name ssh_alias ssh_key_path workspace git_name git_email

  echo
  read -rp "Account name (e.g., personal, work): " name
  while [[ -z "$name" ]] || ! validate_account_name "$name"; do
    log_warn "Invalid name. Use alphanumeric characters, dashes, or underscores."
    read -rp "Account name: " name
  done

  local default_alias="gh-$name"
  read -rp "SSH alias [$default_alias]: " ssh_alias
  ssh_alias="${ssh_alias:-$default_alias}"
  while ! validate_ssh_alias "$ssh_alias"; do
    log_warn "Invalid SSH alias. Use alphanumeric characters, dashes, or underscores."
    read -rp "SSH alias: " ssh_alias
  done

  local default_key="$HOME/.ssh/id_ed25519_$name"
  read -rp "SSH key path [$default_key]: " ssh_key_path
  ssh_key_path="${ssh_key_path:-$default_key}"

  read -rp "Workspace folder (e.g., ~/workspace/$name): " workspace
  while [[ -z "$workspace" ]]; do
    log_warn "Workspace is required."
    read -rp "Workspace folder: " workspace
  done

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

  # Return as JSON for easy parsing
  local id
  id=$(generate_id "$name")

  echo "$id|$name|$ssh_alias|$ssh_key_path|$workspace|$git_name|$git_email"
}

# Parse account info from prompt result
parse_account_info() {
  local info="$1"
  IFS='|' read -r ACCOUNT_ID ACCOUNT_NAME ACCOUNT_SSH_ALIAS ACCOUNT_SSH_KEY_PATH \
    ACCOUNT_WORKSPACE ACCOUNT_GIT_NAME ACCOUNT_GIT_EMAIL <<< "$info"
}
