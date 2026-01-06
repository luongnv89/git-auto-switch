#!/usr/bin/env python3
"""Entry point for git-auto-switch CLI."""

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

# ANSI colors
GREEN = "\033[0;32m"
RED = "\033[0;31m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"  # No Color

CHECK = f"{GREEN}✓{NC}"
CROSS = f"{RED}✗{NC}"
ARROW = f"{BLUE}→{NC}"
WARN = f"{YELLOW}!{NC}"


def print_colored(msg: str) -> None:
    """Print with ANSI color support."""
    if sys.stdout.isatty():
        print(msg)
    else:
        import re
        clean = re.sub(r'\033\[[0-9;]*m', '', msg)
        print(clean)


def get_script_path() -> Path:
    """Get the path to the git-auto-switch bash script."""
    package_dir = Path(__file__).parent
    script_path = package_dir / "scripts" / "git-auto-switch"

    if script_path.exists():
        return script_path

    source_dir = package_dir.parent
    script_path = source_dir / "git-auto-switch"

    if script_path.exists():
        return script_path

    return None


def check_command(cmd: str) -> tuple:
    """Check if a command exists and get its version."""
    path = shutil.which(cmd)
    if not path:
        return False, "not installed"

    try:
        if cmd == "git":
            result = subprocess.run([cmd, "--version"], capture_output=True, text=True)
            version = result.stdout.strip().replace("git version ", "")
        elif cmd == "jq":
            result = subprocess.run([cmd, "--version"], capture_output=True, text=True)
            version = result.stdout.strip().replace("jq-", "")
        elif cmd == "bash":
            result = subprocess.run([cmd, "--version"], capture_output=True, text=True)
            first_line = result.stdout.split("\n")[0]
            version = first_line.split()[3].split("(")[0] if "version" in first_line else "unknown"
        else:
            version = "installed"
        return True, version
    except Exception:
        return True, "unknown"


def detect_os() -> str:
    """Detect operating system."""
    system = platform.system()
    if system == "Darwin":
        return "macos"
    elif system == "Linux":
        if Path("/etc/debian_version").exists():
            return "debian"
        elif Path("/etc/redhat-release").exists():
            return "redhat"
        elif Path("/etc/arch-release").exists():
            return "arch"
        elif Path("/etc/alpine-release").exists():
            return "alpine"
        return "linux"
    return system


def detect_package_manager(os_name: str) -> str:
    """Detect available package manager."""
    if os_name == "macos":
        if shutil.which("brew"):
            return "brew"
        return "none"
    elif os_name == "debian":
        return "apt"
    elif os_name == "redhat":
        if shutil.which("dnf"):
            return "dnf"
        return "yum"
    elif os_name == "arch":
        return "pacman"
    elif os_name == "alpine":
        return "apk"
    return "none"


def get_os_display_name(os_name: str) -> str:
    """Get display name for OS."""
    names = {
        "macos": "macOS",
        "debian": "Debian/Ubuntu",
        "redhat": "RHEL/CentOS/Fedora",
        "arch": "Arch Linux",
        "alpine": "Alpine Linux",
        "linux": "Linux",
    }
    return names.get(os_name, os_name)


def install_homebrew() -> bool:
    """Install Homebrew on macOS."""
    print_colored(f"  {ARROW} Installing Homebrew...")
    try:
        subprocess.run(
            ["/bin/bash", "-c", "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"],
            shell=True,
            check=True
        )
        # Add to PATH for current session
        brew_paths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for brew_path in brew_paths:
            if Path(brew_path).exists():
                result = subprocess.run([brew_path, "shellenv"], capture_output=True, text=True)
                if result.returncode == 0:
                    os.environ["PATH"] = f"{Path(brew_path).parent}:{os.environ.get('PATH', '')}"
                break
        print_colored(f"  {CHECK} Homebrew installed")
        return True
    except Exception as e:
        print_colored(f"  {CROSS} Failed to install Homebrew: {e}")
        return False


