#!/usr/bin/env bash
# Core constants for git-auto-switch

# Version
readonly GAS_VERSION="0.1.0"

# Paths
readonly CONFIG_DIR="$HOME/.git-auto-switch"
readonly CONFIG_FILE="$CONFIG_DIR/config.json"
readonly BACKUP_DIR="$CONFIG_DIR/backup"
readonly HOOKS_DIR="$HOME/.git-hooks"

# Markers for managed config sections
readonly MARKER_START="# === GIT-AUTO-SWITCH MANAGED START ==="
readonly MARKER_END="# === GIT-AUTO-SWITCH MANAGED END ==="

# SSH config path
readonly SSH_CONFIG="$HOME/.ssh/config"

# Git config path
readonly GIT_CONFIG="$HOME/.gitconfig"
