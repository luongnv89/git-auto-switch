#!/usr/bin/env python3
"""Setup script for git-auto-switch that bundles bash scripts."""

import shutil
from pathlib import Path
from setuptools import setup
from setuptools.command.build_py import build_py


class BuildPyCommand(build_py):
    """Custom build command that copies bash scripts into the package."""

    def run(self):
        # Run the standard build
        super().run()

        # Source and destination paths
        src_dir = Path(__file__).parent
        dest_dir = Path(self.build_lib) / "git_auto_switch" / "scripts"

        # Create destination directory
        dest_dir.mkdir(parents=True, exist_ok=True)

        # Copy main script
        shutil.copy2(src_dir / "git-auto-switch", dest_dir / "git-auto-switch")

        # Copy lib directory
        src_lib = src_dir / "lib"
        dest_lib = dest_dir / "lib"
        if dest_lib.exists():
            shutil.rmtree(dest_lib)
        shutil.copytree(src_lib, dest_lib)

        # Make scripts executable
        for script in dest_dir.rglob("*.sh"):
            script.chmod(0o755)
        (dest_dir / "git-auto-switch").chmod(0o755)


setup(cmdclass={"build_py": BuildPyCommand})