def install_package(pkg_manager: str, package: str) -> bool:
    """Install a package using the system package manager."""
    print_colored(f"  {ARROW} Installing {package}...")

    try:
        if pkg_manager == "brew":
            subprocess.run(["brew", "install", package], check=True)
        elif pkg_manager == "apt":
            subprocess.run(["sudo", "apt-get", "update", "-qq"], check=True)
            subprocess.run(["sudo", "apt-get", "install", "-y", "-qq", package], check=True)
        elif pkg_manager == "dnf":
            subprocess.run(["sudo", "dnf", "install", "-y", "-q", package], check=True)
        elif pkg_manager == "yum":
            subprocess.run(["sudo", "yum", "install", "-y", "-q", package], check=True)
        elif pkg_manager == "pacman":
            subprocess.run(["sudo", "pacman", "-S", "--noconfirm", "--quiet", package], check=True)
        elif pkg_manager == "apk":
            subprocess.run(["sudo", "apk", "add", "--quiet", package], check=True)
        else:
            return False

        print_colored(f"  {CHECK} Installed {package}")
        return True
    except subprocess.CalledProcessError as e:
        print_colored(f"  {CROSS} Failed to install {package}: {e}")
        return False
    except FileNotFoundError:
        print_colored(f"  {CROSS} Package manager '{pkg_manager}' not found")
        return False


def check_dependencies() -> list:
    """Check all required dependencies and return missing ones."""
    missing = []
    deps = ["bash", "git", "jq"]

    for dep in deps:
        installed, _ = check_command(dep)
        if not installed:
            missing.append(dep)

    return missing


def print_header() -> None:
    """Print header banner."""
    print_colored("")
    print_colored(f"{BOLD}╔════════════════════════════════════════════════════════════╗{NC}")
    print_colored(f"{BOLD}║            git-auto-switch                                 ║{NC}")
    print_colored(f"{BOLD}╚════════════════════════════════════════════════════════════╝{NC}")


def print_section(title: str) -> None:
    """Print section header."""
    print_colored("")
    print_colored(f"{BOLD}{BLUE}━━━ {title} ━━━{NC}")
    print_colored("")


def print_system_status(os_name: str, pkg_manager: str) -> list:
    """Print system status and return missing deps."""
    print_section("System Status")

    print_colored(f"  {BOLD}Operating System:{NC} {get_os_display_name(os_name)}")
    print_colored(f"  {BOLD}Package Manager:{NC}  {pkg_manager}")
    print_colored("")
    print_colored(f"  {BOLD}Required Dependencies:{NC}")
    print_colored("")

    missing = []

    # Check bash
    installed, version = check_command("bash")
    if installed:
        print_colored(f"    {CHECK} bash     {DIM}v{version} (required: 3.2+){NC}")
    else:
        print_colored(f"    {CROSS} bash     {DIM}not installed (required: 3.2+){NC}")
        missing.append("bash")

    # Check git
    installed, version = check_command("git")
    if installed:
        print_colored(f"    {CHECK} git      {DIM}v{version} (required: 2.13+){NC}")
    else:
        print_colored(f"    {CROSS} git      {DIM}not installed (required: 2.13+){NC}")
        missing.append("git")

    # Check jq
    installed, version = check_command("jq")
    if installed:
        print_colored(f"    {CHECK} jq       {DIM}v{version}{NC}")
    else:
        print_colored(f"    {CROSS} jq       {DIM}not installed{NC}")
        missing.append("jq")

    print_colored("")

    return missing


