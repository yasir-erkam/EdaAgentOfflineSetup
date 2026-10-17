"""Offline integration regressions; never open Altium or touch its profiles."""
import asyncio
from contextlib import contextmanager
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import threading
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


menu = load_module("menu_control", ROOT / "payload/altium/altium_menu.py")
patcher = load_module("menu_patch", ROOT / "installer/apply_altium_menu.py")


@contextmanager
def fixture(backend="altium", enabled=True):
    parent = ROOT / ".work"
    parent.mkdir(exist_ok=True)
    folder = parent / ("menu-test-" + uuid.uuid4().hex)
    folder.mkdir()
    (folder / "installation.json").write_text(json.dumps({"backend": backend}), encoding="utf-8")
    workspace = folder / "workspace"
    workspace.mkdir()
    if enabled:
        (workspace / "eda-menu-enabled").write_text("1")
    try:
        yield folder
    finally:
        if folder.resolve().parent != parent.resolve():
            raise RuntimeError("Refusing cleanup outside test root.")
        shutil.rmtree(folder)


def write_state(workspace, revision, running=True):
    (workspace / "eda-menu-state.json").write_text(json.dumps({
        "revision": revision, "running": running, "target_project": "A.PrjPcb"}), encoding="utf-8")


class MenuTests(unittest.TestCase):
    def test_cli_emits_unicode_json_even_with_ansi_parent(self):
        buffer = io.BytesIO()
        stream = io.TextIOWrapper(buffer, encoding="cp1252")
        with patch.object(menu, "Controller") as control, patch("sys.argv", ["altium_menu.py", "status"]), patch("sys.stdout", stream):
            control.return_value.status.return_value = {"target_project": "Türkçe alanı"}
            self.assertEqual(menu.main(), 0)
            stream.flush()
            result = json.loads(buffer.getvalue().decode("utf-8"))
            self.assertEqual(result["target_project"], "Türkçe alanı")
        stream.detach()

    def test_unicode_pointer_fallback_preserves_ansi_when_possible(self):
        config = SimpleNamespace(_pointer_encoding=lambda: "cp1252")
        menu.configure_pointer_encoding(config, "D:\\EDA Agent\\workspace", "cp1252")
        self.assertEqual(config._pointer_encoding(), "cp1252")
        path = "D:\\Türkçe kurulum alanı\\workspace"
        menu.configure_pointer_encoding(config, path, "cp1252")
        self.assertEqual(config._pointer_encoding(), "utf-8-sig")
        self.assertEqual(path.encode(config._pointer_encoding()).decode("utf-8-sig"), path)

    def test_target_revision_is_captured_at_tool_entry(self):
        class Bridge:
            def _publish_request(self, request):
                return request.params
            def send_command(self, command, params=None, timeout=None):
                return self._publish_request(SimpleNamespace(params=params))
            async def send_command_async(self, command, params=None, timeout=None):
                return self.send_command(command, params, timeout)

        class Registry:
            def tool(self):
                def register(fn):
                    self.fn = fn
                    return fn
                return register

        with fixture() as root:
            workspace = root / "workspace"
            bridge = Bridge()
            bridge.config = SimpleNamespace(workspace_dir=workspace)
            menu.install_bridge_guard(Bridge)

            def register_all(registry):
                @registry.tool()
                async def pcb_get_nets():
                    write_state(workspace, "changed-during-tool")
                    return bridge.send_command("pcb.get_nets")

            module = SimpleNamespace(_register_full=register_all)
            menu.install_tool_guard(module, workspace)
            registry = Registry()
            module._register_full(registry)
            write_state(workspace, "at-entry")
            self.assertEqual(asyncio.run(registry.fn())["_eda_menu_revision"], "at-entry")

    def test_tool_guard_blocks_python_side_effects_and_nested_invoke(self):
        called = []

        class Registry:
            def __init__(self):
                self.functions = {}

            def tool(self):
                def register(fn):
                    self.functions[fn.__name__] = fn
                    return fn
                return register

            async def call_tool(self, name):
                return await self.functions[name]()

        def register_all_tools(registry):
            @registry.tool()
            async def app_save_all():
                called.append("save")

            @registry.tool()
            async def tool_invoke():
                return await registry.call_tool("app_save_all")

            @registry.tool()
            async def pcb_get_nets():
                called.append("query")
                return {"nets": []}

        module = SimpleNamespace(_register_full=register_all_tools)
        menu.install_tool_guard(module)
        menu.install_tool_guard(module)
        registry = Registry()
        module._register_full(registry)
        for name in ("app_save_all", "tool_invoke"):
            result = asyncio.run(registry.call_tool(name))
            self.assertEqual(result["error"]["code"], "UNREVIEWED_TARGET_SCOPE")
        self.assertEqual(asyncio.run(registry.call_tool("pcb_get_nets")), {"nets": []})
        self.assertEqual(called, ["query"])

    def test_control_roundtrip_carries_revision_and_rotates_target(self):
        with fixture() as root:
            workspace = root / "workspace"
            write_state(workspace, "old")
            requests, errors = [], []

            def respond():
                try:
                    deadline = time.monotonic() + 2
                    while time.monotonic() < deadline:
                        paths = list(workspace.glob("request_*.json"))
                        if paths:
                            body = json.loads(paths[0].read_text(encoding="utf-8-sig"))
                            requests.append(body)
                            write_state(workspace, "new")
                            result = {"protocol_version": 2, "id": body["id"], "success": True,
                                      "data": {"revision": "new", "target_project": body["params"]["project_path"]}}
                            response = workspace / f"response_{body['id']}.json"
                            temp = response.with_suffix(".tmp")
                            temp.write_text(json.dumps(result), encoding="utf-8")
                            temp.replace(response)
                            return
                        time.sleep(0.01)
                    raise AssertionError("No request published")
                except Exception as exc:
                    errors.append(exc)

            thread = threading.Thread(target=respond)
            thread.start()
            try:
                result = menu.Controller(root, timeout=2).select("D:\\Tasarımlar\\A.PrjPcb")
            finally:
                thread.join(timeout=3)
            self.assertEqual(errors, [])
            self.assertEqual(requests[0]["command"], "eda_menu.select")
            self.assertEqual(requests[0]["params"]["_eda_menu_revision"], "old")
            self.assertEqual(result["revision"], "new")
            self.assertFalse(list(workspace.glob("request_*.json")))

    def test_old_queued_command_keeps_old_revision(self):
        class Bridge:
            def _publish_request(self, request):
                return request.params

            def send_command(self, command, params=None, timeout=None):
                return self._publish_request(SimpleNamespace(params=params))

            async def send_command_async(self, command, params=None, timeout=None):
                return self.send_command(command, params, timeout)

        with fixture() as root:
            workspace = root / "workspace"
            bridge = Bridge()
            bridge.config = SimpleNamespace(workspace_dir=workspace)
            menu.install_bridge_guard(Bridge)
            menu.install_bridge_guard(Bridge)  # reinstallation must not recurse
            write_state(workspace, "before")
            queued = bridge.send_command_async("pcb.batch_move_components", {"designator": "U1"})
            write_state(workspace, "after")
            self.assertEqual(asyncio.run(queued)["_eda_menu_revision"], "before")
            self.assertEqual(bridge.send_command("pcb.get_nets")["_eda_menu_revision"], "after")
            (workspace / "eda-menu-state.json").write_text("{broken")
            self.assertEqual(bridge.send_command("pcb.batch_move_components")["_eda_menu_revision"], "")

    def test_legacy_ping_and_kicad_isolation(self):
        with fixture(enabled=False) as root:
            control = menu.Controller(root)
            with patch.object(control, "request", return_value={"pong": True}) as request:
                self.assertFalse(control.status()["guarded_menu"])
                request.assert_called_once_with("application.ping")
            with self.assertRaises(menu.MenuError):
                control.disconnect()
            with self.assertRaises(menu.MenuError):
                control.select("A.PrjPcb")
        with fixture(backend="kicad") as root:
            with self.assertRaises(menu.MenuError):
                menu.Controller(root)

    def test_status_does_not_claim_mcp_client_connection(self):
        with fixture() as root:
            control = menu.Controller(root)
            with patch.object(control, "request", return_value={"integration_version": 1, "running": True}):
                self.assertFalse(control.status()["mcp_client_verified"])
            with patch.object(control, "request", return_value={"integration_version": 99}):
                with self.assertRaises(menu.MenuError):
                    control.status()

    def test_reconnect_does_not_start_after_failed_stop(self):
        # Exercise the same explicit ordering used by the CLI, without a real process.
        with patch.object(menu, "Controller") as controller, patch("sys.argv", ["altium_menu.py", "reconnect"]):
            controller.return_value.disconnect.side_effect = TimeoutError("unknown")
            self.assertEqual(menu.main(), 1)
            controller.return_value.start.assert_not_called()

    def test_disconnect_requires_finalization_and_never_sends_save(self):
        with fixture() as root:
            workspace = root / "workspace"
            write_state(workspace, "stopped", running=False)
            control = menu.Controller(root, timeout=0.01)
            with patch.object(control, "request", return_value={"stopping": True}) as request:
                self.assertEqual(control.disconnect(), {"running": False, "saved": False})
                request.assert_called_once_with("eda_menu.disconnect")
            (workspace / "eda-menu-session.lock").mkdir()
            with patch.object(control, "request", return_value={"stopping": True}):
                with self.assertRaises(TimeoutError):
                    control.disconnect()

    def test_raw_ipc_rejects_save_commands_before_writing(self):
        with fixture() as root:
            workspace = root / "workspace"
            before = sorted(p.name for p in workspace.iterdir())
            with self.assertRaises(menu.MenuError):
                menu.Controller(root).request("application.save_all")
            self.assertEqual(sorted(p.name for p in workspace.iterdir()), before)

    def test_missing_response_is_unknown_and_preserves_other_requests(self):
        with fixture() as root:
            workspace = root / "workspace"
            unrelated = workspace / "request_other.json"
            unrelated.write_text("keep")
            with self.assertRaises(TimeoutError):
                menu.Controller(root, timeout=0.01).status()
            self.assertEqual(unrelated.read_text(), "keep")
            self.assertEqual(sorted(p.name for p in workspace.iterdir()), ["eda-menu-enabled", "request_other.json"])

    def test_patch_refuses_unknown_source_before_any_writes(self):
        with fixture() as root:
            for name in patcher.ORIGINALS:
                (root / name).write_bytes(b"unrecognized")
            with self.assertRaises(ValueError):
                patcher.apply(root, ROOT / "installer/altium", patcher.PINNED_COMMIT)
            for name in patcher.ORIGINALS:
                self.assertEqual((root / name).read_bytes(), b"unrecognized")
            self.assertFalse((root / "MenuForm.pas").exists())

    @unittest.skipUnless(os.environ.get("EDA_MENU_UPSTREAM_SCRIPTS"), "Pass the pinned upstream source for overlay checks")
    def test_patch_manifest_guards_and_deployed_form_order(self):
        with fixture() as root:
            scripts = root / "scripts"
            shutil.copytree(os.environ["EDA_MENU_UPSTREAM_SCRIPTS"], scripts)
            patcher.apply(scripts, ROOT / "installer/altium", patcher.PINNED_COMMIT)
            patcher.verify(scripts, ROOT / "installer/altium")
            main = (scripts / "Main.pas").read_text(encoding="utf-8")
            self.assertLess(main.index("Function ReadFileContent("), main.index("Function ResolveDefaultWorkspaceDir("))
            self.assertIn("Line := ReadFileContent(PointerFile);", main)
            project = (scripts / "Altium_API.PrjScr").read_text(encoding="utf-8")
            self.assertLess(project.index("DocumentPath=StatusForm.pas"), project.index("DocumentPath=MenuForm.pas"))
            self.assertLess(project.index("DocumentPath=MenuForm.pas"), project.index("DocumentPath=Dispatcher.pas"))
            status = (scripts / "StatusForm.pas").read_text(encoding="utf-8")
            start = status.index("Procedure StartMCPPump(")
            self.assertLess(status.index("If Not EdaMenuAcquire(0) Then Exit;", start), status.index("CleanupOrphanRequests(0);", start))
            dispatch = status.index("Function ProcessCommand(")
            self.assertLess(status.index("GuardError := EdaMenuGuard", dispatch), status.index("Case Category Of", dispatch))
            (scripts / "MenuForm.pas").write_text("modified")
            with self.assertRaises(ValueError):
                patcher.verify(scripts, ROOT / "installer/altium")


if __name__ == "__main__":
    unittest.main()
