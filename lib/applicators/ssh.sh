#!/usr/bin/env bash
# Apply SSH configuration

# GitHub's published SSH host-key fingerprints.
# Source: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
# These constants are the trust anchor for ensure_github_known_hosts — they
# are never fetched over the network, so a MITM cannot feed us its own keys.
GAS_GITHUB_FINGERPRINT_RSA="SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s"
GAS_GITHUB_FINGERPRINT_ECDSA="SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM"
GAS_GITHUB_FINGERPRINT_ED25519="SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU"

# Known-good github.com host-key lines (same docs page as above).
gas_github_known_host_keys() {
  cat <<'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
EOF
}

# Verify github.com host keys against the published fingerprints above and
# record the verified keys in known_hosts. Aborts (non-zero) on mismatch.
# Never prompts — safe to call headless in CI. Honors GAS_SSH_KNOWN_HOSTS
# to override the known_hosts path (test hook).
ensure_github_known_hosts() {
  local known_hosts_file="${GAS_SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"

  local scan_output
  if ! scan_output=$(ssh-keyscan -t rsa,ecdsa,ed25519 github.com 2>/dev/null); then
    log_error "Could not retrieve github.com host keys (ssh-keyscan failed). Refusing to trust host keys blindly — aborting."
    return 1
  fi
  if [[ -z "$scan_output" ]]; then
    log_error "Empty ssh-keyscan result for github.com. Refusing to trust host keys blindly — aborting."
    return 1
  fi

  local allowed
  allowed=$(gas_github_known_host_keys)

  local verified=()
  local line keytype keyblob
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    # ssh-keyscan format: <host> <keytype> <base64> [comment]
    keytype=$(echo "$line" | awk '{print $2}')
    keyblob=$(echo "$line" | awk '{print $3}')
    [[ -z "$keytype" || -z "$keyblob" ]] && continue
    if echo "$allowed" | grep -qF "$keyblob"; then
      verified+=("github.com $keytype $keyblob")
    fi
  done <<< "$scan_output"

  if [[ ${#verified[@]} -eq 0 ]]; then
    log_error "github.com host key fingerprint mismatch! None of the scanned keys match GitHub's published fingerprints."
    log_error "Expected (https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints):"
    log_error "  RSA:     $GAS_GITHUB_FINGERPRINT_RSA"
    log_error "  ECDSA:   $GAS_GITHUB_FINGERPRINT_ECDSA"
    log_error "  Ed25519: $GAS_GITHUB_FINGERPRINT_ED25519"
    log_error "Aborting — refusing to trust unverified host keys."
    return 1
  fi

  mkdir -p "$(dirname "$known_hosts_file")"
  touch "$known_hosts_file"
  chmod 600 "$known_hosts_file"

  local entry
  for entry in "${verified[@]}"; do
    if ! grep -qF "$entry" "$known_hosts_file" 2>/dev/null; then
      echo "$entry" >> "$known_hosts_file"
    fi
  done

  log_success "Verified github.com host keys against published fingerprints"
}

# Ensure SSH key exists, generate if missing
# Usage: ensure_ssh_key <account_json> [--no-passphrase|true|false] [no_prompt]
# Honors GAS_NO_PASSPHRASE=true and GAS_SSH_PASSPHRASE (non-interactive/test hook).
# Default posture: prompt for a passphrase; an empty passphrase is rejected
# unless the caller explicitly opts out with --no-passphrase (logged).
# Third arg (optional): when "true", never wait on any prompt — used by
# `apply --yes`/`--no-prompt`. Every prompt is also skipped automatically
# whenever stdin is not a TTY.
ensure_ssh_key() {
  local account_json="$1"
  local opt="${2:-false}"
  local no_prompt="${3:-false}"

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

  local no_passphrase="false"
  if [[ "$opt" == "--no-passphrase" || "$opt" == "true" || "${GAS_NO_PASSPHRASE:-false}" == "true" ]]; then
    no_passphrase="true"
  fi

  local passphrase=""
  if [[ "$no_passphrase" == "true" ]]; then
    log_warn "Creating UNENCRYPTED SSH key for $name (explicit --no-passphrase opt-out)."
  else
    if [[ -n "${GAS_SSH_PASSPHRASE:-}" ]]; then
      passphrase="$GAS_SSH_PASSPHRASE"
    elif [[ -t 0 ]] && [[ "$no_prompt" != "true" ]]; then
      read -r -s -p "Enter passphrase for new SSH key [$expanded_path] (empty requires --no-passphrase): " passphrase
      echo
      if [[ -z "$passphrase" ]]; then
        log_error "Empty passphrase requires explicit --no-passphrase to create an unencrypted key. Aborting."
        return 1
      fi
      local confirm=""
      read -r -s -p "Confirm passphrase: " confirm
      echo
      if [[ "$passphrase" != "$confirm" ]]; then
        log_error "Passphrases do not match. Aborting."
        return 1
      fi
    else
      log_error "Cannot prompt for SSH key passphrase (non-interactive). Set GAS_SSH_PASSPHRASE or re-run with --no-passphrase for an explicit unencrypted-key opt-out. Aborting."
      return 1
    fi
    if [[ -z "$passphrase" ]]; then
      log_error "Empty passphrase requires explicit --no-passphrase to create an unencrypted key. Aborting."
      return 1
    fi
  fi

  log_info "Generating SSH key for $name..."
  mkdir -p "$(dirname "$expanded_path")"
  if [[ "$no_passphrase" == "true" ]]; then
    ssh-keygen -t ed25519 -f "$expanded_path" -C "$git_email" -N ""
    log_warn "Generated unencrypted SSH key: $expanded_path (explicit opt-out recorded)"
  else
    ssh-keygen -t ed25519 -f "$expanded_path" -C "$git_email" -N "$passphrase"
    log_success "SSH key generated (encrypted): $expanded_path"
  fi
  echo
  echo "Add this public key to your GitHub account:"
  echo "https://github.com/settings/ssh/new"
  echo
  cat "${expanded_path}.pub"
  echo
  # Pause only on an interactive terminal — a non-TTY stdin (CI, scripts,
  # </dev/null) or --yes/--no-prompt must never block on read (F-BUG-008).
  if [[ "$no_prompt" == "true" ]] || [[ ! -t 0 ]]; then
    log_info "Non-interactive mode: add the key above to GitHub, then re-run 'gas apply' if needed."
  else
    read -rp "Press Enter after adding the key to GitHub..."
  fi
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
