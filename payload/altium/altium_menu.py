"""Altium menu control and stale-target fencing. Standard library only."""
import argparse
from contextvars import ContextVar
from datetime import datetime, timezone
from functools import wraps
import inspect
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

SUPPORTED_TOOLS = frozenset({"tool_catalog", "tool_invoke", "tool_guide", "app_ping",
                             "app_get_version", "pcb_get_components", "pcb_get_nets", "pcb_move_components"})
_tool_revision = ContextVar("eda_menu_tool_revision", default=None)


def configure_pointer_encoding(config_module, workspace, ansi_encoding="mbcs"):
    """Keep legacy ANSI pointers where possible; otherwise use UTF-8 with BOM.

    The local Pascal overlay reads both through upstream's BOM-aware text reader.
    """
    try:
        str(workspace).encode(ansi_encoding)
    except (UnicodeEncodeError, LookupError):
        config_module._pointer_encoding = lambda: "utf-8-sig"


def install_tool_guard(tools_module, workspace=None):
    """Guard both full and minimal MCP tools, including tools that bypass IPC."""
    original = tools_module._register_full
    if getattr(original, "_offline_menu_guard", False):
        return

    class Proxy:
        def __init__(self, target):
            self.target = target

        def __getattr__(self, name):
            return getattr(self.target, name)

        def tool(self, *args, **kwargs):
            decorator = self.target.tool(*args, **kwargs)

            def register(fn):
                @wraps(fn)
                async def guarded(*positional, **named):
                    if fn.__name__ not in SUPPORTED_TOOLS:
                        return {"success": False, "error": {"code": "UNREVIEWED_TARGET_SCOPE",
                            "message": "This tool is disabled in guarded menu mode; see the supported target scope table."}}
                    token = None
                    if workspace is not None and _tool_revision.get() is None:
                        token = _tool_revision.set(revision_for(workspace))
                    try:
                        return await fn(*positional, **named)
                    finally:
                        if token is not None:
                            _tool_revision.reset(token)
                # FastMCP resolves annotations in the wrapper's globals. Preserve
                # evaluated original types rather than its foreign forward refs.
                guarded.__signature__ = inspect.signature(fn, eval_str=True)
                guarded.__annotations__ = inspect.get_annotations(fn, eval_str=True)
                if fn.__name__ not in SUPPORTED_TOOLS:
                    guarded.__doc__ = "Unavailable in guarded Altium menu mode: target scope has not been reviewed."
                return decorator(guarded)
            return register

    def register(target, *args, **kwargs):
        return original(Proxy(target), *args, **kwargs)

    register._offline_menu_guard = True
    tools_module._register_full = register


def revision_for(workspace):
    try:
        state = json.loads((Path(workspace) / "eda-menu-state.json").read_text(encoding="utf-8-sig"))
        if not isinstance(state, dict) or not isinstance(state.get("revision"), str):
            return ""
        return state["revision"] if state.get("running") is True else ""
    except (OSError, ValueError, KeyError, TypeError):
        return ""


def install_bridge_guard(bridge_type):
    """Fence requests at publication; Pascal checks again at execution time."""
    if getattr(bridge_type, "_offline_menu_guard", False):
        return
    original = bridge_type._publish_request
    original_send = bridge_type.send_command
    original_async = bridge_type.send_command_async

    def fence(self, params):
        params = dict(params or {})
        workspace = self.config.workspace_dir
        if (workspace / "eda-menu-enabled").is_file():
            captured = _tool_revision.get()
            params.setdefault("_eda_menu_revision", revision_for(workspace) if captured is None else captured)
        return params

    def send(self, command, params=None, timeout=None):
        return original_send(self, command, fence(self, params), timeout)

    def send_async(self, command, params=None, timeout=None):
        # Capture before upstream queues work in its single-worker executor.
        return original_async(self, command, fence(self, params), timeout)

    def publish(self, request):
        workspace = self.config.workspace_dir
        if (workspace / "eda-menu-enabled").is_file():
            request.params = fence(self, request.params)
        return original(self, request)

    bridge_type._publish_request = publish
    bridge_type.send_command = send
    bridge_type.send_command_async = send_async
    bridge_type._offline_menu_guard = True


class MenuError(RuntimeError):
    pass


