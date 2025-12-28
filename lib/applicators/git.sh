#!/usr/bin/env bash
# Apply Git configuration

# Backup Git config
backup_git_config() {
  create_backup "$GIT_CONFIG" "gitconfig"

  # Also backup per-account configs
  for f in "$HOME"/.gitconfig-*; do
    if [[ -f "$f" ]]; then
      create_backup "$f" "$(basename "$f")"
    fi
  done
}

# Remove managed includeIf blocks from ~/.gitconfig
remove_managed_git_includes() {
  if [[ ! -f "$GIT_CONFIG" ]]; then
    return 0
  fi

  if grep -q "$MARKER_START" "$GIT_CONFIG"; then
    # Create backup first
    cp "$GIT_CONFIG" "$GIT_CONFIG.bak"

    # Remove the managed block
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "/$MARKER_START/,/$MARKER_END/d" "$GIT_CONFIG"
    else
      sed -i "/$MARKER_START/,/$MARKER_END/d" "$GIT_CONFIG"
    fi

    log_info "Removed existing managed Git includeIf blocks"
  fi
}

# Create per-account gitconfig file
create_git_config_file() {
  local account_json="$1"

  local id
  id=$(echo "$account_json" | jq -r '.id')

  local config_path="$HOME/.gitconfig-$id"
  local content
  content=$(generate_git_config_file "$account_json")

  echo "$content" > "$config_path"
  log_info "Created Git config: $config_path"
}

# Apply Git configuration for all accounts
apply_git_config() {
  require_jq

  # Backup existing configs
  backup_git_config

  # Remove old managed includeIf blocks
  remove_managed_git_includes

  # Create per-account config files
  local account_count
  account_count=$(get_account_count)

  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")
    create_git_config_file "$account"
  done

  # Generate and append includeIf blocks
  local include_block
  include_block=$(generate_git_include_block)

  # Ensure .gitconfig exists
  touch "$GIT_CONFIG"

  echo "$include_block" >> "$GIT_CONFIG"

  log_success "Git config updated with includeIf blocks"
}

# Set default Git identity
set_default_git_identity() {
  local account_json="$1"

  local git_name git_email
  git_name=$(echo "$account_json" | jq -r '.git_name')
  git_email=$(echo "$account_json" | jq -r '.git_email')

  git config --global user.name "$git_name"
  git config --global user.email "$git_email"

  log_success "Set default Git identity: $git_name <$git_email>"
}

# Validate Git config for an account
validate_git_config() {
  local account_json="$1"

  local id git_email workspaces_count
  id=$(echo "$account_json" | jq -r '.id')
  git_email=$(echo "$account_json" | jq -r '.git_email')
  workspaces_count=$(echo "$account_json" | jq '.workspaces | length')

  local errors=0

  # Check per-account config file exists
  local config_path="$HOME/.gitconfig-$id"
  if [[ ! -f "$config_path" ]]; then
    log_error "Missing Git config file: $config_path"
    ((errors++))
  fi

  # Check each workspace
  for ((i=0; i<workspaces_count; i++)); do
    local workspace expanded_workspace
    workspace=$(echo "$account_json" | jq -r ".workspaces[$i]")
    expanded_workspace=$(expand_path "$workspace")

    # Check workspace directory exists
    if [[ ! -d "$expanded_workspace" ]]; then
      log_warn "Workspace directory does not exist: $expanded_workspace"
    fi

    # Check includeIf entry exists in .gitconfig
    if ! grep -q "gitdir:${expanded_workspace}/" "$GIT_CONFIG" 2>/dev/null; then
      log_error "Missing includeIf entry for workspace: $workspace"
      ((errors++))
    fi
  done

  return $errors
}
