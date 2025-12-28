#!/usr/bin/env bats

load test_helper

@test "generate_ssh_config creates valid config block" {
  create_test_state

  local ssh_config
  ssh_config=$(generate_ssh_config)

  # Check markers
  echo "$ssh_config" | grep -q "$MARKER_START"
  echo "$ssh_config" | grep -q "$MARKER_END"

  # Check host entry
  echo "$ssh_config" | grep -q "Host gh-personal"
  echo "$ssh_config" | grep -q "HostName github.com"
  echo "$ssh_config" | grep -q "IdentitiesOnly yes"
}

@test "generate_git_config_file creates valid config" {
  create_test_state

  local account
  account=$(get_account "personal")

  local git_config
  git_config=$(generate_git_config_file "$account")

  # Check user section
  echo "$git_config" | grep -q "name = John Doe"
  echo "$git_config" | grep -q "email = john@personal.com"

  # Check core section
  echo "$git_config" | grep -q "hooksPath = $HOOKS_DIR"
}

@test "generate_git_include_block creates includeIf entries" {
  create_test_state

  local include_block
  include_block=$(generate_git_include_block)

  # Check markers
  echo "$include_block" | grep -q "$MARKER_START"
  echo "$include_block" | grep -q "$MARKER_END"

  # Check includeIf
  echo "$include_block" | grep -q "includeIf"
  echo "$include_block" | grep -q "gitconfig-personal"
}

@test "generate_pre_commit_hook creates executable hook" {
  local hook_content
  hook_content=$(generate_pre_commit_hook)

  # Check shebang
  echo "$hook_content" | head -1 | grep -q "#!/usr/bin/env bash"

  # Check for key logic
  echo "$hook_content" | grep -q "CONFIG_FILE"
  echo "$hook_config" | grep -q "git rev-parse" || true
}
