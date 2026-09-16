#!/usr/bin/env bash
#
# git-auto-switch launcher bootstrap
#
# The single implementation of OS detection, package-manager detection,
# dependency install flows, and the bootstrap banners shared by every entry
# point (F-CLEAN-002, F-DEAD-002, F-DEAD-004):
#
#   bin/git-auto-switch.js    (npm install -g)  → bash lib/bootstrap.sh --target …
#   git_auto_switch/cli.py    (pip install)     → bash lib/bootstrap.sh --target …
#   install-curl.sh           (curl installer)  → bash lib/bootstrap.sh --ensure
#
# The Node and Python launchers stay thin: they locate the bash CLI, hand it
# to this script, and this script guarantees the runtime dependencies before
# exec'ing it. install-curl.sh cannot source repo files before download, so it
# invokes the extracted copy of this script to ensure dependencies instead.
#
# Usage:
#   bootstrap.sh --target <git-auto-switch> [args...]   ensure deps, exec the CLI
#   bootstrap.sh --ensure                               ensure deps only, exit
#
# Environment:
#   AUTO_INSTALL=true        install missing dependencies without prompting
#   GAS_SOURCE_ONLY=true     source this file for its helpers (tests)
#
# Exit codes: 0 ready / 1 failed / 2 cancelled by the user at the plan prompt.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${BLUE}→${NC}"
WARN="${YELLOW}!${NC}"

AUTO_INSTALL="${AUTO_INSTALL:-false}"

# Runtime dependencies of the git-auto-switch CLI. bash is implied: this
# script cannot run without it (see bash_version_ok for the 3.2+ floor).
REQUIRED_DEPS=("git" "jq")

HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# ============================================================================
# Output helpers
# ============================================================================

print_header() {
  echo ""
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║            git-auto-switch                                 ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
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
    Darwin*) echo "macos" ;;
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
    *) echo "unknown" ;;
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
    debian) echo "apt" ;;
    redhat)
      if command -v dnf &> /dev/null; then
        echo "dnf"
      else
        echo "yum"
      fi
      ;;
    arch)   echo "pacman" ;;
    alpine) echo "apk" ;;
    *)      echo "none" ;;
  esac
}

get_os_display_name() {
  local os="$1"
  case "$os" in
    macos)  echo "macOS" ;;
    debian) echo "Debian/Ubuntu" ;;
    redhat) echo "RHEL/CentOS/Fedora" ;;
    arch)   echo "Arch Linux" ;;
    alpine) echo "Alpine Linux" ;;
    linux)  echo "Linux" ;;
    *)      echo "$os" ;;
  esac
}

# ============================================================================
# Dependency checking
# ============================================================================

check_command() {
  command -v "$1" &> /dev/null
}

get_version() {
  local cmd="$1"
  case "$cmd" in
    git)
      git --version 2>/dev/null | awk '{print $3}' || echo "unknown"
      ;;
    jq)
      jq --version 2>/dev/null | sed 's/jq-//' || echo "unknown"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# This script runs in bash, so the runtime check is the version floor.
bash_version_ok() {
  [[ "${BASH_VERSINFO[0]:-0}" -ge 3 ]]
}

get_missing_deps() {
  local missing=()
  local dep
  for dep in "${REQUIRED_DEPS[@]}"; do
    if ! check_command "$dep"; then
      missing+=("$dep")
    fi
  done
  # bash 3.2 (the project floor) treats "${arr[*]}" on an empty array as an
  # unbound variable under set -u — keep the :- default so the all-present
  # fast path stays clean.
  echo "${missing[*]:-}"
}

print_system_status() {
  print_section "System Status"

  local os
  os=$(detect_os)
  local pkg_manager
  pkg_manager=$(detect_package_manager "$os")

  echo -e "  ${BOLD}Operating System:${NC} $(get_os_display_name "$os")"
  echo -e "  ${BOLD}Package Manager:${NC}  $pkg_manager"
  echo ""

  echo -e "  ${BOLD}Required Dependencies:${NC}"
  echo ""

  # Bash (the bootstrap is already running under it — only the floor can fail)
  local bash_version="${BASH_VERSINFO[0]:-?}.${BASH_VERSINFO[1]:-?}"
  if bash_version_ok; then
    echo -e "    ${CHECK} bash     ${DIM}v$bash_version (required: 3.2+)${NC}"
  else
    echo -e "    ${CROSS} bash     ${DIM}v$bash_version (required: 3.2+)${NC}"
  fi

  # Git
  if check_command git; then
    echo -e "    ${CHECK} git      ${DIM}v$(get_version git) (required: 2.13+)${NC}"
  else
    echo -e "    ${CROSS} git      ${DIM}not installed (required: 2.13+)${NC}"
  fi

  # jq
  if check_command jq; then
    echo -e "    ${CHECK} jq       ${DIM}v$(get_version jq)${NC}"
  else
    echo -e "    ${CROSS} jq       ${DIM}not installed${NC}"
  fi

  echo ""
}

