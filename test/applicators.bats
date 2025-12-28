#!/usr/bin/env bats

load test_helper

@test "apply_ssh_config creates SSH config with markers" {
  create_test_state

  apply_ssh_config

  # Check SSH config file exists
  [ -f "$SSH_CONFIG" ]

  # Check markers are present
  grep -q "$MARKER_START" "$SSH_CONFIG"
  grep -q "$MARKER_END" "$SSH_CONFIG"

  # Check host entry
  grep -q "Host gh-personal" "$SSH_CONFIG"
}

@test "remove_managed_ssh_config removes only managed block" {
  # Create SSH config with managed and unmanaged content
  cat > "$SSH_CONFIG" <<EOF
Host existing-host
  HostName example.com

$MARKER_START
Host gh-old
  HostName github.com
$MARKER_END

Host another-host
  HostName test.com
EOF

  remove_managed_ssh_config

  # Managed block should be removed
  ! grep -q "gh-old" "$SSH_CONFIG"
  ! grep -q "$MARKER_START" "$SSH_CONFIG"

  # Other content should remain
  grep -q "existing-host" "$SSH_CONFIG"
  grep -q "another-host" "$SSH_CONFIG"
}

@test "apply_git_config creates per-account config files" {
  create_test_state

  apply_git_config

  # Check per-account config exists
  [ -f "$HOME/.gitconfig-personal" ]

  # Check content
  grep -q "john@personal.com" "$HOME/.gitconfig-personal"
}

@test "apply_pre_commit_hook creates executable hook" {
  apply_pre_commit_hook

  # Check hook exists
  [ -f "$HOOKS_DIR/pre-commit" ]

  # Check it's executable
  [ -x "$HOOKS_DIR/pre-commit" ]
}

@test "backup creates timestamped backup" {
  # Create a file to backup
  echo "test content" > "$SSH_CONFIG"

  backup_ssh_config

  # Check backup directory was created
  local backup_count
  backup_count=$(find "$BACKUP_DIR" -name "ssh_config" 2>/dev/null | wc -l)
  [ "$backup_count" -ge 1 ]
}
