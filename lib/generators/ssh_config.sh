#!/usr/bin/env bash
# Generate SSH config blocks

# Generate SSH config entry for a single account
generate_ssh_config_entry() {
  local account_json="$1"

  local ssh_alias ssh_key_path
  ssh_alias=$(echo "$account_json" | jq -r '.ssh_alias')
  ssh_key_path=$(echo "$account_json" | jq -r '.ssh_key_path')

  cat <<EOF
Host $ssh_alias
  HostName github.com
  User git
  IdentityFile $ssh_key_path
  IdentitiesOnly yes

EOF
}

# Generate complete SSH config block for all accounts
generate_ssh_config() {
  require_jq

  echo "$MARKER_START"
  echo "# Managed by git-auto-switch - DO NOT EDIT"
  echo

  local account_count
  account_count=$(get_account_count)

  for ((i=0; i<account_count; i++)); do
    local account
    account=$(get_account_by_index "$i")
    generate_ssh_config_entry "$account"
  done

  echo "$MARKER_END"
}
