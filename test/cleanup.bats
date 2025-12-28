#!/usr/bin/env bats

load test_helper

@test "backup_configs creates backup directory" {
  source "$PROJECT_ROOT/lib/cleanup.sh"

  # Create files to backup
  echo "Host example" > "$HOME/.ssh/config"
  echo "[user]" > "$HOME/.gitconfig"

  backup_configs

  [ -f "$BACKUP_DIR/ssh_config.bak" ]
  [ -f "$BACKUP_DIR/gitconfig.bak" ]
}

@test "backup_configs handles missing files gracefully" {
  source "$PROJECT_ROOT/lib/cleanup.sh"

  # No files exist - should not fail
  run backup_configs
  [ "$status" -eq 0 ]
}

@test "clean_old_configs removes managed SSH blocks" {
  source "$PROJECT_ROOT/lib/cleanup.sh"

  cat > "$HOME/.ssh/config" <<EOF
Host personal
  User git

# === GIT-AUTO-SWITCH START ===
Host gh-work
  HostName github.com
# === GIT-AUTO-SWITCH END ===

Host other
  User someone
EOF

  clean_old_configs

  # Managed block should be removed
  ! grep -q "GIT-AUTO-SWITCH" "$HOME/.ssh/config"
  # Other entries should remain
  grep -q "Host personal" "$HOME/.ssh/config"
  grep -q "Host other" "$HOME/.ssh/config"
}

@test "clean_old_configs handles missing SSH config" {
  source "$PROJECT_ROOT/lib/cleanup.sh"

  # No SSH config exists
  rm -f "$HOME/.ssh/config"

  run clean_old_configs
  [ "$status" -eq 0 ]
}
