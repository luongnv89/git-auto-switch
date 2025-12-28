#!/usr/bin/env bash
# Generate Git config files

# Generate .gitconfig-{id} content for account
generate_git_config_file() {
  local account_json="$1"

  local id git_name git_email ssh_key_path
  id=$(echo "$account_json" | jq -r '.id')
  git_name=$(echo "$account_json" | jq -r '.git_name')
  git_email=$(echo "$account_json" | jq -r '.git_email')
  ssh_key_path=$(echo "$account_json" | jq -r '.ssh_key_path')

  cat <<EOF
# Git config for account: $id
# Managed by git-auto-switch

[user]
  name = $git_name
  email = $git_email

[core]
  sshCommand = ssh -i $ssh_key_path
  hooksPath = $HOOKS_DIR
EOF
}

# Generate includeIf block for ~/.gitconfig
generate_git_include_block() {
  require_jq

  local output=""
  output+="$MARKER_START"$'\n'

  local account_count
  account_count=$(get_account_count)

  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")

    local id workspace
    id=$(echo "$account" | jq -r '.id')
    workspace=$(echo "$account" | jq -r '.workspace')

    # Expand ~ for gitdir matching
    local expanded_workspace
    expanded_workspace=$(expand_path "$workspace")

    output+="[includeIf \"gitdir:${expanded_workspace}/\"]"$'\n'
    output+="  path = ~/.gitconfig-${id}"$'\n'
  done

  output+="$MARKER_END"$'\n'

  echo "$output"
}