# ============================================================================
# Dependency installation
# ============================================================================

# Install Homebrew on macOS via download -> verify -> exec. The installer is
# saved to a temp file first and executed as a file argument to bash, so no
# network stream is ever piped into a shell (F-SEC-001).
install_homebrew() {
  print_step "Installing Homebrew..."
  print_info "Prefer the official instructions at https://brew.sh"
  local tmp_file
  tmp_file=$(mktemp)
  if ! curl -fsSL "$HOMEBREW_INSTALL_URL" -o "$tmp_file"; then
    print_error "Failed to download the Homebrew installer"
    rm -f "$tmp_file"
    return 1
  fi
  if [[ ! -s "$tmp_file" ]]; then
    print_error "Downloaded Homebrew installer is empty; refusing to run it"
    rm -f "$tmp_file"
    return 1
  fi
  if ! /bin/bash "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi
  rm -f "$tmp_file"

  # Add to PATH for the rest of this session
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  return 0
}

# Install a single package through the detected package manager.
install_package() {
  local pkg_manager="$1"
  local package="$2"
  print_step "Installing $package..."

  local rc=0
  case "$pkg_manager" in
    brew)   brew install "$package" || rc=$? ;;
    apt)
      sudo apt-get update -qq || rc=$?
      if [[ $rc -eq 0 ]]; then
        sudo apt-get install -y -qq "$package" || rc=$?
      fi
      ;;
    dnf)    sudo dnf install -y -q "$package" || rc=$? ;;
    yum)    sudo yum install -y -q "$package" || rc=$? ;;
    pacman) sudo pacman -S --noconfirm --quiet "$package" || rc=$? ;;
    apk)    sudo apk add --quiet "$package" || rc=$? ;;
    *)
      print_error "Unsupported package manager: $pkg_manager"
      return 1
      ;;
  esac

  if [[ $rc -ne 0 ]]; then
    print_error "Failed to install $package"
    return 1
  fi
  print_success "Installed $package"
  return 0
}

