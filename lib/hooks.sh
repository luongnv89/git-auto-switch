install_commit_guard() {
  local i="$1"
  mkdir -p ~/.git-hooks

  cat > ~/.git-hooks/pre-commit <<EOF
#!/usr/bin/env bash
EXPECTED="${GIT_EMAILS[$i]}"
CURRENT=\$(git config user.email)

if [[ "\$CURRENT" != "\$EXPECTED" ]]; then
  echo "❌ Wrong Git email"
  echo "Expected: \$EXPECTED"
  echo "Current:  \$CURRENT"
  exit 1
fi
EOF

  chmod +x ~/.git-hooks/pre-commit
}