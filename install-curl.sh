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
# Options (via environment variables):
#   INSTALL_DIR    - Installation directory (default: ~/.local/bin)
#   DATA_DIR       - Data directory (default: ~/.local/share/git-auto-switch)
#   VERSION        - Specific version to install (default: latest)
#   AUTO_INSTALL   - Auto-install dependencies without prompting (default: false)
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

# Track what we install
INSTALLED_DEPS=()

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
# System detection
# ============================================================================

detect_os() {
    case "$(uname -s)" in
        Darwin*)  echo "macos" ;;
        Linux*)
            if [[ -f /etc/debian_version ]]; then
                echo "debian"
            elif [[ -f /etc/redhat-release ]]; then
                echo "redhat"
            elif [[ -f /etc/arch-release ]]; then
                echo "arch"
            elif [[ -f /etc/alpine-release ]]; then
                echo "alpine"
            else
                echo "linux"
            fi
            ;;
        *)        echo "unknown" ;;
    esac
}

detect_package_manager() {
    local os="$1"
    case "$os" in
        macos)
            if command -v brew &> /dev/null; then
                echo "brew"
            else
                echo "none"
            fi
            ;;
        debian)  echo "apt" ;;
        redhat)
            if command -v dnf &> /dev/null; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        arch)    echo "pacman" ;;
        alpine)  echo "apk" ;;
        *)       echo "none" ;;
    esac
}

# ============================================================================
# Dependency checking
# ============================================================================

check_command() {
    local cmd="$1"
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

get_version() {
    local cmd="$1"
    case "$cmd" in
        bash)
            echo "${BASH_VERSION:-unknown}"
            ;;
        git)
            git --version 2>/dev/null | awk '{print $3}' || echo "unknown"
            ;;
        jq)
            jq --version 2>/dev/null | sed 's/jq-//' || echo "unknown"
            ;;
        curl)
            curl --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

print_system_status() {
    print_section "System Status"

    local os
    os=$(detect_os)
    local pkg_manager
    pkg_manager=$(detect_package_manager "$os")

    echo -e "  ${BOLD}Operating System:${NC} $os"
    echo -e "  ${BOLD}Package Manager:${NC}  $pkg_manager"
    echo ""

    echo -e "  ${BOLD}Required Dependencies:${NC}"
    echo ""

    # Check each dependency
    local all_ok=true

    # Bash (always present if we're running)
    local bash_version="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
    if [[ "${BASH_VERSINFO[0]}" -ge 3 ]]; then
        echo -e "    ${CHECK} bash     ${DIM}v$bash_version (required: 3.2+)${NC}"
    else
        echo -e "    ${CROSS} bash     ${DIM}v$bash_version (required: 3.2+)${NC}"
        all_ok=false
    fi

    # Git
    if check_command git; then
        local git_ver
        git_ver=$(get_version git)
        echo -e "    ${CHECK} git      ${DIM}v$git_ver (required: 2.13+)${NC}"
    else
        echo -e "    ${CROSS} git      ${DIM}not installed (required: 2.13+)${NC}"
        all_ok=false
    fi

    # jq
    if check_command jq; then
        local jq_ver
        jq_ver=$(get_version jq)
        echo -e "    ${CHECK} jq       ${DIM}v$jq_ver${NC}"
    else
        echo -e "    ${CROSS} jq       ${DIM}not installed${NC}"
        all_ok=false
    fi

    # curl
    if check_command curl; then
        local curl_ver
        curl_ver=$(get_version curl)
        echo -e "    ${CHECK} curl     ${DIM}v$curl_ver${NC}"
    else
        echo -e "    ${CROSS} curl     ${DIM}not installed${NC}"
        all_ok=false
    fi

    echo ""

    if $all_ok; then
        return 0
    else
        return 1
    fi
}

get_missing_deps() {
    local missing=()

    if ! check_command git; then
        missing+=("git")
    fi

    if ! check_command jq; then
        missing+=("jq")
    fi

    if ! check_command curl; then
        missing+=("curl")
    fi

    echo "${missing[*]}"
}

# ============================================================================
# Dependency installation
# ============================================================================

