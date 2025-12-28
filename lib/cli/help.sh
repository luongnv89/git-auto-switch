#!/usr/bin/env bash
# Help and version display

show_version() {
  echo "git-auto-switch version $GAS_VERSION"
}

show_help() {
  cat <<EOF
git-auto-switch - Manage multiple GitHub accounts with automatic identity switching

USAGE:
  git-auto-switch <command> [options]
  gas <command> [options]

COMMANDS:
  init        Initialize configuration (first-time setup)
  add         Add a new account
  remove [id] Remove an account (interactive if no ID provided)
  list        List all configured accounts
  apply       Apply configuration to system (SSH, Git, hooks)
  validate    Validate configuration and check for issues
  audit       Audit repositories for identity mismatches
  help        Show this help message
  version     Show version information

EXAMPLES:
  # First-time setup
  git-auto-switch init

  # Add a new account
  git-auto-switch add

  # Remove an account
  git-auto-switch remove personal

  # List all accounts
  git-auto-switch list

  # Apply configuration after changes
  git-auto-switch apply

  # Check for issues
  git-auto-switch validate

  # Audit repositories
  git-auto-switch audit

CONFIG FILE:
  $CONFIG_FILE

DOCUMENTATION:
  https://github.com/luongnv89/git-auto-switch

EOF
}
