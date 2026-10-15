"""Keep the Altium and KiCad products in distinct installation folders."""
import json
from pathlib import Path
import sys

try:
    target, backend = Path(sys.argv[1]), sys.argv[2]
    for name in ("installation.json", "bundle.json"):
        metadata = target / name
        if metadata.exists() and json.loads(metadata.read_text(encoding="utf-8-sig")).get("backend") != backend:
            sys.exit(1)
except (OSError, ValueError, IndexError):
    sys.exit(1)