install_homebrew() {
    print_step "Installing Homebrew..."
    print_info "Prefer the official instructions at https://brew.sh"
    local tmp_file
    tmp_file=$(mktemp)
    # Download first, then execute the file: never pipe a network stream
    # straight into a shell (F-SEC-001).
    if ! curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" -o "$tmp_file"; then
        print_error "Failed to download the Homebrew installer"
        rm -f "$tmp_file"
        exit 1
    fi
    if [[ ! -s "$tmp_file" ]]; then
        print_error "Downloaded Homebrew installer is empty; refusing to run it"
        rm -f "$tmp_file"
        exit 1
    fi
    /bin/bash "$tmp_file"
    rm -f "$tmp_file"

    # Add to PATH for current session
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

install_deps_macos() {
    local deps=("$@")

    if ! check_command brew; then
        print_warn "Homebrew not found"
        echo ""
        read -rp "    Install Homebrew? [Y/n] " response
        if [[ "$response" =~ ^[Nn] ]]; then
            print_error "Cannot install dependencies without Homebrew"
            echo ""
            echo "    Please install manually (see https://brew.sh):"
            echo "      /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo "      brew install ${deps[*]}"
            exit 1
        fi
        install_homebrew
    fi

    for dep in "${deps[@]}"; do
        print_step "Installing $dep via Homebrew..."
        if brew install "$dep"; then
            print_success "Installed $dep"
            INSTALLED_DEPS+=("$dep")
        else
            print_error "Failed to install $dep"
            exit 1
        fi
    done
}

install_deps_apt() {
    local deps=("$@")

    print_step "Updating package lists..."
    sudo apt-get update -qq

    for dep in "${deps[@]}"; do
        print_step "Installing $dep via apt..."
        if sudo apt-get install -y -qq "$dep"; then
            print_success "Installed $dep"
            INSTALLED_DEPS+=("$dep")
        else
            print_error "Failed to install $dep"
            exit 1
        fi
    done
}

install_deps_dnf() {
    local deps=("$@")

    for dep in "${deps[@]}"; do
        print_step "Installing $dep via dnf..."
        if sudo dnf install -y -q "$dep"; then
            print_success "Installed $dep"
            INSTALLED_DEPS+=("$dep")
        else
            print_error "Failed to install $dep"
            exit 1
        fi
    done
}

install_deps_yum() {
    local deps=("$@")

    for dep in "${deps[@]}"; do
        print_step "Installing $dep via yum..."
        if sudo yum install -y -q "$dep"; then
            print_success "Installed $dep"
            INSTALLED_DEPS+=("$dep")
        else
            print_error "Failed to install $dep"
            exit 1
        fi
    done
}

install_deps_pacman() {
    local deps=("$@")

    for dep in "${deps[@]}"; do
        print_step "Installing $dep via pacman..."
        if sudo pacman -S --noconfirm --quiet "$dep"; then
            print_success "Installed $dep"
            INSTALLED_DEPS+=("$dep")
        else
            print_error "Failed to install $dep"
            exit 1
        fi
    done
}

install_deps_apk() {
    local deps=("$@")

    for dep in "${deps[@]}"; do
        print_step "Installing $dep via apk..."
        if sudo apk add --quiet "$dep"; then
            print_success "Installed $dep"
            INSTALLED_DEPS+=("$dep")
        else
            print_error "Failed to install $dep"
            exit 1
        fi
    done
}

install_dependencies() {
    local missing
    missing=$(get_missing_deps)

    if [[ -z "$missing" ]]; then
        return 0
    fi

    # Convert to array
    local deps
    read -ra deps <<< "$missing"

    local os
    os=$(detect_os)
    local pkg_manager
    pkg_manager=$(detect_package_manager "$os")

    print_section "Installation Plan"

    echo -e "  ${BOLD}Missing dependencies:${NC} ${deps[*]}"
    echo ""

    if [[ "$pkg_manager" == "none" ]]; then
        print_error "No supported package manager found"
        echo ""
        echo "    Please install the following manually:"
        for dep in "${deps[@]}"; do
            echo "      - $dep"
        done
        exit 1
    fi

    echo -e "  ${BOLD}Actions to perform:${NC}"
    for dep in "${deps[@]}"; do
        echo -e "    ${ARROW} Install $dep using $pkg_manager"
    done
    echo -e "    ${ARROW} Download git-auto-switch"
    echo -e "    ${ARROW} Install to $INSTALL_DIR"
    echo ""

    # Prompt for confirmation unless AUTO_INSTALL is true
    if [[ "$AUTO_INSTALL" != "true" ]]; then
        read -rp "  Proceed with installation? [Y/n] " response
        if [[ "$response" =~ ^[Nn] ]]; then
            echo ""
            print_warn "Installation cancelled"
            exit 0
        fi
    fi

    print_section "Installing Dependencies"

    case "$pkg_manager" in
        brew)   install_deps_macos "${deps[@]}" ;;
        apt)    install_deps_apt "${deps[@]}" ;;
        dnf)    install_deps_dnf "${deps[@]}" ;;
        yum)    install_deps_yum "${deps[@]}" ;;
        pacman) install_deps_pacman "${deps[@]}" ;;
        apk)    install_deps_apk "${deps[@]}" ;;
        *)
            print_error "Unsupported package manager: $pkg_manager"
            exit 1
            ;;
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
    latest=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | jq -r '.tag_name // empty')

    if [[ -z "$latest" ]]; then
        echo "main"
    else
        echo "$latest"
    fi
}

install_git_auto_switch() {
    local version="$1"
    local tmp_dir

    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    print_section "Installing git-auto-switch"

    # Determine download URL (GAS_DOWNLOAD_URL overrides for tests)
    local download_url
    if [[ -n "$GAS_DOWNLOAD_URL" ]]; then
        download_url="$GAS_DOWNLOAD_URL"
    elif [[ "$version" == "main" || "$version" == "latest" ]]; then
        download_url="https://github.com/$REPO/archive/refs/heads/main.tar.gz"
        version="main"
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
    local src_dir
    src_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "git-auto-switch*" | head -1)

    if [[ -z "$src_dir" ]]; then
        print_error "Failed to find extracted directory"
        exit 1
    fi

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

    # Dependencies
    if [[ ${#INSTALLED_DEPS[@]} -gt 0 ]]; then
        echo -e "    ${CHECK} Dependencies: ${INSTALLED_DEPS[*]}"
    fi

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

    # Phase 1: Check system status
    if ! print_system_status; then
        # Phase 2: Install missing dependencies
        install_dependencies

        # Verify dependencies are now available
        echo ""
        print_step "Verifying dependencies..."
        local still_missing
        still_missing=$(get_missing_deps)
        if [[ -n "$still_missing" ]]; then
            print_error "Dependencies still missing: $still_missing"
            exit 1
        fi
        print_success "All dependencies satisfied"
    else
        print_success "All dependencies satisfied"
    fi

    # Phase 3: Determine version
    local install_version="$VERSION"
    if [[ "$install_version" == "latest" ]]; then
        print_step "Checking for latest version..."
        install_version=$(get_latest_version)
    fi

    # Phase 4: Install git-auto-switch
    install_git_auto_switch "$install_version"

    # Phase 5: Show summary
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
