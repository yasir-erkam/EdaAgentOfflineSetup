"""Run the bundled MCP without depending on a system Python or PATH."""
import json
import os
import runpy
from pathlib import Path

root = Path(__file__).resolve().parent
settings = json.loads((root / "installation.json").read_text(encoding="utf-8"))
os.environ["EDA_AGENT_BACKEND"] = settings["backend"]
os.environ["EDA_AGENT_WORKSPACE"] = str(root / "workspace")
# Upstream's health/relaunch/install-scripts helpers otherwise use USERPROFILE
# even when the workspace and script project were installed elsewhere.
from eda_agent import cli

cli.get_default_scripts_dest = lambda: root / "scripts"
runpy.run_module("eda_agent", run_name="__main__")