# Install the missing deps through the detected package manager. Returns
# 0 on success, 1 on failure (including a declined Homebrew offer).
install_dependencies() {
  local os="$1"
  local pkg_manager="$2"
  shift 2
  local deps=("$@")
  local dep

  # Contractually non-empty (ensure_dependencies only calls us with missing
  # deps), but guard anyway: empty "${arr[@]}" is an unbound error on bash 3.2.
  if [[ ${#deps[@]} -eq 0 ]]; then
    return 0
  fi

  print_section "Installing Dependencies"

  # Handle macOS without Homebrew
  if [[ "$os" == "macos" && "$pkg_manager" == "none" ]]; then
    print_warn "Homebrew not found"
    echo ""
    local response=""
    if [[ "$AUTO_INSTALL" == "true" ]]; then
      response="y"
    elif ! read -rp "  Install Homebrew? [Y/n] " response; then
      response="n"  # stdin closed (non-interactive): decline rather than install
    fi
    if [[ "$response" =~ ^[Nn] ]]; then
      print_error "Cannot install dependencies without Homebrew"
      echo ""
      echo "    Please install manually (see https://brew.sh):"
      echo "      /bin/bash -c \"\$(curl -fsSL $HOMEBREW_INSTALL_URL)\""
      for dep in "${deps[@]}"; do
        echo "      brew install $dep"
      done
      return 1
    fi
    if ! install_homebrew; then
      return 1
    fi
    pkg_manager="brew"
  fi

  if [[ "$pkg_manager" == "none" ]]; then
    print_error "No supported package manager found"
    echo ""
    echo "    Please install the following manually:"
    for dep in "${deps[@]}"; do
      echo "      - $dep"
    done
    return 1
  fi

  local installed=()
  for dep in "${deps[@]}"; do
    if install_package "$pkg_manager" "$dep"; then
      installed+=("$dep")
    else
      echo ""
      print_error "Failed to install all dependencies"
      return 1
    fi
  done

  echo ""
  print_success "All dependencies installed: ${installed[*]}"
  return 0
}

# ============================================================================
# Post-install summary
# ============================================================================

print_success_summary() {
  print_section "Ready to Use"

  echo -e "  ${CHECK} All dependencies satisfied"
  echo ""
  echo -e "  ${BOLD}Quick start:${NC}"
  echo ""
  echo "    gas init          # First-time setup"
  echo "    gas add           # Add a new GitHub account"
  echo "    gas --help        # Show all commands"
  echo ""
}

# ============================================================================
# Orchestration
# ============================================================================

# Ensure every runtime dependency is present; install what's missing.
# $1: context — "launcher" (default, prints the quick-start summary after a
#     successful install) or "installer" (neutral success line for
#     install-curl.sh, which prints its own summary later).
# Returns 0 ready, 1 failed, 2 cancelled by the user.
ensure_dependencies() {
  local context="${1:-launcher}"
  local missing
  missing="$(get_missing_deps)"

  if [[ -z "$missing" ]] && bash_version_ok; then
    if [[ "$context" == "installer" ]]; then
      print_success "All dependencies satisfied"
    fi
    return 0
  fi

  local deps=()
  if [[ -n "$missing" ]]; then
    read -ra deps <<< "$missing"
  fi

  local os pkg_manager
  os=$(detect_os)
  pkg_manager=$(detect_package_manager "$os")

  print_header
  print_system_status

  print_section "Installation Plan"

  echo -e "  ${BOLD}Actions to perform:${NC}"
  echo ""
  if ! bash_version_ok; then
    # bash itself is below the floor: nothing here can install it reliably.
    echo -e "    ${ARROW} Install bash 3.2+ using $pkg_manager"
  fi
  local dep
  if [[ ${#deps[@]} -gt 0 ]]; then
    for dep in "${deps[@]}"; do
      echo -e "    ${ARROW} Install $dep using $pkg_manager"
    done
  fi
  echo ""

  local response=""
  if [[ "$AUTO_INSTALL" == "true" ]]; then
    response="y"
  elif ! read -rp "  Proceed with installation? [Y/n] " response; then
    response="n"  # stdin closed (non-interactive): cancel rather than install
  fi
  if [[ "$response" =~ ^[Nn] ]]; then
    echo ""
    print_warn "Installation cancelled"
    return 2
  fi

  if ! bash_version_ok; then
    print_error "bash 3.2+ is required — please upgrade bash and retry"
    return 1
  fi

  if ! install_dependencies "$os" "$pkg_manager" "${deps[@]}"; then
    return 1
  fi

  # Verify installation
  local still_missing
  still_missing="$(get_missing_deps)"
  if [[ -n "$still_missing" ]]; then
    echo ""
    print_error "Dependencies still missing: $still_missing"
    return 1
  fi

  if [[ "$context" == "launcher" ]]; then
    print_success_summary
  else
    print_success "All dependencies satisfied"
  fi
  return 0
}

# ============================================================================
# Main
# ============================================================================

main() {
  case "${1:-}" in
    --ensure)
      shift
      ensure_dependencies installer || exit $?
      exit 0
      ;;
    --target)
      shift
      local target="${1:-}"
      if [[ -z "$target" ]]; then
        print_error "--target needs the path to the git-auto-switch script"
        exit 1
      fi
      shift
      if [[ ! -f "$target" ]]; then
        print_error "git-auto-switch script not found: $target"
        exit 1
      fi
      local rc=0
      ensure_dependencies launcher || rc=$?
      case "$rc" in
        0) exec bash "$target" "$@" ;;
        2) exit 0 ;;  # cancelled: clean exit, the CLI does not run
        *) exit "$rc" ;;
      esac
      ;;
    --help|-h)
      echo "Usage: bootstrap.sh --target <git-auto-switch> [args...]"
      echo "       bootstrap.sh --ensure"
      echo ""
      echo "Ensures git-auto-switch runtime dependencies (git, jq), offering to"
      echo "install missing ones via the detected package manager."
      exit 0
      ;;
    *)
      print_error "Unknown argument: ${1:-} (try --help)"
      exit 1
      ;;
  esac
}

# GAS_SOURCE_ONLY=true lets tests source this file for its helpers without
# running main.
if [[ "${GAS_SOURCE_ONLY:-false}" != "true" ]]; then
  main "$@"
fi
