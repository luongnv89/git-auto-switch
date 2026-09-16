#!/usr/bin/env bash
# Validate configuration

cmd_validate() {
  # Optional flags:
  #   --check-ssh  run the SSH connection test without prompting
  #   --yes, -y    assume "yes" for optional prompts (runs the SSH test)
  #   --no-prompt  never prompt; skip optional interactive checks
  local check_ssh=false
  local assume_yes=false
  local no_prompt=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check-ssh)
        check_ssh=true
        ;;
      --yes|-y)
        assume_yes=true
        ;;
      --no-prompt)
        no_prompt=true
        ;;
      *)
        die "Unknown option for 'validate': $1 (supported: --check-ssh, --yes, --no-prompt)"
        ;;
    esac
    shift
  done

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
    # Single jq projection: all fields + workspaces in one call (F-PERF-003)
    read_account_fields "$i"
    local id="$ACCT_ID" name="$ACCT_NAME" ssh_alias="$ACCT_SSH_ALIAS" ssh_key_path="$ACCT_SSH_KEY_PATH"

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

    # Check all workspaces for this account
    local workspaces_count=${#ACCT_WORKSPACES[@]}
    for ((j=0; j<workspaces_count; j++)); do
      local workspace="${ACCT_WORKSPACES[$j]}"

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
    done

    # Test SSH connection (optional, network dependent). Only prompt on an
    # interactive terminal: a non-TTY stdin (CI, scripts, </dev/null) skips
    # the test deterministically unless --check-ssh/--yes opts in.
    local test_ssh=""
    if [[ "$check_ssh" == true || "$assume_yes" == true ]]; then
      test_ssh="y"
    elif [[ "$no_prompt" == true ]] || [[ ! -t 0 ]]; then
      log_info "Skipping SSH connection test for $name (non-interactive; pass --check-ssh to run it)"
    else
      read -rp "  Test SSH connection for $name? [y/N] " test_ssh
    fi
    if [[ "$test_ssh" == "y" || "$test_ssh" == "Y" ]]; then
      # Fetch the full account JSON only when the user opts into the SSH test
      local account
      account=$(get_account_by_index "$i")
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
