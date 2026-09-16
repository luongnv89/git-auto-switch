#!/usr/bin/env bash
#
# git-auto-switch installer
#
# Preferred install order (package managers first):
#   pip install git-auto-switch      # PyPI
#   npm install -g git-auto-switch   # npm
# Use this curl installer only when no package manager fits. When you do,
# prefer download-then-run over piping so you can inspect and verify first:
#   curl -fsSL https://raw.githubusercontent.com/luongnv89/git-auto-switch/main/install-curl.sh -o install-curl.sh
#   bash install-curl.sh [--checksum <sha256>]
# Piping (curl ... | bash) still works but skips pre-run inspection.
#
# Checksum verification: the release tarball is verified via SHA256 before
# anything is extracted or executed. Precedence:
#   1. --checksum <sha256> / GAS_CHECKSUM env var (explicit pin, recommended)
#   2. "<tarball-url>.sha256" sidecar (or GAS_CHECKSUM_URL override)
#   3. No checksum found: warn and continue (main-branch snapshots publish
#      no sidecar). On mismatch the download is deleted and install aborts.
#
# Dependency bootstrap: runtime deps (git, jq) are ensured by the extracted
# tree's lib/bootstrap.sh — the single implementation shared with the npm and
# pip launchers (F-CLEAN-002). This script keeps only the installer-tool
# preflight (curl, tar) that must pass before anything can be downloaded.
#
# Options (via environment variables):
#   INSTALL_DIR    - Installation directory (default: ~/.local/bin)
#   DATA_DIR       - Data directory (default: ~/.local/share/git-auto-switch)
#   VERSION        - Specific version to install (default: latest)
#   AUTO_INSTALL   - Auto-install dependencies without prompting (default: false;
#                    forced when stdin is not a TTY, e.g. curl | bash)
#   GAS_CHECKSUM   - Expected SHA256 of the release tarball (default: empty)
#   GAS_CHECKSUM_URL - Override URL of the .sha256 sidecar file (default: empty)
#   GAS_DOWNLOAD_URL - Override tarball URL (test hook; default: empty)
#
# Flags: uninstall | --checksum <sha256> | --help
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${BLUE}→${NC}"
WARN="${YELLOW}!${NC}"

# Configuration
REPO="luongnv89/git-auto-switch"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/git-auto-switch}"
VERSION="${VERSION:-latest}"
AUTO_INSTALL="${AUTO_INSTALL:-false}"
GAS_CHECKSUM="${GAS_CHECKSUM:-}"
GAS_CHECKSUM_URL="${GAS_CHECKSUM_URL:-}"
GAS_DOWNLOAD_URL="${GAS_DOWNLOAD_URL:-}"

# Directory the release tarball extracted to (set by download_and_extract)
EXTRACTED_DIR=""
# Download scratch dir — global so the EXIT trap can still see it after
# main() returns (a function-local would be unbound under `set -u` there).
TMP_DIR=""

# ============================================================================
# Output helpers
# ============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║            git-auto-switch installer                       ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

print_step() {
    echo -e "  ${ARROW} $1"
}

print_success() {
    echo -e "  ${CHECK} $1"
}

print_error() {
    echo -e "  ${CROSS} $1" >&2
}

print_warn() {
    echo -e "  ${WARN} $1"
}

print_info() {
    echo -e "  ${DIM}$1${NC}"
}

# ============================================================================
# Installer preflight — tools needed before the repo exists locally
# ============================================================================
#
# These are the installer's own requirements: they fetch and extract the
# release tarball. The app's runtime dependencies (git, jq) are a different
# set and are ensured post-extraction by lib/bootstrap.sh — the single
# implementation of OS detection, package-manager detection, and dependency
# install flows shared with the npm and pip launchers (F-CLEAN-002).

preflight_installer_tools() {
    local missing=()
    local tool
    for tool in curl tar; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "The installer requires: ${missing[*]}"
        echo ""
        echo "    Please install them with your system package manager, then retry."
        exit 1
    fi
}

