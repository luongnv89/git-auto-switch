#!/usr/bin/env bash
# Apply SSH configuration

# Ensure SSH key exists, generate if missing
ensure_ssh_key() {
  local account_json="$1"

  local ssh_key_path git_email name
  ssh_key_path=$(echo "$account_json" | jq -r '.ssh_key_path')
  git_email=$(echo "$account_json" | jq -r '.git_email')
  name=$(echo "$account_json" | jq -r '.name')

  local expanded_path
  expanded_path=$(expand_path "$ssh_key_path")

  if [[ -f "$expanded_path" ]]; then
    log_info "SSH key exists: $expanded_path"
    return 0
  fi

  log_info "Generating SSH key for $name..."
  mkdir -p "$(dirname "$expanded_path")"
  ssh-keygen -t ed25519 -f "$expanded_path" -C "$git_email" -N ""

  log_success "SSH key generated: $expanded_path"
  echo
  echo "Add this public key to your GitHub account:"
  echo "https://github.com/settings/ssh/new"
  echo
  cat "${expanded_path}.pub"
  echo
  read -rp "Press Enter after adding the key to GitHub..."
}

# Backup SSH config
backup_ssh_config() {
  create_backup "$SSH_CONFIG" "ssh_config"
}

# Remove managed SSH config block
remove_managed_ssh_config() {
  if [[ ! -f "$SSH_CONFIG" ]]; then
    return 0
  fi

  # Use sed to remove managed block
  if grep -q "$MARKER_START" "$SSH_CONFIG"; then
    # Create backup first
    cp "$SSH_CONFIG" "$SSH_CONFIG.bak"

    # Remove the managed block (sed compatible with both macOS and Linux)
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "/$MARKER_START/,/$MARKER_END/d" "$SSH_CONFIG"
    else
      sed -i "/$MARKER_START/,/$MARKER_END/d" "$SSH_CONFIG"
    fi

    log_info "Removed existing managed SSH config block"
  fi
}

# Apply SSH config for all accounts
apply_ssh_config() {
  require_jq

  # Ensure .ssh directory exists
  mkdir -p "$HOME/.ssh"
  touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"

  # Backup existing config
  backup_ssh_config

  # Remove old managed block
  remove_managed_ssh_config

  # Generate and append new config
  local ssh_block
  ssh_block=$(generate_ssh_config)

  echo "$ssh_block" >> "$SSH_CONFIG"

  log_success "SSH config updated"
}

# Validate SSH connection for an account
validate_ssh_connection() {
  local account_json="$1"

  local ssh_alias name
  ssh_alias=$(echo "$account_json" | jq -r '.ssh_alias')
  name=$(echo "$account_json" | jq -r '.name')

  log_info "Testing SSH connection for $name..."

  # Test SSH connection (GitHub returns exit code 1 with success message)
  local output
  if output=$(ssh -T "git@$ssh_alias" 2>&1); then
    log_success "SSH connection successful for $name"
    return 0
  elif echo "$output" | grep -q "successfully authenticated"; then
    log_success "SSH connection successful for $name"
    return 0
  else
    log_error "SSH connection failed for $name: $output"
    return 1
  fi
}
