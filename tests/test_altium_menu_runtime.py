"""Register real FastMCP tools in both modes; refuse saves before bridge access."""
import asyncio
import importlib.util
import os
from pathlib import Path
import shutil
from unittest.mock import patch
import uuid

root = Path(__file__).resolve().parents[1]
fixture = root / ".work" / ("menu-runtime-test-" + uuid.uuid4().hex)
fixture.mkdir(parents=True)
os.environ["EDA_AGENT_WORKSPACE"] = str(fixture / "workspace")
os.environ["EDA_AGENT_POINTER_FILE"] = str(fixture / "pointer.txt")
os.environ["EDA_AGENT_NO_DASHBOARD"] = "1"
os.environ["EDA_AGENT_BACKEND"] = "altium"
spec = importlib.util.spec_from_file_location("menu_runtime", root / "payload/altium/altium_menu.py")
menu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(menu)


async def check():
    from mcp.server.fastmcp import FastMCP
    from eda_agent import tools
    menu.install_tool_guard(tools)
    for mode in ("minimal", "full"):
        server = FastMCP("guarded-menu-test")
        tools.register_backend(server, "altium", mode)
        advertised = {t.name for t in await server.list_tools()}
        assert {"tool_catalog", "tool_invoke"} <= advertised
        # No command should ever reach a bridge, even when testing guard failure.
        with patch("eda_agent.tools.application.get_bridge", side_effect=AssertionError("Bridge must not be touched")):
            reply = await server.call_tool("tool_invoke", {"name": "app_save_all", "arguments": {}})
            assert "UNREVIEWED_TARGET_SCOPE" in str(reply), reply
            reply = await server.call_tool("tool_invoke", {"name": "get_board_info", "arguments": {}})
            assert "UNREVIEWED_TARGET_SCOPE" in str(reply), reply
            if mode == "full":
                reply = await server.call_tool("app_save_all", {})
                assert "UNREVIEWED_TARGET_SCOPE" in str(reply), reply
        print(f"PASS: real FastMCP {mode} registration, nested dispatch and save refusal; no bridge calls")


try:
    asyncio.run(check())
finally:
    if fixture.resolve().parent != (root / ".work").resolve():
        raise RuntimeError("Refusing cleanup outside test root")
    shutil.rmtree(fixture)
