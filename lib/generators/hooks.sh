#!/usr/bin/env bash
# Generate pre-commit hook

# Generate pre-commit hook that validates email based on workspace
generate_pre_commit_hook() {
  cat <<'HOOK'
#!/usr/bin/env bash
# Pre-commit hook for git-auto-switch
# Validates that the configured Git email matches the expected email for this workspace

set -euo pipefail

CONFIG_FILE="$HOME/.git-auto-switch/config.json"

# Skip if config doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# Check if jq is available
if ! command -v jq &>/dev/null; then
  echo "WARNING: jq not found, skipping git-auto-switch email validation" >&2
  exit 0
fi

# Get current repository path
repo_path=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -z "$repo_path" ]]; then
  exit 0
fi

# Find matching account by workspace
expected_email=$(jq -r --arg repo "$repo_path" '
  .accounts[] |
  select(.workspaces[] as $ws | ($repo + "/") | startswith(($ws | gsub("~"; env.HOME)) + "/")) |
  .git_email
' "$CONFIG_FILE" | head -n1)

# If no matching workspace, allow commit (not managed)
if [[ -z "$expected_email" ]]; then
  exit 0
fi

# Get configured email for this repo
configured_email=$(git config user.email 2>/dev/null || echo "")

if [[ "$configured_email" != "$expected_email" ]]; then
  echo "========================================"
  echo " Git identity mismatch detected!"
  echo "========================================"
  echo
  echo "Repository: $repo_path"
  echo "Expected email: $expected_email"
  echo "Current email:  $configured_email"
  echo
  echo "To fix, run:"
  echo "  git config user.email \"$expected_email\""
  echo
  echo "Or apply the correct configuration:"
  echo "  git-auto-switch apply"
  echo
  exit 1
fi

exit 0
HOOK
}
