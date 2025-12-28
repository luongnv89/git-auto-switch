#!/usr/bin/env bash
#
# Legacy installer - redirects to new CLI
#
# This script is kept for backward compatibility.
# Please use 'git-auto-switch' or 'gas' commands instead.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================"
echo "  git-auto-switch"
echo "========================================"
echo
echo "NOTE: install.sh is deprecated."
echo "Please use the new CLI commands instead:"
echo
echo "  ./git-auto-switch init    # First-time setup"
echo "  ./git-auto-switch add     # Add account"
echo "  ./git-auto-switch list    # List accounts"
echo "  ./git-auto-switch apply   # Apply configuration"
echo
echo "Redirecting to 'git-auto-switch init'..."
echo

exec "$SCRIPT_DIR/git-auto-switch" init
