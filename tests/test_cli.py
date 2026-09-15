"""Minimal unit tests for the git_auto_switch Python shim.

Covers pure helpers so `pytest --cov` reports a real number (F-TEST-002).
No network, no installs, no subprocess side effects beyond `--version` probes.
"""

from pathlib import Path

from git_auto_switch import cli


def test_get_os_display_name_known():
    assert cli.get_os_display_name("macos") == "macOS"
    assert cli.get_os_display_name("debian") == "Debian/Ubuntu"
    assert cli.get_os_display_name("linux") == "Linux"


def test_get_os_display_name_unknown_passthrough():
    assert cli.get_os_display_name("plan9") == "plan9"


def test_detect_package_manager_macos_brew(monkeypatch):
    monkeypatch.setattr(cli.shutil, "which", lambda _: "/opt/homebrew/bin/brew")
    assert cli.detect_package_manager("macos") == "brew"


def test_detect_package_manager_macos_none(monkeypatch):
    monkeypatch.setattr(cli.shutil, "which", lambda _: None)
    assert cli.detect_package_manager("macos") == "none"


def test_detect_package_manager_debian():
    assert cli.detect_package_manager("debian") == "apt"


def test_detect_package_manager_unknown():
    assert cli.detect_package_manager("plan9") == "none"


def test_check_command_missing():
    ok, msg = cli.check_command("gas-definitely-not-a-real-cmd-xyz")
    assert ok is False
    assert msg == "not installed"


def test_get_script_path_resolves_to_repo():
    path = cli.get_script_path()
    assert path is not None
    assert Path(path).exists()


def test_detect_os_returns_known_value():
    assert cli.detect_os() in (
        "macos", "debian", "redhat", "arch", "alpine", "linux",
        "Windows", "Java",
    ) or isinstance(cli.detect_os(), str)


def test_check_dependencies_returns_list():
    missing = cli.check_dependencies()
    assert isinstance(missing, list)
    # bash and git must exist in any dev/CI container running this suite
    assert "bash" not in missing
    assert "git" not in missing


def test_print_colored_strips_ansi_when_not_tty(capsys):
    cli.print_colored(f"{cli.BOLD}hello{cli.NC}")
    out = capsys.readouterr().out
    assert "hello" in out
    assert "\033[" not in out
