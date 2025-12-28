#!/usr/bin/env bash
# Validate configuration

cmd_validate() {
  # Check if initialized
  if ! load_state; then
    die "Not initialized. Run 'git-auto-switch init' first."
  fi

  echo
  echo "========================================"
  echo "  Configuration Validation"
  echo "========================================"
  echo

  local errors=0
  local warnings=0

  # Validate state structure
  log_info "Validating state file..."
  if validate_state; then
    log_success "State file is valid"
  else
    log_error "State file has errors"
    ((errors++))
  fi

  local account_count
  account_count=$(get_account_count)

  if [[ $account_count -eq 0 ]]; then
    log_warn "No accounts configured"
    ((warnings++))
    echo
    echo "Validation complete: $errors errors, $warnings warnings"
    return 0
  fi

  # Validate each account
  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")

    local id name ssh_alias ssh_key_path workspace
    id=$(echo "$account" | jq -r '.id')
    name=$(echo "$account" | jq -r '.name')
    ssh_alias=$(echo "$account" | jq -r '.ssh_alias')
    ssh_key_path=$(echo "$account" | jq -r '.ssh_key_path')
    workspace=$(echo "$account" | jq -r '.workspace')

    echo
    log_info "Validating account: $name ($id)"

    # Check SSH key exists
    local expanded_key
    expanded_key=$(expand_path "$ssh_key_path")
    if [[ -f "$expanded_key" ]]; then
      log_success "SSH key exists: $expanded_key"
    else
      log_error "SSH key missing: $expanded_key"
      ((errors++))
    fi

    # Check SSH config entry
    if grep -q "Host $ssh_alias" "$SSH_CONFIG" 2>/dev/null; then
      log_success "SSH config entry exists for $ssh_alias"
    else
      log_error "SSH config entry missing for $ssh_alias"
      ((errors++))
    fi

    # Check per-account gitconfig
    local git_config_file="$HOME/.gitconfig-$id"
    if [[ -f "$git_config_file" ]]; then
      log_success "Git config file exists: $git_config_file"
    else
      log_error "Git config file missing: $git_config_file"
      ((errors++))
    fi

    # Check workspace directory
    local expanded_workspace
    expanded_workspace=$(expand_path "$workspace")
    if [[ -d "$expanded_workspace" ]]; then
      log_success "Workspace exists: $expanded_workspace"
    else
      log_warn "Workspace does not exist: $expanded_workspace"
      ((warnings++))
    fi

    # Check includeIf entry
    if grep -q "gitdir:${expanded_workspace}/" "$GIT_CONFIG" 2>/dev/null; then
      log_success "Git includeIf entry exists for $workspace"
    else
      log_error "Git includeIf entry missing for $workspace"
      ((errors++))
    fi

    # Test SSH connection (optional, network dependent)
    read -rp "  Test SSH connection for $name? [y/N] " test_ssh
    if [[ "$test_ssh" == "y" || "$test_ssh" == "Y" ]]; then
      if validate_ssh_connection "$account"; then
        log_success "SSH connection successful"
      else
        log_error "SSH connection failed"
        ((errors++))
      fi
    fi
  done

  # Check pre-commit hook
  echo
  log_info "Validating pre-commit hook..."
  if validate_hook; then
    log_success "Pre-commit hook is properly configured"
  else
    log_error "Pre-commit hook has issues"
    ((errors++))
  fi

  # Summary
  echo
  echo "========================================"
  if [[ $errors -eq 0 ]]; then
    log_success "Validation passed: $errors errors, $warnings warnings"
  else
    log_error "Validation failed: $errors errors, $warnings warnings"
    echo
    echo "Run 'git-auto-switch apply' to fix configuration issues"
    return 1
  fi

  return 0
}
