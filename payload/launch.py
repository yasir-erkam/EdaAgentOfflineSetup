"""Run the bundled MCP without depending on a system Python or PATH."""
import json
import os
import runpy
import sys
from pathlib import Path

for stream in (sys.stdout, sys.stderr):
    if stream is not None and hasattr(stream, "reconfigure"):
        # MCP is UTF-8; upstream CLI messages must also survive Turkish paths
        # when the parent PowerShell process redirects output using cp1252.
        stream.reconfigure(encoding="utf-8", errors="backslashreplace")

root = Path(__file__).resolve().parent
settings = json.loads((root / "installation.json").read_text(encoding="utf-8"))
os.environ["EDA_AGENT_BACKEND"] = settings["backend"]
os.environ["EDA_AGENT_WORKSPACE"] = str(root / "workspace")
# Discover schemas on demand instead of sending every EDA tool to the model.
# Set before importing eda_agent: its tool registry is built at import time.
os.environ.setdefault("EDA_AGENT_TOOLSET", "minimal")
if settings["backend"] == "kicad":
    # Upstream initializes an Altium pointer even on KiCad. Keep it private so
    # starting KiCad never redirects a running Altium session.
    os.environ["EDA_AGENT_POINTER_FILE"] = str(root / "workspace" / "unused-altium-pointer.txt")
    os.environ.setdefault("EDA_AGENT_NO_DASHBOARD", "1")
# Upstream's health/relaunch/install-scripts helpers otherwise use USERPROFILE
# even when the workspace and script project were installed elsewhere.
from eda_agent import cli

cli.get_default_scripts_dest = lambda: root / "scripts"
if settings["backend"] == "altium":
    # Embedded Python's _pth does not add the launcher's directory automatically.
    sys.path.insert(0, str(root))
    from altium_menu import configure_pointer_encoding
    from eda_agent import config as agent_config
    configure_pointer_encoding(agent_config, root / "workspace")
if settings["backend"] == "altium" and (root / "workspace" / "eda-menu-enabled").is_file():
    from altium_menu import install_bridge_guard, install_tool_guard
    from eda_agent.bridge.altium_bridge import AltiumBridge
    from eda_agent import tools
    install_bridge_guard(AltiumBridge)
    install_tool_guard(tools, root / "workspace")
    os.environ["EDA_AGENT_UI_AUTOMATION"] = "0"
    os.environ["EDA_AGENT_NO_DASHBOARD"] = "1"
runpy.run_module("eda_agent", run_name="__main__")