def install_dependencies(missing: list, os_name: str, pkg_manager: str) -> bool:
    """Install missing dependencies."""
    print_section("Installing Dependencies")

    # Handle macOS without Homebrew
    if os_name == "macos" and pkg_manager == "none":
        print_colored(f"  {WARN} Homebrew not found")
        print_colored("")
        response = input("  Install Homebrew? [Y/n] ").strip().lower()
        if response in ["n", "no"]:
            print_colored("")
            print_colored(f"  {CROSS} Cannot install dependencies without Homebrew")
            print_colored("")
            print_colored("  Please install manually:")
            print_colored('    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')
            for dep in missing:
                print_colored(f"    brew install {dep}")
            return False

        if not install_homebrew():
            return False
        pkg_manager = "brew"

    if pkg_manager == "none":
        print_colored(f"  {CROSS} No supported package manager found")
        print_colored("")
        print_colored("  Please install the following manually:")
        for dep in missing:
            print_colored(f"    - {dep}")
        return False

    # Install each missing dependency
    installed_deps = []
    for dep in missing:
        if install_package(pkg_manager, dep):
            installed_deps.append(dep)
        else:
            print_colored("")
            print_colored(f"  {CROSS} Failed to install all dependencies")
            return False

    print_colored("")
    print_colored(f"  {CHECK} All dependencies installed: {', '.join(installed_deps)}")
    return True


def print_success_summary() -> None:
    """Print success message after dependencies are installed."""
    print_section("Ready to Use")

    print_colored(f"  {CHECK} All dependencies satisfied")
    print_colored("")
    print_colored(f"  {BOLD}Quick start:{NC}")
    print_colored("")
    print_colored("    gas init          # First-time setup")
    print_colored("    gas add           # Add a new GitHub account")
    print_colored("    gas --help        # Show all commands")
    print_colored("")


def print_script_not_found() -> None:
    """Print error when script is not found."""
    print_colored("")
    print_colored(f"{BOLD}{RED}━━━ Installation Error ━━━{NC}")
    print_colored("")
    print_colored(f"  {CROSS} git-auto-switch script not found")
    print_colored("")
    print_colored("  The package may not be installed correctly.")
    print_colored("  Try reinstalling:")
    print_colored("")
    print_colored("    pip uninstall git-auto-switch")
    print_colored("    pip install git-auto-switch")
    print_colored("")


def main() -> None:
    """Run the git-auto-switch bash script."""
    # Find the script
    script_path = get_script_path()

    if script_path is None:
        print_script_not_found()
        sys.exit(1)

    # Check dependencies
    missing = check_dependencies()

    if missing:
        print_header()

        os_name = detect_os()
        pkg_manager = detect_package_manager(os_name)

        # Show current status
        print_system_status(os_name, pkg_manager)

        # Show installation plan
        print_section("Installation Plan")
        print_colored(f"  {BOLD}Actions to perform:{NC}")
        print_colored("")
        for dep in missing:
            print_colored(f"    {ARROW} Install {dep} using {pkg_manager}")
        print_colored("")

        # Ask for confirmation
        response = input("  Proceed with installation? [Y/n] ").strip().lower()
        if response in ["n", "no"]:
            print_colored("")
            print_colored(f"  {WARN} Installation cancelled")
            print_colored("")
            sys.exit(0)

        # Install dependencies
        if not install_dependencies(missing, os_name, pkg_manager):
            sys.exit(1)

        # Verify installation
        still_missing = check_dependencies()
        if still_missing:
            print_colored("")
            print_colored(f"  {CROSS} Dependencies still missing: {', '.join(still_missing)}")
            sys.exit(1)

        print_success_summary()

    # Run the bash script
    try:
        result = subprocess.run(
            [str(script_path)] + sys.argv[1:],
            stdin=sys.stdin,
            stdout=sys.stdout,
            stderr=sys.stderr,
        )
        sys.exit(result.returncode)
    except FileNotFoundError:
        print_colored(f"  {CROSS} Failed to execute bash script")
        print_colored("      Make sure bash is installed and in your PATH")
        sys.exit(1)
    except PermissionError:
        print_colored(f"  {CROSS} Permission denied executing script")
        print_colored(f"      Try: chmod +x {script_path}")
        sys.exit(1)


if __name__ == "__main__":
    main()
