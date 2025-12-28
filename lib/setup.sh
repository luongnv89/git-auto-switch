declare -a NAMES ALIASES KEYS WORKSPACES GIT_NAMES GIT_EMAILS
ACCOUNT_COUNT=0

setup_accounts() {
  read -rp "How many GitHub accounts? " ACCOUNT_COUNT

  for ((i=0; i<ACCOUNT_COUNT; i++)); do
    echo
    echo "---- Account $((i+1)) ----"

    read -rp "Label (e.g. personal, work): " "NAMES[$i]"
    read -rp "SSH alias (e.g. gh-${NAMES[$i]}): " "ALIASES[$i]"
    read -rp "SSH key path (will auto-generate if missing): " "KEYS[$i]"
    read -rp "Workspace folder (e.g. ~/workspace/${NAMES[$i]}/): " "WORKSPACES[$i]"
    read -rp "Git user.name: " "GIT_NAMES[$i]"
    read -rp "Git user.email: " "GIT_EMAILS[$i]"

    ensure_ssh_key "${KEYS[$i]}" "${NAMES[$i]}"
    write_ssh_config
    write_git_config "$i"
    install_commit_guard "$i"
  done

  set_default_identity
}