# Ensure runtime deps via the downloaded tree's shared bootstrap. Runs as a
# subprocess so the launchers and this installer execute the same code.
ensure_runtime_deps() {
    local src_dir="$1"
    local bootstrap="$src_dir/lib/bootstrap.sh"

    print_section "Checking Dependencies"

    if [[ ! -f "$bootstrap" ]]; then
        # Version skew guard: a pinned older tarball predates the shared
        # bootstrap — warn rather than silently skip the check.
        print_warn "Dependency bootstrap not found in the downloaded package"
        print_info "Ensure git and jq are installed before running gas"
        return 0
    fi

    # A piped install (curl | bash) has no stdin to prompt on — proceed
    # without asking, matching this script's previous empty-answer behavior.
    local auto_install="$AUTO_INSTALL"
    if [[ ! -t 0 ]]; then
        auto_install="true"
    fi

    local rc=0
    AUTO_INSTALL="$auto_install" bash "$bootstrap" --ensure || rc=$?
    case "$rc" in
        0) return 0 ;;
        2) exit 0 ;;  # user cancelled the dependency install
        *) exit 1 ;;
    esac
}

# ============================================================================
# Download verification (F-SEC-001)
# ============================================================================

sha256_of_file() {
    local file="$1"
    if command -v sha256sum &> /dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &> /dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        print_error "No SHA256 tool found (need sha256sum or shasum)"
        return 1
    fi
}

verify_sha256() {
    local file="$1"
    local expected="$2"
    local actual
    actual=$(sha256_of_file "$file") || return 1
    # Tolerate "<hash>  <filename>" sidecar format; compare case-insensitively.
    local expected_hash
    expected_hash=$(echo "$expected" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
    actual=$(echo "$actual" | tr '[:upper:]' '[:lower:]')
    if [[ -n "$expected_hash" && "$actual" == "$expected_hash" ]]; then
        print_success "Checksum verified (SHA256)"
        return 0
    fi
    print_error "Checksum mismatch for $file"
    print_error "  expected: $expected_hash"
    print_error "  actual:   $actual"
    return 1
}

fetch_expected_checksum() {
    local base_url="$1"
    local checksum_url="${GAS_CHECKSUM_URL:-$base_url.sha256}"
    curl -fsSL "$checksum_url" 2>/dev/null | awk '{print $1}'
}

download_and_verify() {
    local url="$1"
    local dest="$2"
    print_step "Downloading $url"
    if ! curl -fsSL "$url" -o "$dest"; then
        print_error "Failed to download $url"
        return 1
    fi
    local expected=""
    if [[ -n "$GAS_CHECKSUM" ]]; then
        expected="$GAS_CHECKSUM"
    else
        expected=$(fetch_expected_checksum "$url" 2>/dev/null || true)
    fi
    if [[ -z "$expected" ]]; then
        print_warn "No checksum available for $url"
        print_info "Pin it with: GAS_CHECKSUM=<sha256> bash $0  (or --checksum <sha256>)"
        return 0
    fi
    if ! verify_sha256 "$dest" "$expected"; then
        print_error "Refusing to use $dest (checksum mismatch)"
        rm -f "$dest"
        return 1
    fi
    return 0
}

# ============================================================================
# git-auto-switch installation
# ============================================================================

get_latest_version() {
    local latest
    # Parsed without jq: jq is an app dependency ensured later, while this
    # runs before the download — falling back to "main" on a missing jq would
    # silently change which version gets installed.
    latest=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)

    if [[ -z "$latest" ]]; then
        echo "main"
    else
        echo "$latest"
    fi
}

