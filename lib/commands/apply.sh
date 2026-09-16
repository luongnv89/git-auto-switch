#!/usr/bin/env bash
# Apply configuration from state to system

cmd_apply() {
  # Check if initialized
  if ! load_state; then
    die "Not initialized. Run 'git-auto-switch init' first."
  fi

  # Parse flags. --no-passphrase explicitly opts out of encrypted-key
  # creation for any keys generated during this run (logged by ensure_ssh_key).
  local no_passphrase="false"
  local target=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-passphrase)
        no_passphrase="true"
        shift
        ;;
      -h|--help)
        show_help
        return 0
        ;;
      *)
        if [[ -z "$target" ]]; then
          target="$1"
        else
          die "Unknown argument: $1 (usage: gas apply [--no-passphrase] [id|ssh_alias])"
        fi
        shift
        ;;
    esac
  done
  if [[ "${GAS_NO_PASSPHRASE:-false}" == "true" ]]; then
    no_passphrase="true"
  fi

  # Validate state before applying
  if ! validate_state; then
    die "Invalid state. Fix errors and try again."
  fi

  # If an account ID is given, apply that account to the current repo only.
  if [[ -n "$target" ]]; then
    apply_to_current_repo "$target"
    return $?
  fi

  local account_count
  account_count=$(get_account_count)

  if [[ $account_count -eq 0 ]]; then
    log_warn "No accounts configured. Nothing to apply."
    return 0
  fi

  echo
  log_info "Applying configuration for $account_count account(s)..."
  echo

  # Step 1: Ensure SSH keys exist
  log_info "Step 1/5: Checking SSH keys..."
  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")
    ensure_ssh_key "$account" "$no_passphrase"
  done

  # Step 1b: Verify github.com host keys before trusting them.
  log_info "Verifying github.com SSH host keys..."
  ensure_github_known_hosts

  # Step 2: Apply SSH config
  log_info "Step 2/5: Updating SSH config..."
  apply_ssh_config

  # Step 3: Apply Git config
  log_info "Step 3/5: Updating Git config..."
  apply_git_config

  # Step 4: Install pre-commit hook
  log_info "Step 4/5: Installing pre-commit hook..."
  apply_pre_commit_hook
  configure_global_hooks

  # Step 5: Rewrite remotes
  log_info "Step 5/5: Rewriting repository remotes..."
  rewrite_all_remotes

  # Update last_applied in state
  save_state

  echo
  log_success "Configuration applied successfully!"
  echo
  echo "Summary:"
  echo "  - SSH config updated with $account_count host alias(es)"
  echo "  - Git includeIf blocks configured for $account_count workspace(s)"
  echo "  - Pre-commit hook installed at $HOOKS_DIR/pre-commit"
  echo
  echo "Test SSH connections with:"
  local ssh_alias
  while IFS= read -r ssh_alias; do
    echo "  ssh -T git@$ssh_alias"
  done <<< "$(echo "$STATE_JSON" | jq -r '.accounts[].ssh_alias // empty')"
  echo
}

# Apply a single account's identity to the current git repository.
# The argument may be either the account ID or the account's SSH alias.
# Sets local user.name/user.email and rewrites the origin remote to use
# the SSH alias. If the alias is missing from ~/.ssh/config it is added,
# so this works even when the user has never run a system-wide apply.
apply_to_current_repo() {
  local key="$1"

  local account
  account=$(get_account_by_id_or_alias "$key")
  if [[ -z "$account" ]]; then
    die "Account '$key' not found (looked up by id and ssh_alias). Run 'git-auto-switch list' to see available accounts."
  fi

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    die "Not in a git repository. Run this command from inside the repository you want to configure."
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  # Single jq projection: all fields in one call (F-PERF-003)
  parse_account_fields "$account"
  local id="$ACCT_ID" ssh_alias="$ACCT_SSH_ALIAS" ssh_key_path="$ACCT_SSH_KEY_PATH" git_name="$ACCT_GIT_NAME" git_email="$ACCT_GIT_EMAIL"

  echo
  log_info "Applying account '$id' to repository: $repo_root"
  echo

  # Make sure the SSH host alias resolves. Only rewrite ~/.ssh/config when
  # the alias is missing — avoids creating a backup on every invocation.
  log_info "Step 1/3: Checking SSH config..."
  if grep -q "^Host $ssh_alias\$" "$SSH_CONFIG" 2>/dev/null; then
    log_info "SSH alias '$ssh_alias' already present in $SSH_CONFIG"
  else
    log_info "SSH alias '$ssh_alias' missing — refreshing $SSH_CONFIG"
    apply_ssh_config
  fi

  # Warn (don't fail) if the SSH key file does not exist; the user can fix
  # this later by running `git-auto-switch apply` (system-wide) which will
  # generate the key.
  local expanded_key
  expanded_key=$(expand_path "$ssh_key_path")
  if [[ ! -f "$expanded_key" ]]; then
    log_warn "SSH key not found: $expanded_key"
    log_warn "Run 'git-auto-switch apply' (no args) to generate the key."
  fi

  # Set local Git identity for this repository.
  log_info "Step 2/3: Setting local Git identity..."
  git -C "$repo_root" config user.name "$git_name"
  git -C "$repo_root" config user.email "$git_email"
  log_success "Set local Git identity: $git_name <$git_email>"

  # Rewrite the origin remote to use the SSH host alias. If the remote
  # currently points at a different alias (e.g. user is switching from
  # 'personal' to 'work'), normalize it back to github.com first so the
  # shared rewriter can process it. The character class excludes '.', so
  # genuine github.com URLs never match this branch — they are passed
  # through to rewrite_repo_remotes which handles them directly.
  log_info "Step 3/3: Rewriting origin remote..."
  local origin_url
  origin_url=$(git -C "$repo_root" remote get-url origin 2>/dev/null || echo "")
  if [[ -n "$origin_url" && "$origin_url" =~ ^git@([a-zA-Z0-9_-]+):(.*)$ ]]; then
    local current_host="${BASH_REMATCH[1]}"
    if [[ "$current_host" != "$ssh_alias" ]]; then
      git -C "$repo_root" remote set-url origin "git@github.com:${BASH_REMATCH[2]}"
    fi
  elif [[ -n "$origin_url" && "$origin_url" =~ ^ssh://git@([a-zA-Z0-9_-]+)/(.*)$ ]]; then
    # Same normalization for ssh:// remotes already pointing at some alias:
    # ssh://git@<alias>/path -> git@github.com:path so the shared rewriter
    # emits the canonical scp-style form. The host class excludes '.', so
    # ssh://git@github.com/... never matches and is handled by the rewriter.
    if [[ "${BASH_REMATCH[1]}" != "$ssh_alias" ]]; then
      git -C "$repo_root" remote set-url origin "git@github.com:${BASH_REMATCH[2]}"
    fi
  fi
  rewrite_repo_remotes "$repo_root" "$ssh_alias"

  echo
  log_success "Applied '$id' to $repo_root"
  echo
  echo "Verify with:"
  echo "  git -C \"$repo_root\" config --local --get user.email"
  echo "  git -C \"$repo_root\" remote get-url origin"
  echo "  ssh -T git@$ssh_alias"
  echo
}
