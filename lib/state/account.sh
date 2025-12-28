#!/usr/bin/env bash
# Account CRUD operations on state

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
  local name ssh_alias ssh_key_path git_name git_email
  local -a workspaces=()

  echo
  read -rp "Account name (e.g., personal, work): " name
  while [[ -z "$name" ]] || ! validate_account_name "$name"; do
    log_warn "Invalid name. Use alphanumeric characters, dashes, or underscores."
    read -rp "Account name: " name
  done

  # Ask for workspaces (multiple allowed)
  echo
  log_info "Add workspace folders for this account (you can add multiple)"
  local default_workspace="$HOME/workspace/$name"
  read -rp "Workspace folder [$default_workspace]: " workspace_input
  workspace_input="${workspace_input:-$default_workspace}"
  workspaces+=("$workspace_input")

  # Ask for additional workspaces
  while true; do
    read -rp "Add another workspace? (leave empty to continue): " workspace_input
    if [[ -z "$workspace_input" ]]; then
      break
    fi
    workspaces+=("$workspace_input")
  done

  local default_alias="gh-$name"
  read -rp "SSH alias [$default_alias]: " ssh_alias
  ssh_alias="${ssh_alias:-$default_alias}"
  while ! validate_ssh_alias "$ssh_alias"; do
    log_warn "Invalid SSH alias. Use alphanumeric characters, dashes, or underscores."
    read -rp "SSH alias: " ssh_alias
  done

  # Default SSH key path inside first workspace/.ssh folder
  local default_key="${workspaces[0]}/.ssh/id_ed25519"
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
    echo "  1) Account name:   $name"
    echo "  2) Workspaces:"
    local ws_idx=0
    for ws in "${workspaces[@]}"; do
      echo "       [$ws_idx] $ws"
      ((ws_idx++))
    done
    echo "  3) SSH alias:      $ssh_alias"
    echo "  4) SSH key path:   $ssh_key_path"
    echo "  5) Git user.name:  $git_name"
    echo "  6) Git user.email: $git_email"
    echo "----------------------------------------"

    # Run validation checks
    local issues=0
    local ssh_key_exists=false
    local ssh_auth_ok=false
    echo
    log_info "Validating configuration..."

    # Check if workspaces exist
    for ws in "${workspaces[@]}"; do
      local expanded_ws
      expanded_ws=$(expand_path "$ws")
      if [[ -d "$expanded_ws" ]]; then
        log_success "Workspace exists: $expanded_ws"
      else
        log_warn "Workspace does not exist (will be created): $expanded_ws"
      fi
    done

    # Check if SSH key exists
    local expanded_key
    expanded_key=$(expand_path "$ssh_key_path")
    if [[ -f "$expanded_key" ]]; then
      log_success "SSH key exists: $expanded_key"
      ssh_key_exists=true

      # Test SSH authentication with GitHub using this key
      log_info "Testing SSH authentication with GitHub..."
      local ssh_output
      if ssh_output=$(ssh -i "$expanded_key" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -T git@github.com 2>&1); then
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
        ((issues++))
      fi
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
    if [[ $issues -eq 0 ]]; then
      # No issues - automatically proceed
      # Build workspaces JSON array
      local workspaces_json="["
      local first=true
      for ws in "${workspaces[@]}"; do
        if [[ "$first" == "true" ]]; then
          first=false
        else
          workspaces_json+=","
        fi
        workspaces_json+="\"$ws\""
      done
      workspaces_json+="]"

      # Set global variables and exit loop
      ACCOUNT_ID=$(generate_id "$name")
      ACCOUNT_NAME="$name"
      ACCOUNT_SSH_ALIAS="$ssh_alias"
      ACCOUNT_SSH_KEY_PATH="$ssh_key_path"
      ACCOUNT_WORKSPACES_JSON="$workspaces_json"
      ACCOUNT_GIT_NAME="$git_name"
      ACCOUNT_GIT_EMAIL="$git_email"
      return 0
    fi

    # There are issues - show menu to fix them
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
        # Workspace management submenu
        while true; do
          echo
          echo "Current workspaces:"
          ws_idx=0
          for ws in "${workspaces[@]}"; do
            echo "  [$ws_idx] $ws"
            ((ws_idx++))
          done
          echo
          echo "  [a] Add new workspace"
          echo "  [r] Remove workspace by index"
          echo "  [d] Done"
          echo
          read -rp "Workspace action: " ws_action
          case "$ws_action" in
            a|A)
              read -rp "New workspace folder: " new_ws
              if [[ -n "$new_ws" ]]; then
                workspaces+=("$new_ws")
                log_success "Added workspace: $new_ws"
              fi
              ;;
            r|R)
              if [[ ${#workspaces[@]} -le 1 ]]; then
                log_warn "Cannot remove the last workspace. At least one is required."
              else
                read -rp "Index to remove (0-$((${#workspaces[@]}-1))): " rm_idx
                if [[ "$rm_idx" =~ ^[0-9]+$ ]] && [[ $rm_idx -lt ${#workspaces[@]} ]]; then
                  log_info "Removed workspace: ${workspaces[$rm_idx]}"
                  unset 'workspaces[rm_idx]'
                  # Re-index array
                  workspaces=("${workspaces[@]}")
                else
                  log_warn "Invalid index."
                fi
              fi
              ;;
            d|D)
              break
              ;;
            *)
              log_warn "Invalid choice."
              ;;
          esac
        done
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
  done
}
