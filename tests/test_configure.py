"""Regression checks for preserving valid config and refusing invalid JSONC."""
from contextlib import contextmanager
import json
from pathlib import Path
import runpy
import sys
import shutil
import unittest
import uuid

helper = runpy.run_path(sys.argv.pop(1))
parse_jsonc = helper["parse_jsonc"]
configure = helper["configure"]
remove_owned = helper["remove_owned"]
temporary_root = Path(__file__).resolve().parents[1] / ".work"
temporary_root.mkdir(exist_ok=True)


@contextmanager
def fixture_directory():
    # Inherit the workspace ACL; Python's private 0700 temp ACL can exclude a
    # restricted Windows test token even when it can create the directory.
    folder = temporary_root / ("config-test-" + uuid.uuid4().hex)
    folder.mkdir()
    try:
        yield folder
    finally:
        if folder.resolve().parent != temporary_root.resolve():
            raise RuntimeError("Refusing cleanup outside the fixture root")
        shutil.rmtree(folder)


class ConfigurationTests(unittest.TestCase):
    def test_comments_escapes_and_trailing_commas(self):
        expected = {"url": "https://example.invalid/*x*/", "text": 'escaped " //', "items": [1, 2]}
        source = json.dumps(expected).replace('[1, 2]', '[1, 2, /* end */]')
        source = source[:-1] + ', // comment\n}'
        self.assertEqual(parse_jsonc(source), expected)

    def test_invalid_jsonc(self):
        for source in ('{,}', '[,]', '[1,,]', '{"x":NaN}', '{"x":Infinity}', '{"x":/*', '{"x":"unterminated}'):
            with self.subTest(source=source), self.assertRaises(ValueError):
                parse_jsonc(source)

    def test_add_mcp_to_template_without_mcp(self):
        with fixture_directory() as folder:
            target = Path(folder) / "config.jsonc"
            snippet = Path(folder) / "mcp.json"
            original = b'{"provider":{"test":{"options":{"apiKey":"preserve-me"}}}}'
            target.write_bytes(original)
            snippet.write_text(json.dumps({"mcp": {"eda-agent": {"type": "local", "command": ["python.exe", "launch.py"], "enabled": True}}}))
            configure(target, snippet)
            self.assertEqual(json.loads(target.read_text())["provider"]["test"]["options"]["apiKey"], "preserve-me")
            self.assertEqual(next(Path(folder).glob("*.bak")).read_bytes(), original)

    def test_invalid_mcp_shape_is_untouched(self):
        with fixture_directory() as folder:
            target = Path(folder) / "config.jsonc"
            for source in (b'[]', b'{"mcp":null}', b'{"mcp":[]}'):
                target.write_bytes(source)
                with self.assertRaises(ValueError):
                    configure(target, Path(folder) / "does-not-exist.json")
                self.assertEqual(target.read_bytes(), source)

    def test_uninstall_removes_only_owned_entry(self):
        with fixture_directory() as folder:
            target = folder / "config.jsonc"
            snippet = folder / "mcp.json"
            entry = {"type": "local", "command": ["C:/EDA/python.exe", "C:/EDA/launch.py"], "enabled": True}
            snippet.write_text(json.dumps({"mcp": {"eda-agent": entry}}))
            data = {"provider": {"test": {"apiKey": "keep"}}, "mcp": {"other": {"enabled": False}, "eda-agent": entry}}
            target.write_text(json.dumps(data))
            remove_owned(target, snippet)
            result = json.loads(target.read_text())
            self.assertEqual(result["provider"], data["provider"])
            self.assertEqual(result["mcp"], {"other": {"enabled": False}})

    def test_uninstall_preserves_different_installation(self):
        with fixture_directory() as folder:
            target = folder / "config.jsonc"
            snippet = folder / "mcp.json"
            original = b'{"mcp":{"eda-agent":{"command":["other-python.exe","other-launch.py"]}}}'
            target.write_bytes(original)
            snippet.write_text('{"mcp":{"eda-agent":{"command":["owned-python.exe","owned-launch.py"]}}}')
            remove_owned(target, snippet)
            self.assertEqual(target.read_bytes(), original)
            self.assertFalse(list(folder.glob("*.bak")))

    def test_altium_and_kicad_coexist(self):
        with fixture_directory() as folder:
            target = folder / "config.jsonc"
            altium = folder / "altium.json"
            kicad = folder / "kicad.json"
            altium.write_text('{"mcp":{"eda-agent":{"command":["altium-python.exe","launch.py"]}}}')
            kicad.write_text('{"mcp":{"eda-agent-kicad":{"command":["kicad-python.exe","launch.py"]}}}')
            configure(target, altium)
            configure(target, kicad)
            self.assertEqual(set(json.loads(target.read_text())["mcp"]), {"eda-agent", "eda-agent-kicad"})
            remove_owned(target, kicad)
            self.assertEqual(set(json.loads(target.read_text())["mcp"]), {"eda-agent"})
            remove_owned(target, altium)
            self.assertNotIn("mcp", json.loads(target.read_text()))


if __name__ == "__main__":
    unittest.main()
