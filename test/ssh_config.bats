#!/usr/bin/env bats

load test_helper

@test "generate_ssh_config preserves newlines between entries" {
  init_state
  add_account "a1" "Account 1" "gh-a1" "$HOME/.ssh/id_a1" \
    '["'"$HOME"'/workspace/a"]' "User A" "a@example.com"
  add_account "a2" "Account 2" "gh-a2" "$HOME/.ssh/id_a2" \
    '["'"$HOME"'/workspace/b"]' "User B" "b@example.com"

  local ssh_config
  ssh_config=$(generate_ssh_config)

  # Check that entries are separated (not concatenated on same line)
  ! echo "$ssh_config" | grep -q "yesHost"

  # Check each host has its own line
  local host_count
  host_count=$(echo "$ssh_config" | grep -c "^Host gh-")
  [ "$host_count" -eq 2 ]
}

@test "generate_ssh_config_entry includes all required fields" {
  create_test_state

  local account
  account=$(get_account "personal")

  local entry
  entry=$(generate_ssh_config_entry "$account")

  echo "$entry" | grep -q "Host gh-personal"
  echo "$entry" | grep -q "HostName github.com"
  echo "$entry" | grep -q "User git"
  echo "$entry" | grep -q "IdentityFile $HOME/.ssh/id_personal"
  echo "$entry" | grep -q "IdentitiesOnly yes"
}

@test "apply_ssh_config creates valid config file" {
  create_test_state

  # Create a mock existing SSH config
  echo "Host existing" > "$SSH_CONFIG"
  echo "  User testuser" >> "$SSH_CONFIG"

  apply_ssh_config

  # Check existing content is preserved
  grep -q "Host existing" "$SSH_CONFIG"

  # Check managed block is added
  grep -q "$MARKER_START" "$SSH_CONFIG"
  grep -q "$MARKER_END" "$SSH_CONFIG"
  grep -q "Host gh-personal" "$SSH_CONFIG"
}

@test "remove_managed_ssh_config removes only managed block" {
  # Create config with existing and managed content
  cat > "$SSH_CONFIG" << 'EOF'
Host existing
  User testuser

# === GIT-AUTO-SWITCH MANAGED START ===
Host gh-test
  HostName github.com
# === GIT-AUTO-SWITCH MANAGED END ===

Host another
  User anotheruser
EOF

  remove_managed_ssh_config

  # Check managed block is removed
  ! grep -q "$MARKER_START" "$SSH_CONFIG"
  ! grep -q "Host gh-test" "$SSH_CONFIG"

  # Check other content is preserved
  grep -q "Host existing" "$SSH_CONFIG"
  grep -q "Host another" "$SSH_CONFIG"
}