# Download, checksum-verify, and extract the release into $tmp_dir; sets
# EXTRACTED_DIR to the extracted repo root.
download_and_extract() {
    local version="$1"
    local tmp_dir="$2"

    print_section "Installing git-auto-switch"

    # Determine download URL (GAS_DOWNLOAD_URL overrides for tests)
    local download_url
    if [[ -n "$GAS_DOWNLOAD_URL" ]]; then
        download_url="$GAS_DOWNLOAD_URL"
    elif [[ "$version" == "main" || "$version" == "latest" ]]; then
        download_url="https://github.com/$REPO/archive/refs/heads/main.tar.gz"
    else
        download_url="https://github.com/$REPO/archive/refs/tags/$version.tar.gz"
    fi

    print_step "Downloading version: $version"
    print_info "$download_url"

    # Download to a file and verify before extracting: never pipe a
    # network stream into tar, and refuse to run on checksum mismatch.
    local tarball="$tmp_dir/gas.tar.gz"
    if ! download_and_verify "$download_url" "$tarball"; then
        print_error "Aborting installation (download/verification failed)"
        exit 1
    fi

    print_step "Extracting..."
    if ! tar -xzf "$tarball" -C "$tmp_dir"; then
        print_error "Failed to extract git-auto-switch"
        exit 1
    fi

    # Find extracted directory
    EXTRACTED_DIR=$(find "$tmp_dir" -maxdepth 1 -type d -name "git-auto-switch*" | head -1)

    if [[ -z "$EXTRACTED_DIR" ]]; then
        print_error "Failed to find extracted directory"
        exit 1
    fi
}

# Copy the extracted tree into place and create the command symlinks.
install_files() {
    local src_dir="$1"

    # Create directories
    print_step "Creating directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"

    # Copy files
    print_step "Installing files to $DATA_DIR"
    rm -rf "$DATA_DIR"
    cp -r "$src_dir" "$DATA_DIR"

    # Make scripts executable
    chmod +x "$DATA_DIR/git-auto-switch"
    find "$DATA_DIR/lib" -name "*.sh" -exec chmod +x {} \;

    # Create symlinks
    print_step "Creating symlinks in $INSTALL_DIR"
    ln -sf "$DATA_DIR/git-auto-switch" "$INSTALL_DIR/git-auto-switch"
    ln -sf "$DATA_DIR/git-auto-switch" "$INSTALL_DIR/gas"

    print_success "Installation complete"
}

# ============================================================================
# Post-installation
# ============================================================================

check_path_and_suggest() {
    local path_ok=true
    local shell_config=""

    # Detect shell config file
    case "${SHELL:-/bin/bash}" in
        */zsh)  shell_config="$HOME/.zshrc" ;;
        */bash)
            if [[ -f "$HOME/.bash_profile" ]]; then
                shell_config="$HOME/.bash_profile"
            else
                shell_config="$HOME/.bashrc"
            fi
            ;;
        *)      shell_config="$HOME/.profile" ;;
    esac

    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        path_ok=false
    fi

    echo "$path_ok|$shell_config"
}

print_final_summary() {
    local version="$1"

    print_section "Installation Summary"

    echo -e "  ${BOLD}What was installed:${NC}"
    echo ""

    # Main app
    echo -e "    ${CHECK} git-auto-switch v$version"
    echo -e "       ${DIM}Location: $DATA_DIR${NC}"
    echo -e "       ${DIM}Commands: $INSTALL_DIR/git-auto-switch${NC}"
    echo -e "       ${DIM}          $INSTALL_DIR/gas${NC}"
    echo ""

    # Check PATH
    local path_info
    path_info=$(check_path_and_suggest)
    local path_ok="${path_info%%|*}"
    local shell_config="${path_info##*|}"

    if [[ "$path_ok" == "false" ]]; then
        echo -e "  ${BOLD}${YELLOW}Action Required:${NC}"
        echo ""
        echo -e "    Add $INSTALL_DIR to your PATH:"
        echo ""
        echo -e "    ${DIM}# Add this line to $shell_config${NC}"
        echo -e "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo -e "    ${DIM}Then reload your shell:${NC}"
        echo -e "    source $shell_config"
        echo ""
    fi

    print_section "Getting Started"

    echo -e "  ${BOLD}Quick start:${NC}"
    echo ""
    if [[ "$path_ok" == "true" ]]; then
        echo "    gas init          # First-time setup"
    else
        echo "    $INSTALL_DIR/gas init    # First-time setup"
    fi
    echo ""

    echo -e "  ${BOLD}Common commands:${NC}"
    echo ""
    echo "    gas add           # Add a new GitHub account"
    echo "    gas list          # List configured accounts"
    echo "    gas current       # Show active account for current directory"
    echo "    gas audit --fix   # Fix identity issues in repositories"
    echo ""

    echo -e "  ${BOLD}Get help:${NC}"
    echo ""
    echo "    gas --help                              # Show all commands"
    echo "    https://github.com/$REPO    # Documentation"
    echo ""
}