class Controller:
    def __init__(self, root, timeout=10, caller_id="", session_id="", process_identity=""):
        self.root = Path(root).resolve()
        settings = json.loads((self.root / "installation.json").read_text(encoding="utf-8"))
        if settings.get("backend") != "altium":
            raise MenuError("Altium menu control is only available in the Altium package.")
        self.workspace = self.root / "workspace"
        self.enabled = (self.workspace / "eda-menu-enabled").is_file()
        self.timeout = timeout
        self.caller_id = caller_id
        self.session_id = session_id
        if any(c not in "0123456789-" for c in caller_id + session_id):
            raise MenuError("Invalid Altium context identity.")
        if process_identity:
            try:
                pid, created = process_identity.split(":")
                self.process_identity = (int(pid), float(created))
            except ValueError:
                raise MenuError("Invalid Altium process identity.")

    def process_token(self):
        self.sole_process()
        return str(self.process_identity[0]) + ":" + repr(self.process_identity[1])

    def sole_process(self):
        import psutil
        candidates = list(psutil.process_iter(["name", "create_time"]))
        candidates = [p for p in candidates if (p.info.get("name") or "").lower() in {"x2.exe", "dxp.exe"}]
        if len(candidates) != 1:
            raise MenuError("Exactly one Altium session is required; no session was selected or changed.")
        process = candidates[0]
        identity = (process.pid, process.create_time())
        if hasattr(self, "process_identity") and self.process_identity != identity:
            raise MenuError("Altium process changed; reopen Connection Assistant.")
        self.process_identity = identity
        return process

    def dispatch(self, action):
        process = self.sole_process()
        lock = self.workspace / "eda-assistant-launch.lock"
        try:
            lock.mkdir()
        except FileExistsError:
            raise MenuError("Another assistant launch is pending; no start was attempted.")
        nonce = uuid.uuid4().hex
        response = lock / ("response-" + nonce + ".json")
        intent = lock / "intent.json"
        confirmed = False
        try:
            from datetime import timedelta
            body = {"nonce": nonce, "caller_id": self.caller_id, "action": action, "session_id": self.session_id,
                    "expires": (datetime.now() + timedelta(seconds=self.timeout)).strftime("%Y%m%d%H%M%S")}
            staged = lock / "intent.tmp"
            staged.write_text(json.dumps(body), encoding="utf-8-sig")
            staged.replace(intent)
            project = self.root / "scripts" / "Altium_API.PrjScr"
            command = f"-RScriptingSystem:RunScript(ProjectName={project}|ProcName=ConnectionAssistant.pas>DispatchConnectionAssistant)"
            self.sole_process()
            subprocess.Popen([process.exe(), command], close_fds=True)
            deadline = time.monotonic() + self.timeout
            while time.monotonic() < deadline:
                try:
                    data = json.loads(response.read_text(encoding="utf-8-sig"))
                except (OSError, ValueError):
                    time.sleep(0.05)
                    continue
                self.sole_process()
                if not isinstance(data, dict):
                    raise MenuError("Invalid native launch response.")
                if data.get("nonce") != nonce or data.get("error"):
                    raise MenuError(data.get("error", "Unexpected native launch response."))
                if self.caller_id and data.get("caller_id") != self.caller_id:
                    raise MenuError("Calling Altium context changed.")
                if not data.get("caller_id"):
                    raise MenuError("Native caller identity was not confirmed.")
                if action == "prepare" and self.caller_id and data.get("session_id") != self.session_id:
                    raise MenuError("Calling Altium session changed; reopen Connection Assistant.")
                if action == "start" and (not isinstance(data.get("session_id"), str) or not data["session_id"] or data.get("running") is not True):
                    raise MenuError("Native bridge start was not confirmed.")
                confirmed = True
                self.caller_id = data["caller_id"]
                self.session_id = data.get("session_id", "")
                return data
            raise TimeoutError("Native launch was not confirmed; no retry or force was attempted.")
        finally:
            # A late callback must not consume a replacement owner's intent.
            # Keep an unconfirmed mailbox until all Altium sessions are closed.
            if confirmed:
                for path in (intent, response, lock / "intent.tmp"):
                    path.unlink(missing_ok=True)
                try:
                    lock.rmdir()
                except OSError:
                    pass

    def prepare(self):
        token = self.process_token()
        if not self.enabled:
            return {"caller_id": "", "session_id": "", "running": False, "process_identity": token}
        if self.caller_id:
            if not (self.workspace / ("eda-assistant-caller-" + self.caller_id + ".json")).is_file():
                raise MenuError("Calling Altium context is unavailable; reopen Connection Assistant.")
        data = self.dispatch("prepare")
        data["process_identity"] = token
        return data

    def request(self, command, params=None):
        if command not in {"application.ping", "eda_menu.status", "eda_menu.select", "eda_menu.disconnect"}:
            raise MenuError("Unsupported menu control command.")
        if hasattr(self, "process_identity"):
            self.sole_process()
        request_id = uuid.uuid4().hex
        staged = self.workspace / f"request_{request_id}.json.tmp"
        request = staged.with_suffix("")
        response = self.workspace / f"response_{request_id}.json"
        if self.enabled and (not self.caller_id or not self.session_id):
            raise MenuError("Start the connection in this assistant before requesting bridge status.")
        body = {"protocol_version": 2, "id": request_id, "command": command,
                "params": dict(params or {}, _eda_menu_revision=revision_for(self.workspace),
                               _eda_caller_id=self.caller_id, _eda_session_id=self.session_id)}
        try:
            with staged.open("x", encoding="utf-8-sig") as stream:
                json.dump(body, stream, ensure_ascii=False)
            staged.replace(request)
            deadline = time.monotonic() + self.timeout
            while True:
                try:
                    data = json.loads(response.read_text(encoding="utf-8-sig"))
                except (FileNotFoundError, PermissionError, json.JSONDecodeError, UnicodeDecodeError):
                    # SaveToFile publishes directly to this path; an existing file
                    # may still contain only part of the JSON or a UTF-8 character.
                    pass
                else:
                    if not isinstance(data, dict) or data.get("id") != request_id or type(data.get("protocol_version")) is not int or data["protocol_version"] != 2:
                        raise MenuError("Unexpected bridge response; status is unknown.")
                    if data.get("success") is not True:
                        error = data.get("error") or {}
                        raise MenuError(str(error.get("message", error)))
                    if not isinstance(data.get("data"), dict):
                        raise MenuError("Bridge returned invalid control data.")
                    if self.enabled and (data["data"].get("caller_id") != self.caller_id or
                                         data["data"].get("session_id") != self.session_id):
                        raise MenuError("Bridge response belongs to another session.")
                    return data["data"]
                if time.monotonic() >= deadline:
                    raise TimeoutError("Bridge did not answer; its state is unknown. No force or save was attempted.")
                time.sleep(0.05)
        finally:
            for path in (staged, request, response):
                path.unlink(missing_ok=True)

    def status(self):
        data = self.request("eda_menu.status" if self.enabled else "application.ping")
        if self.enabled and data.get("integration_version") != 2:
            raise MenuError("Reload the installed Altium script project; menu adapter version mismatch.")
        if not self.enabled:
            if data.get("pong") is not True:
                raise MenuError("Bridge did not return a valid pong.")
            data.update(running=True, target_project="", projects=[], session_verified=False)
        data["guarded_menu"] = self.enabled
        data["checked_utc"] = datetime.now(timezone.utc).isoformat()
        data["mcp_client_verified"] = False
        return data

    def start(self):
        if self.enabled:
            if not self.caller_id:
                self.prepare()
            self.dispatch("start")
            return self.status()
        self.sole_process()
        # Upstream returns after publishing the start request, so probe afterwards.
        result = subprocess.run([str(self.root / "runtime" / "python.exe"),
                                 str(self.root / "launch.py"), "relaunch"],
                                capture_output=True, text=True, timeout=20,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        if result.returncode:
            raise MenuError(result.stdout + result.stderr)
        return self.status()

    def select(self, project):
        if not self.enabled:
            raise MenuError("Enable guarded Altium menu support in setup first.")
        # Dispatcher validates the full path against open projects and rotates revision.
        return self.request("eda_menu.select", {"project_path": project})

    def disconnect(self):
        if not self.enabled:
            raise MenuError("Safe disconnect requires guarded Altium menu support. No save or stop was attempted.")
        self.request("eda_menu.disconnect")
        deadline = time.monotonic() + self.timeout
        while time.monotonic() < deadline:
            try:
                state = json.loads((self.workspace / "eda-menu-state.json").read_text(encoding="utf-8-sig"))
            except (OSError, ValueError):
                state = {}
            if (state.get("running") is False and state.get("caller_id") == self.caller_id
                    and state.get("session_id") == self.session_id):
                # The pump removes its atomic directory lease only after finalization.
                if not (self.workspace / "eda-menu-session.lock").exists():
                    return {"running": False, "saved": False, "caller_id": self.caller_id, "session_id": self.session_id}
            time.sleep(0.05)
        raise TimeoutError("Stop was requested but not confirmed; do not force restart.")


def main():
    for stream in (sys.stdout, sys.stderr):
        if stream is not None and hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "start", "status", "select", "disconnect", "reconnect"))
    parser.add_argument("--project")
    parser.add_argument("--caller-id", default="")
    parser.add_argument("--session-id", default="")
    parser.add_argument("--process-identity", default="")
    args = parser.parse_args()
    try:
        controller = Controller(Path(__file__).resolve().parent, caller_id=args.caller_id,
                                session_id=args.session_id, process_identity=args.process_identity)
        if args.command == "select":
            if not args.project:
                raise MenuError("Select requires --project with an open design project path.")
            result = controller.select(args.project)
        elif args.command == "reconnect":
            controller.disconnect()
            result = controller.start()
        else:
            result = getattr(controller, args.command)()
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (OSError, ValueError, MenuError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
