#!/usr/bin/env python3
"""Entry point for git-auto-switch CLI.

Thin wrapper: all OS detection, package-manager detection, dependency
install flows, and banners live in ``lib/bootstrap.sh`` — the single
implementation shared with the npm launcher and install-curl.sh
(F-CLEAN-002). This module only locates the bash CLI and delegates.
"""

import re
import subprocess
import sys
from pathlib import Path

# ANSI colors (only what the launcher-local error paths need)
RED = "\033[0;31m"
BOLD = "\033[1m"
NC = "\033[0m"  # No Color

CROSS = f"{RED}✗{NC}"


def print_colored(msg: str) -> None:
    """Print with ANSI color support."""
    if sys.stdout.isatty():
        print(msg)
    else:
        clean = re.sub(r"\033\[[0-9;]*m", "", msg)
        print(clean)


def get_script_path() -> Path | None:
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


def get_bootstrap_path(script_path: Path) -> Path | None:
    """Get the shared dependency bootstrap next to the bash CLI."""
    bootstrap_path = script_path.parent / "lib" / "bootstrap.sh"
    return bootstrap_path if bootstrap_path.exists() else None


def print_script_not_found(expected: Path) -> None:
    """Print error when package files are missing."""
    print_colored("")
    print_colored(f"{BOLD}{RED}━━━ Installation Error ━━━{NC}")
    print_colored("")
    print_colored(f"  {CROSS} git-auto-switch files not found")
    print_colored(f"     Expected at: {expected}")
    print_colored("")
    print_colored("  The package may not be installed correctly.")
    print_colored("  Try reinstalling:")
    print_colored("")
    print_colored("    pip uninstall git-auto-switch")
    print_colored("    pip install git-auto-switch")
    print_colored("")


def main() -> None:
    """Delegate to the shared bootstrap, which ensures dependencies and execs the CLI."""
    script_path = get_script_path()
    if script_path is None:
        print_script_not_found(Path(__file__).parent / "scripts" / "git-auto-switch")
        sys.exit(1)

    bootstrap_path = get_bootstrap_path(script_path)
    if bootstrap_path is None:
        print_script_not_found(script_path.parent / "lib" / "bootstrap.sh")
        sys.exit(1)

    # The bootstrap ensures dependencies (installing them with the user's
    # consent when missing), then execs the real CLI with our arguments.
    try:
        result = subprocess.run(
            ["bash", str(bootstrap_path), "--target", str(script_path), *sys.argv[1:]],
            check=False,
        )
        sys.exit(result.returncode)
    except FileNotFoundError:
        print_colored("")
        print_colored(f"  {CROSS} bash not found")
        print_colored("      git-auto-switch requires bash 3.2+ — install it with")
        print_colored("      your system package manager, then retry.")
        print_colored("")
        sys.exit(1)
    except PermissionError:
        print_colored(f"  {CROSS} Permission denied executing script")
        print_colored(f"      Try: chmod +x {bootstrap_path}")
        sys.exit(1)


if __name__ == "__main__":
    main()
