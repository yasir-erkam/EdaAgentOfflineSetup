"""Read-only MCP handshake and tool discovery; never invoke design tools."""
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
        receive(1)
        send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        tools = receive(2)["tools"]
        assert tools, "Server advertised no tools"
        names = {tool["name"] for tool in tools}
        if backend == "kicad":
            assert "kicad_ping" in names, "KiCad tools are missing"
        else:
            assert "kicad_ping" not in names, "Altium package advertised KiCad tools"
        assert not network_log.exists(), f"External network attempted; see {network_log}"
        print(f"MCP {backend}: initialize and tools/list OK: {len(tools)} tools, {time.monotonic() - started:.2f}s, external network blocked")
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)
