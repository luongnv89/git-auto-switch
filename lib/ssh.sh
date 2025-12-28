ensure_ssh_key() {
  local key="$1"
  local label="$2"

  if [[ ! -f "$key" ]]; then
    echo "🔐 Generating SSH key for $label"
    mkdir -p "$(dirname "$key")"
    ssh-keygen -t ed25519 -f "$key" -C "$label" -N ""
    echo
    echo "👉 Add this public key to GitHub:"
    cat "${key}.pub"
    echo
  fi
}

write_ssh_config() {
  mkdir -p ~/.ssh
  touch ~/.ssh/config

  if ! grep -q "GIT-START" ~/.ssh/config; then
    cat >> ~/.ssh/config <<EOF

# === GIT-AUTO-SWITCH START ===
# Managed by git-auto-switch
EOF
  fi

  for i in "${!NAMES[@]}"; do
    grep -q "Host ${ALIASES[$i]}" ~/.ssh/config && continue

    cat >> ~/.ssh/config <<EOF
Host ${ALIASES[$i]}
  HostName github.com
  User git
  IdentityFile ${KEYS[$i]}
  IdentitiesOnly yes

EOF
  done

  sed -i '' '/# === GIT-AUTO-SWITCH START ===/a\
# === GIT-AUTO-SWITCH END ===
' ~/.ssh/config 2>/dev/null || true
}