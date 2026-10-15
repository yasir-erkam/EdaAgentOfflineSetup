"""Validate deployed Pascal, DFM and project files, allowing upstream stamps."""
from pathlib import Path
import sys

from eda_agent.cli import get_bundled_scripts_path
from eda_agent.script_stamps import stamp_source

deployed = Path(sys.argv[1])
count = 0
for source in get_bundled_scripts_path().iterdir():
    if source.suffix not in {".pas", ".dfm", ".PrjScr"}:
        continue
    target = deployed / source.name
    expected = source.read_bytes().replace(b"\r\n", b"\n")
    if source.suffix == ".pas":
        bom = b"\xef\xbb\xbf" if expected.startswith(b"\xef\xbb\xbf") else b""
        expected = bom + stamp_source(expected.decode("utf-8-sig")).encode("utf-8")
    if not target.is_file() or target.read_bytes().replace(b"\r\n", b"\n") != expected:
        raise RuntimeError(f"Deployed script differs: {source.name}")
    count += 1
if count < 1:
    raise RuntimeError("No bundled Altium scripts found")
print(f"Deployed Altium scripts verified, including content stamps: {count} files")
