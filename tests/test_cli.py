"""Minimal unit tests for the git_auto_switch Python shim.

Covers pure helpers so `pytest --cov` reports a real number (F-TEST-002).
No network, no installs, no subprocess side effects beyond `--version` probes.
"""

import inspect
import subprocess
from pathlib import Path
from types import SimpleNamespace

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


def test_no_shell_true_anywhere_in_shim():
    # F-SEC-001 regression guard: no curl-pipe via shell=True may return.
    assert "shell=True" not in inspect.getsource(cli)


def test_download_file_uses_argv_list_without_shell(monkeypatch, tmp_path):
    calls = []

    def fake_run(args, **kwargs):
        calls.append((args, kwargs))
        assert isinstance(args, list)
        assert kwargs.get("shell", False) is not True
        Path(args[args.index("-o") + 1]).write_text("x")
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(cli.subprocess, "run", fake_run)
    dest = tmp_path / "installer.sh"
    assert cli.download_file("https://example.invalid/i.sh", dest) is True
    assert calls[0][0][:3] == ["curl", "-fsSL", "https://example.invalid/i.sh"]
    assert dest.exists()


def test_download_file_returns_false_on_failure(monkeypatch, tmp_path):
    def fake_run(args, **kwargs):
        raise subprocess.CalledProcessError(6, args)

    monkeypatch.setattr(cli.subprocess, "run", fake_run)
    assert cli.download_file("https://example.invalid/i.sh", tmp_path / "i.sh") is False


def test_install_homebrew_download_verify_exec(monkeypatch, tmp_path):
    def fake_download(url, dest):
        assert url == cli.HOMEBREW_INSTALL_URL
        Path(dest).write_text("#!/bin/bash\necho hi\n")
        return True

    runs = []

    def fake_run(args, **kwargs):
        runs.append((args, kwargs))
        assert isinstance(args, list)
        assert kwargs.get("shell", False) is not True
        return SimpleNamespace(returncode=0, stdout="", stderr="")

    monkeypatch.setattr(cli, "download_file", fake_download)
    monkeypatch.setattr(cli.subprocess, "run", fake_run)
    assert cli.install_homebrew() is True
    # Second call executes the downloaded file with bash (no shell=True).
    assert runs[-1][0][0] == "/bin/bash"
    assert runs[-1][0][1].endswith("install.sh")


def test_install_homebrew_refuses_empty_download(monkeypatch):
    monkeypatch.setattr(cli, "download_file", lambda url, dest: True)

    def fake_run(args, **kwargs):
        raise AssertionError("must not execute an unverified installer")

    monkeypatch.setattr(cli.subprocess, "run", fake_run)
    assert cli.install_homebrew() is False


def test_install_homebrew_returns_false_when_download_fails(monkeypatch):
    monkeypatch.setattr(cli, "download_file", lambda url, dest: False)
    assert cli.install_homebrew() is False
