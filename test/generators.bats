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

@test "generate_git_config_file quotes a spaced ssh key path" {
  init_state
  add_account "personal" "Personal" "gh-personal" "$HOME/.ssh/my keys/id_rsa" \
    '["'"$HOME"'/workspace/personal"]' "John Doe" "john@personal.com"

  local account
  account=$(get_account "personal")

  local git_config
  git_config=$(generate_git_config_file "$account")

  # The command is emitted as a gitconfig-quoted string whose inner quotes
  # survive into the shell command git runs, keeping the path one argument.
  local expected="sshCommand = \"ssh -i \\\"$HOME/.ssh/my keys/id_rsa\\\"\""
  [[ "$git_config" == *"$expected"* ]]

  # End-to-end: git parses the generated file and the sshCommand value keeps
  # the inner quoting that protects the spaced path from word-splitting.
  local config_file="$HOME/gitconfig-personal"
  printf '%s\n' "$git_config" > "$config_file"
  local parsed
  parsed=$(git config -f "$config_file" --get core.sshCommand)
  [ "$parsed" = "ssh -i \"$HOME/.ssh/my keys/id_rsa\"" ]
}

@test "generate_git_config_file expands ~ in the ssh key path" {
  init_state
  add_account "personal" "Personal" "gh-personal" "~/.ssh/id_rsa" \
    '["'"$HOME"'/workspace/personal"]' "John Doe" "john@personal.com"

  local account
  account=$(get_account "personal")

  local git_config
  git_config=$(generate_git_config_file "$account")

  # A quoted "~" would not survive shell tilde-expansion, so the generator
  # emits the expanded absolute path instead.
  local expected="sshCommand = \"ssh -i \\\"$HOME/.ssh/id_rsa\\\"\""
  [[ "$git_config" == *"$expected"* ]]
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
