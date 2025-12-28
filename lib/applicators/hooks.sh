#!/usr/bin/env bash
# Apply Git hooks

# Install pre-commit hook globally
apply_pre_commit_hook() {
  # Create hooks directory
  mkdir -p "$HOOKS_DIR"

  # Generate and write hook
  local hook_content
  hook_content=$(generate_pre_commit_hook)

  local hook_path="$HOOKS_DIR/pre-commit"

  # Backup existing hook if present
  if [[ -f "$hook_path" ]]; then
    create_backup "$hook_path" "pre-commit"
  fi

  echo "$hook_content" > "$hook_path"
  chmod +x "$hook_path"

  log_success "Installed pre-commit hook: $hook_path"
}

# Configure git to use global hooks directory
configure_global_hooks() {
  git config --global core.hooksPath "$HOOKS_DIR"
  log_info "Configured global hooks path: $HOOKS_DIR"
}

# Validate hook installation
validate_hook() {
  local errors=0

  # Check hook file exists
  if [[ ! -f "$HOOKS_DIR/pre-commit" ]]; then
    log_error "Pre-commit hook not found: $HOOKS_DIR/pre-commit"
    ((errors++))
  fi

  # Check hook is executable
  if [[ ! -x "$HOOKS_DIR/pre-commit" ]]; then
    log_error "Pre-commit hook is not executable"
    ((errors++))
  fi

  # Check global hooks path is configured
  local hooks_path
  hooks_path=$(git config --global core.hooksPath 2>/dev/null || echo "")
  if [[ "$hooks_path" != "$HOOKS_DIR" ]]; then
    log_error "Global hooks path not configured correctly"
    log_error "  Expected: $HOOKS_DIR"
    log_error "  Actual: $hooks_path"
    ((errors++))
  fi

  return $errors
}
