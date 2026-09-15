#!/usr/bin/env bash
# Common utilities

# Canonicalize a path: expand a leading ~ to $HOME and strip trailing slashes.
# This is the single canonicalizer every workspace/path comparison routes
# through (state lookup, apply/audit/validate, gas current). The generated
# pre-commit hook cannot call it, so it embeds a jq mirror — keep the two in
# sync (see lib/generators/hooks.sh).
expand_path() {
  local path="$1"
  path="${path/#\~/$HOME}"
  # Drop trailing slashes so "~/ws" and "~/ws/" compare equal; keep "/" itself.
  while [[ "$path" == */ && "$path" != "/" ]]; do
    path="${path%/}"
  done
  echo "$path"
}

# Validate email format (basic check)
validate_email() {
  local email="$1"
  [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

# Validate SSH alias (alphanumeric, dash, underscore)
validate_ssh_alias() {
  local alias="$1"
  [[ "$alias" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]
}

# Validate account name/label (alphanumeric, dash, underscore)
validate_account_name() {
  local name="$1"
  [[ "$name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]
}

# Check if directory exists
validate_directory() {
  local dir="$1"
  local expanded
  expanded=$(expand_path "$dir")
  [[ -d "$expanded" ]]
}

# Check if jq is available
require_jq() {
  if ! command -v jq &>/dev/null; then
    die "jq is required but not installed. Install with: brew install jq (macOS) or apt install jq (Linux)"
  fi
}

# Generate a safe ID from label
generate_id() {
  local label="$1"
  echo "$label" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-'
}

# Check if path is inside another path
is_path_inside() {
  local child="$1"
  local parent="$2"
  local child_expanded parent_expanded
  child_expanded=$(expand_path "$child")
  parent_expanded=$(expand_path "$parent")

  # Ensure trailing slash for proper prefix matching
  [[ "${child_expanded}/" == "${parent_expanded}/"* ]]
}

# Create backup with timestamp
create_backup() {
  local source="$1"
  local backup_name="$2"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_path="$BACKUP_DIR/$timestamp"

  mkdir -p "$backup_path"

  if [[ -f "$source" ]]; then
    cp "$source" "$backup_path/$backup_name"
    log_info "Backed up $source to $backup_path/$backup_name"
  fi
}
