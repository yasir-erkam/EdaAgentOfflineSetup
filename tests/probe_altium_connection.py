"""Prototype IPC-v2 ping probe; never save designs or initialize an upstream bridge.

Pass an existing workspace explicitly. This writes only its own IPC request and
does not update the shared workspace pointer. A pong proves channel liveness,
not the identity of an Altium process, a selected project, or an MCP client.
"""
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import time
import uuid


PROTOCOL_VERSION = 2


def validate_response(response, request_id):
    if not isinstance(response, dict) or response.get("id") != request_id:
        raise ValueError("Response does not match this probe's request.")
    version = response.get("protocol_version")
    if type(version) is not int or version != PROTOCOL_VERSION:
        raise ValueError("Unsupported response protocol version.")
    if response.get("success") is not True:
        raise ValueError("Altium returned an unsuccessful ping response.")
    data = response.get("data")
    if not isinstance(data, dict) or data.get("pong") is not True:
        raise ValueError("Response does not contain a valid pong.")
    if type(data.get("protocol_version")) is not int or data["protocol_version"] != PROTOCOL_VERSION:
        raise ValueError("Ping payload protocol version does not match.")
    if not isinstance(data.get("script_version"), str) or not data["script_version"].strip():
        raise ValueError("Ping payload has no script version.")
    # Do not echo project paths or arbitrary response content into shared logs.
    return {
        "status": "responsive",
        "checked_utc": datetime.now(timezone.utc).isoformat(),
        "script_version": data["script_version"],
        "altium_version": data.get("altium_version", ""),
        "session_verified": False,
        "project_verified": False,
    }


def probe(workspace, timeout=10.0):
    if not math.isfinite(timeout) or not 0 < timeout <= 60:
        raise ValueError("Timeout must be greater than zero and at most 60 seconds.")
    workspace = Path(workspace).resolve(strict=True)
    if not workspace.is_dir():
        raise ValueError("Workspace must be an existing directory.")
    request_id = uuid.uuid4().hex
    request_path = workspace / f"request_{request_id}.json"
    staged_path = workspace / f"request_{request_id}.json.tmp"
    response_path = workspace / f"response_{request_id}.json"
    request = {
        "protocol_version": PROTOCOL_VERSION,
        "id": request_id,
        "command": "application.ping",
        "params": {},
    }
    try:
        # Match upstream's BOM encoding and atomic request publication.
        with staged_path.open("x", encoding="utf-8-sig") as handle:
            json.dump(request, handle)
        staged_path.replace(request_path)
        deadline = time.monotonic() + timeout
        while True:
            try:
                raw = response_path.read_text(encoding="utf-8-sig")
            except (FileNotFoundError, PermissionError):
                pass
            else:
                return validate_response(json.loads(raw), request_id)
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("No pong before the deadline; bridge state is unknown.")
            time.sleep(min(0.05, remaining))
    finally:
        # Never sweep a workspace, progress markers, or another caller's files.
        for owned_path in (staged_path, request_path, response_path):
            owned_path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()
    try:
        result = probe(args.workspace, args.timeout)
    except TimeoutError as exc:
        print(json.dumps({"status": "unknown", "error": str(exc)}))
        return 2
    except (OSError, ValueError) as exc:
        print(json.dumps({"status": "error", "error": str(exc)}))
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
