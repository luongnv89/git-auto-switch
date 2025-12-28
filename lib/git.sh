write_git_config() {
  local i="$1"
  local cfg="$HOME/.gitconfig-${NAMES[$i]}"

  cat > "$cfg" <<EOF
# Multi GitHub Account
[user]
  name = ${GIT_NAMES[$i]}
  email = ${GIT_EMAILS[$i]}

[core]
  sshCommand = ssh -i ${KEYS[$i]}
  hooksPath = ~/.git-hooks
EOF

  git config --global "includeIf.gitdir:${WORKSPACES[$i]}/.path" "$cfg"
}

set_default_identity() {
  echo
  echo "Select DEFAULT account:"
  select def in "${NAMES[@]}"; do
    for i in "${!NAMES[@]}"; do
      if [[ "${NAMES[$i]}" == "$def" ]]; then
        git config --global user.name "${GIT_NAMES[$i]}"
        git config --global user.email "${GIT_EMAILS[$i]}"
        return
      fi
    done
  done
}