# ============================================================================
# Uninstall
# ============================================================================

uninstall() {
    print_header
    print_section "Uninstalling git-auto-switch"

    if [[ -L "$INSTALL_DIR/git-auto-switch" ]]; then
        print_step "Removing $INSTALL_DIR/git-auto-switch"
        rm -f "$INSTALL_DIR/git-auto-switch"
        print_success "Removed symlink"
    fi

    if [[ -L "$INSTALL_DIR/gas" ]]; then
        print_step "Removing $INSTALL_DIR/gas"
        rm -f "$INSTALL_DIR/gas"
        print_success "Removed symlink"
    fi

    if [[ -d "$DATA_DIR" ]]; then
        print_step "Removing $DATA_DIR"
        rm -rf "$DATA_DIR"
        print_success "Removed data directory"
    fi

    print_section "Uninstall Complete"

    echo -e "  ${CHECK} git-auto-switch has been removed"
    echo ""
    echo -e "  ${DIM}Note: Your configuration at ~/.git-auto-switch was preserved.${NC}"
    echo -e "  ${DIM}      Remove it manually if no longer needed:${NC}"
    echo -e "  ${DIM}      rm -rf ~/.git-auto-switch${NC}"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    # Handle flags: uninstall | --checksum <sha256> | --help
    while [[ $# -gt 0 ]]; do
        case "$1" in
            uninstall)
                print_header
                uninstall
                exit 0
                ;;
            --checksum)
                if [[ $# -lt 2 ]]; then
                    print_error "--checksum needs a SHA256 value"
                    exit 1
                fi
                GAS_CHECKSUM="$2"
                shift 2
                ;;
            --help|-h)
                print_header
                echo "  Usage: bash install-curl.sh [uninstall] [--checksum <sha256>]"
                echo ""
                echo "  Prefer a package manager first: pip install git-auto-switch,"
                echo "  npm install -g git-auto-switch."
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1 (try --help)"
                exit 1
                ;;
        esac
    done

    print_header

    # Phase 1: Installer preflight — curl and tar fetch/extract the release;
    # the app's own deps come later from the shared bootstrap.
    preflight_installer_tools

    # Phase 2: Determine version
    local install_version="$VERSION"
    if [[ "$install_version" == "latest" ]]; then
        print_step "Checking for latest version..."
        install_version=$(get_latest_version)
    fi

    # Phase 3: Download, checksum-verify, and extract the release
    TMP_DIR=$(mktemp -d)
    trap '[[ -n "${TMP_DIR:-}" ]] && rm -rf "$TMP_DIR"' EXIT
    download_and_extract "$install_version" "$TMP_DIR"

    # Phase 4: Ensure runtime dependencies (git, jq) via the extracted
    # tree's shared bootstrap — the same code the npm/pip launchers run.
    ensure_runtime_deps "$EXTRACTED_DIR"

    # Phase 5: Install files and create symlinks
    install_files "$EXTRACTED_DIR"

    # Phase 6: Show summary
    # Get actual version from installed script
    local actual_version
    actual_version=$("$INSTALL_DIR/git-auto-switch" version 2>/dev/null | awk '{print $NF}' || echo "$install_version")

    print_final_summary "$actual_version"
}

# GAS_SOURCE_ONLY=true lets tests source this file for its helpers
# without running the installer (curl | bash still runs main normally).
if [[ "${GAS_SOURCE_ONLY:-false}" != "true" ]]; then
    main "$@"
fi
