backup_configs() {
  echo "🛟 Backing up existing configs..."
  cp -a ~/.ssh/config "$BACKUP_DIR/ssh_config.bak" 2>/dev/null || true
  cp -a ~/.gitconfig "$BACKUP_DIR/gitconfig.bak" 2>/dev/null || true
  cp -a ~/.gitconfig-* "$BACKUP_DIR/" 2>/dev/null || true
}

clean_old_configs() {
  echo "🧼 Cleaning old managed blocks..."

  # SSH
  if [[ -f ~/.ssh/config ]]; then
    sed -i.bak '/# === GIT-AUTO-SWITCH START ===/,/# === GIT-AUTO-SWITCH END ===/d' ~/.ssh/config
  fi

  # Git includeIf
  git config --global --unset-all includeIf.gitdir || true
}