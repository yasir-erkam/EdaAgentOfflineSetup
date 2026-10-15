"""Read-only MCP handshake and catalog discovery; never invoke design tools."""
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time

launcher = Path(sys.argv[1])
backend = json.loads((launcher.parent / "installation.json").read_text(encoding="utf-8"))["backend"]
errors = launcher.parent / "probe-stderr.log"
network_log = launcher.parent / "probe-network.log"
network_log.unlink(missing_ok=True)
environment = dict(os.environ, EDA_PROBE_NETWORK_LOG=str(network_log))
started = time.monotonic()
with errors.open("w", encoding="utf-8") as stderr:
    process = subprocess.Popen(
        [sys.executable, str(Path(__file__).with_name("offline_launcher.py")), str(launcher)], stdin=subprocess.PIPE,
        stdout=subprocess.PIPE, stderr=stderr, text=True, encoding="utf-8",
        env=environment,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    lines = queue.Queue()

    def read_stdout():
        for line in process.stdout:
            lines.put(line)
        lines.put(None)

    threading.Thread(target=read_stdout, daemon=True).start()

    def send(message):
        process.stdin.write(json.dumps(message) + "\n")
        process.stdin.flush()

    def receive(request_id):
        deadline = time.monotonic() + 60
        while True:
            line = lines.get(timeout=max(0, deadline - time.monotonic()))
            if line is None:
                raise RuntimeError(f"Server exited. See {errors}")
            message = json.loads(line)
            if message.get("id") == request_id:
                if "error" in message:
                    raise RuntimeError(message["error"])
                return message["result"]

    try:
        send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "offline-bundle-probe", "version": "1.0"},
        }})
        initialization = receive(1)
        send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        tools = receive(2)["tools"]
        assert tools, "Server advertised no tools"
        names = {tool["name"] for tool in tools}
        expected_toolset = environment.get("EDA_AGENT_TOOLSET", "minimal")
        if expected_toolset == "minimal":
            assert names == {"tool_catalog", "tool_invoke"}, "Minimal tool surface changed"
        # The full catalog must remain discoverable, including backend isolation.
        send({"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {
            "name": "tool_catalog", "arguments": {},
        }})
        catalog_result = receive(3)
        assert not catalog_result.get("isError"), catalog_result
        catalog = json.loads(next(item["text"] for item in catalog_result["content"] if item["type"] == "text"))
        catalog_names = {tool["name"] for tool in catalog["tools"]}
        if backend == "kicad":
            assert "kicad_ping" in catalog_names, "KiCad tools are missing"
            assert "app_get_status" not in catalog_names, "KiCad package advertised Altium tools"
        else:
            assert "app_get_status" in catalog_names, "Altium tools are missing"
            assert "kicad_ping" not in catalog_names, "Altium package advertised KiCad tools"
        # Exercise dispatch using only the read-only catalog, never an EDA call.
        query = "kicad_ping" if backend == "kicad" else "app_get_status"
        send({"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {
            "name": "tool_invoke", "arguments": {
                "name": "tool_catalog", "arguments": {"query": query, "with_schema": True},
            },
        }})
        invocation_result = receive(4)
        assert not invocation_result.get("isError"), invocation_result
        invocation = json.loads(next(item["text"] for item in invocation_result["content"] if item["type"] == "text"))
        assert invocation["tool"] == "tool_catalog", invocation
        discovered = invocation["result"]["tools"]
        assert any(tool["name"] == query and "parameters" in tool for tool in discovered), invocation
        context_bytes = len(json.dumps({"instructions": initialization.get("instructions", ""), "tools": tools}, ensure_ascii=False).encode("utf-8"))
        assert not network_log.exists(), f"External network attempted; see {network_log}"
        print(f"MCP {backend} ({expected_toolset}): {len(tools)} advertised tools, {len(catalog_names)} discoverable tools, {context_bytes} context bytes; catalog/schema/dispatch OK, {time.monotonic() - started:.2f}s, external network blocked")
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)
