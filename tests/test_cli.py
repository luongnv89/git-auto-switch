"""Unit tests for the git_auto_switch thin Python launcher.

The launcher delegates all dependency bootstrap work to lib/bootstrap.sh
(F-CLEAN-002), so these tests cover path resolution, delegation argv, exit
codes, and error paths. No network, no installs — subprocess.run is mocked.
"""

import inspect
import io
import sys
import tomllib
from pathlib import Path
from types import SimpleNamespace

import pytest

import git_auto_switch
from git_auto_switch import cli


def test_get_script_path_resolves_to_repo():
    path = cli.get_script_path()
    assert path is not None
    assert Path(path).exists()
    assert path.name == "git-auto-switch"


def test_get_bootstrap_path_resolves_next_to_script():
    script = cli.get_script_path()
    bootstrap = cli.get_bootstrap_path(script)
    assert bootstrap is not None
    assert bootstrap.exists()
    assert bootstrap.name == "bootstrap.sh"
    assert bootstrap.parent.name == "lib"


def test_get_bootstrap_path_missing_returns_none(tmp_path):
    assert cli.get_bootstrap_path(tmp_path / "git-auto-switch") is None


def test_print_colored_strips_ansi_when_not_tty(capsys):
    cli.print_colored(f"{cli.BOLD}hello{cli.NC}")
    out = capsys.readouterr().out
    assert "hello" in out
    assert "\033[" not in out


def test_print_script_not_found_shows_pip_hint(capsys):
    cli.print_script_not_found(Path("/x/git-auto-switch"))
    out = capsys.readouterr().out
    assert "not found" in out
    assert "pip install git-auto-switch" in out


def test_main_delegates_to_shared_bootstrap(monkeypatch):
    calls = []

    def fake_run(args, **kwargs):
        calls.append((args, kwargs))
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(cli.subprocess, "run", fake_run)
    monkeypatch.setattr(sys, "argv", ["gas", "list", "--json"])
    with pytest.raises(SystemExit) as exc:
        cli.main()
    assert exc.value.code == 0

    args = calls[0][0]
    script = cli.get_script_path()
    assert args[0] == "bash"
    assert args[1].endswith("lib/bootstrap.sh")
    assert args[2:4] == ["--target", str(script)]
    assert args[4:] == ["list", "--json"]
    assert calls[0][1].get("shell", False) is not True


def test_main_propagates_cli_exit_code(monkeypatch):
    monkeypatch.setattr(
        cli.subprocess,
        "run",
        lambda *a, **k: SimpleNamespace(returncode=7),
    )
    with pytest.raises(SystemExit) as exc:
        cli.main()
    assert exc.value.code == 7


def test_main_exits_when_script_missing(monkeypatch, capsys):
    monkeypatch.setattr(cli, "get_script_path", lambda: None)
    with pytest.raises(SystemExit) as exc:
        cli.main()
    assert exc.value.code == 1
    assert "not found" in capsys.readouterr().out


def test_main_exits_when_bootstrap_missing(monkeypatch, capsys):
    monkeypatch.setattr(cli, "get_bootstrap_path", lambda _p: None)
    with pytest.raises(SystemExit) as exc:
        cli.main()
    assert exc.value.code == 1
    assert "bootstrap.sh" in capsys.readouterr().out


def test_main_exits_with_hint_when_bash_missing(monkeypatch, capsys):
    def fake_run(*a, **k):
        raise FileNotFoundError("bash")

    monkeypatch.setattr(cli.subprocess, "run", fake_run)
    with pytest.raises(SystemExit) as exc:
        cli.main()
    assert exc.value.code == 1
    assert "bash not found" in capsys.readouterr().out


def test_main_exits_on_permission_error(monkeypatch, capsys):
    def fake_run(*a, **k):
        raise PermissionError("denied")

    monkeypatch.setattr(cli.subprocess, "run", fake_run)
    with pytest.raises(SystemExit) as exc:
        cli.main()
    assert exc.value.code == 1
    assert "Permission denied" in capsys.readouterr().out


def test_launcher_has_no_detection_or_install_logic():
    # F-CLEAN-002 convergence guard: the shim must not grow a second copy.
    src = inspect.getsource(cli)
    for banned in (
        "def detect_os",
        "def detect_package_manager",
        "def install_homebrew",
        "def install_package",
        "def check_dependencies",
    ):
        assert banned not in src


def test_no_shell_true_anywhere_in_shim():
    # F-SEC-001 regression guard: no curl-pipe via shell=True may return.
    assert "shell=True" not in inspect.getsource(cli)


# --- Survivors of the F-CLEAN-002 convergence: helpers the shim still owns ---


def test_print_colored_keeps_ansi_on_tty(monkeypatch):
    class TTY(io.StringIO):
        def isatty(self):
            return True

    tty = TTY()
    monkeypatch.setattr(sys, "stdout", tty)
    cli.print_colored(f"{cli.BOLD}hello{cli.NC}")
    assert "\033[" in tty.getvalue()


def test_get_script_path_prefers_packaged_script(monkeypatch):
    monkeypatch.setattr(
        Path, "exists", lambda self: str(self).endswith("scripts/git-auto-switch")
    )
    expected = Path(cli.__file__).parent / "scripts" / "git-auto-switch"
    assert cli.get_script_path() == expected


def test_get_script_path_returns_none_when_absent(monkeypatch):
    monkeypatch.setattr(Path, "exists", lambda self: False)
    assert cli.get_script_path() is None


def test_package_version_matches_pyproject():
    pyproject = Path(__file__).resolve().parent.parent / "pyproject.toml"
    version = tomllib.loads(pyproject.read_text())["project"]["version"]
    assert git_auto_switch.__version__ == version
