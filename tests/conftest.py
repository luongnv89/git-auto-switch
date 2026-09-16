"""Pytest bootstrap: keep ``import git_auto_switch`` working under every
invocation. ``python -m pytest`` already puts the repo root on ``sys.path``;
a bare ``pytest`` run does not, so the root is inserted here.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
