"""Merge one MCP entry into JSON/JSONC, validating before backing up or writing."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile


def parse_jsonc(text):
    # Mask comments and trailing commas outside strings. Keep line breaks for errors.
    chars = list(text)
    i = 0
    quoted = False
    while i < len(chars):
        char = chars[i]
        if quoted:
            if char == "\\":
                i += 2
                continue
            if char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif text[i:i + 2] == "//":
            while i < len(chars) and chars[i] not in "\r\n":
                chars[i] = " "
                i += 1
            continue
        elif text[i:i + 2] == "/*":
            end = text.find("*/", i + 2)
            if end < 0:
                raise ValueError("Unterminated JSONC comment")
            for j in range(i, end + 2):
                if chars[j] not in "\r\n":
                    chars[j] = " "
            i = end + 2
            continue
        i += 1
    i = 0
    quoted = False
    while i < len(chars):
        if quoted:
            if chars[i] == "\\":
                i += 2
                continue
            if chars[i] == '"':
                quoted = False
        elif chars[i] == '"':
            quoted = True
        elif chars[i] == ",":
            j = i + 1
            while j < len(chars) and chars[j].isspace():
                j += 1
            previous = i - 1
            while previous >= 0 and chars[previous].isspace():
                previous -= 1
            if (j < len(chars) and chars[j] in "}]" and previous >= 0
                    and chars[previous] not in "[{,:"):
                chars[i] = " "
        i += 1
    def invalid_constant(value):
        raise ValueError(f"Invalid JSON constant: {value}")

    return json.loads("".join(chars), parse_constant=invalid_constant)


def load_config(target):
    data = parse_jsonc(target.read_text(encoding="utf-8-sig")) if target.exists() else {}
    if not isinstance(data, dict):
        raise ValueError("OpenCode configuration must be an object")
    if "mcp" not in data:
        data["mcp"] = {}
    if not isinstance(data["mcp"], dict):
        raise ValueError("Existing mcp field must be an object")
    return data


def configure(target, snippet):
    data = load_config(target)
    entry = json.loads(snippet.read_text(encoding="utf-8"))["mcp"]["eda-agent"]
    data["mcp"]["eda-agent"] = entry
    output = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        backup = target.with_name(target.name + "." + stamp + ".bak")
        shutil.copy2(target, backup)
        print(f"Configuration backup: {backup}")
    fd, name = tempfile.mkstemp(prefix=".eda-agent-", suffix=".tmp", dir=target.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(output)
        os.replace(name, target)
    finally:
        if os.path.exists(name):
            os.unlink(name)


if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("target", type=Path)
        parser.add_argument("snippet", type=Path, nargs="?")
        parser.add_argument("--check", action="store_true", help="Validate without writing")
        args = parser.parse_args()
        if args.check:
            load_config(args.target)
        elif args.snippet is None:
            parser.error("snippet is required unless --check is used")
        else:
            configure(args.target, args.snippet)
    except Exception as exc:
        print(f"Configuration failed: {exc}", file=sys.stderr)
        sys.exit(1)
