rewrite_all_remotes() {
  for i in "${!WORKSPACES[@]}"; do
    find "${WORKSPACES[$i]}" -name ".git" 2>/dev/null | while read -r g; do
      repo="$(dirname "$g")"
      cd "$repo" || continue

      url=$(git remote get-url origin 2>/dev/null || true)
      if [[ "$url" == git@github.com:* ]]; then
        new="${url/github.com/${ALIASES[$i]}}"
        git remote set-url origin "$new"
        echo "🔁 Rewrote remote in $repo"
      fi
    done
  done
}