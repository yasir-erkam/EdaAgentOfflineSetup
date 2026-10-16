"""Exercise the prototype against temporary IPC files, without Altium."""
from contextlib import contextmanager
import json
from pathlib import Path
import shutil
import threading
import time
import unittest
import uuid

from probe_altium_connection import probe, validate_response


@contextmanager
def fixture_directory():
    root = Path(__file__).resolve().parents[1] / ".work"
    root.mkdir(exist_ok=True)
    folder = root / ("ping-test-" + uuid.uuid4().hex)
    folder.mkdir()
    try:
        yield folder
    finally:
        if folder.resolve().parent != root.resolve():
            raise RuntimeError("Cleanup path is outside the test root.")
        shutil.rmtree(folder)


def response_for(request_id):
    return {
        "id": request_id, "success": True, "protocol_version": 2,
        "data": {"pong": True, "protocol_version": 2, "script_version": "test",
                 "altium_version": "test", "script_projects": ["private-path"]},
    }


class ConnectionProbeTests(unittest.TestCase):
    def test_ping_only_and_unrelated_files_preserved(self):
        with fixture_directory() as folder:
            workspace = folder / "Türkçe çalışma alanı"
            workspace.mkdir()
            sentinels = {
                "request_other.json": b"another request",
                "response_other.json": b"another response",
                "progress_other.json": b"another progress",
                "workspace-path.txt": b"unchanged pointer",
                "design.SchDoc": b"unchanged design",
            }
            for name, content in sentinels.items():
                (workspace / name).write_bytes(content)
            received = []
            failures = []

            def respond():
                try:
                    deadline = time.monotonic() + 3
                    while time.monotonic() < deadline:
                        requests = [p for p in workspace.glob("request_*.json")
                                    if p.name not in sentinels]
                        if requests:
                            request = json.loads(requests[0].read_text(encoding="utf-8-sig"))
                            received.append(request)
                            target = workspace / f"response_{request['id']}.json"
                            staged = target.with_suffix(".tmp")
                            staged.write_text(json.dumps(response_for(request["id"])), encoding="utf-8")
                            staged.replace(target)
                            return
                        time.sleep(0.01)
                    raise AssertionError("Probe did not publish a request.")
                except Exception as exc:
                    failures.append(exc)

            thread = threading.Thread(target=respond)
            thread.start()
            try:
                result = probe(workspace, timeout=3)
            finally:
                thread.join(timeout=4)
            self.assertFalse(thread.is_alive())
            self.assertEqual(failures, [])
            self.assertEqual(len(received), 1)
            self.assertEqual(received[0]["command"], "application.ping")
            self.assertEqual(received[0]["params"], {})
            self.assertEqual(received[0]["protocol_version"], 2)
            self.assertEqual(result["status"], "responsive")
            self.assertFalse(result["session_verified"])
            self.assertFalse(result["project_verified"])
            self.assertNotIn("private-path", json.dumps(result))
            self.assertEqual({p.name: p.read_bytes() for p in workspace.iterdir()}, sentinels)

    def test_timeout_cleans_only_owned_files(self):
        with fixture_directory() as folder:
            marker = folder / "request_other.json"
            marker.write_bytes(b"keep")
            with self.assertRaises(TimeoutError):
                probe(folder, timeout=0.03)
            self.assertEqual(list(folder.iterdir()), [marker])
            self.assertEqual(marker.read_bytes(), b"keep")

    def test_refuse_missing_workspace_and_invalid_timeout(self):
        with fixture_directory() as folder:
            with self.assertRaises(FileNotFoundError):
                probe(folder / "missing")
            for timeout in (0, -1, 61, float("nan"), float("inf")):
                with self.subTest(timeout=timeout), self.assertRaises(ValueError):
                    probe(folder, timeout)
            self.assertEqual(list(folder.iterdir()), [])

    def test_reject_wrong_id_protocol_failure_and_invalid_pong(self):
        samples = []
        for key, value in (("id", "other"), ("protocol_version", 3),
                           ("protocol_version", True), ("success", False), ("data", None)):
            response = response_for("expected")
            response[key] = value
            samples.append(response)
        for key, value in (("pong", False), ("pong", 1), ("protocol_version", 1),
                           ("script_version", "")):
            response = response_for("expected")
            response["data"][key] = value
            samples.append(response)
        samples.extend([None, [], "invalid"])
        for response in samples:
            with self.subTest(response=response), self.assertRaises(ValueError):
                validate_response(response, "expected")


if __name__ == "__main__":
    unittest.main()
