#!/usr/bin/env bash
set -e

PROJECT_NAME="git-auto-switch"
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.${PROJECT_NAME}-backup/$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo " Git Auto Switch "
echo "========================================"
echo

read -rp "This will configure SSH & Git auto-switching. Continue? [y/N] " yn
[[ "$yn" != "y" ]] && exit 0

mkdir -p "$BACKUP_DIR"

# Load modules
source "$INSTALL_DIR/lib/cleanup.sh"
source "$INSTALL_DIR/lib/setup.sh"
source "$INSTALL_DIR/lib/ssh.sh"
source "$INSTALL_DIR/lib/git.sh"
source "$INSTALL_DIR/lib/remotes.sh"
source "$INSTALL_DIR/lib/hooks.sh"

backup_configs
clean_old_configs
setup_accounts
rewrite_all_remotes

echo
echo "✅ Installation complete"
echo "🛟 Backup saved at: $BACKUP_DIR"
echo "Restart your terminal to apply changes"