"""Apply a reviewed, hash-checked local overlay to the pinned Altium scripts."""
import argparse
import hashlib
import json
from pathlib import Path

PINNED_COMMIT = "f552f69175bea93c6f53571021852de43f05447f"
ORIGINALS = {
    "Main.pas": "1c8ed7b64ca39f847011668be72757fa36af036696e37367c77dc3764b1212db",
    "StatusForm.pas": "ce5926072b116e6875fb0a35eba35e2db1ba9bbee37b6bb423db79efd9709050",
    "Altium_API.PrjScr": "4d837d2751c1a65b0f1625998feee6bd7435c2c49328c9ea4480f97eda50b2db",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Patch anchor must occur exactly once: {old[:70]!r}")
    return text.replace(old, new, 1)


def apply(scripts, overlay, commit):
    scripts, overlay = Path(scripts), Path(overlay)
    if commit != PINNED_COMMIT:
        raise ValueError("Altium menu overlay needs review for this upstream commit.")
    originals = {name: (scripts / name).read_bytes() for name in ORIGINALS}
    for name, expected in ORIGINALS.items():
        if digest(originals[name]) != expected:
            raise ValueError(f"Unrecognized upstream file; no patch applied: {name}")
    additions = {name: (overlay / name).read_bytes() for name in
                 ("MenuControl.pas", "MenuForm.pas", "MenuForm.dfm")}
    main = originals["Main.pas"].decode("utf-8-sig").replace("\r\n", "\n")
    main = replace_once(main, "    WorkspaceDir : String;", """    EdaMenuEnabled : Boolean;
    EdaMenuTarget : String;
    EdaMenuRevision : String;
    EdaMenuSession : String;
    EdaMenuCounter : Integer;
    EdaMenuOwnsLease : Boolean;
    WorkspaceDir : String;""")
    main = replace_once(main, "SCRIPT_VERSION = '2026.10.14.7';",
                        "SCRIPT_VERSION = '2026.10.14.7.offline-menu2';")
    # Reuse upstream's BOM-aware, sharing-safe reader for Unicode pointer paths.
    # Move the resolver below ReadFileContent: DelphiScript has no forward declarations.
    resolver_start = main.index("Function ResolveDefaultWorkspaceDir(Dummy : Integer): String;")
    resolver_end = main.index("\nEnd;", resolver_start) + len("\nEnd;")
    resolver = main[resolver_start:resolver_end]
    resolver = replace_once(resolver, "    F : TextFile;\n", "")
    resolver = replace_once(resolver, """            AssignFile(F, PointerFile);
            Reset(F);
            Try
                If Not Eof(F) Then
                    ReadLn(F, Line);
            Finally
                CloseFile(F);
            End;""", "            Line := ReadFileContent(PointerFile);")
    main = main[:resolver_start] + main[resolver_end:]
    anchor = "Procedure WriteFileContent(FilePath : String; Content : String);"
    main = replace_once(main, anchor, resolver + "\n\n" + anchor)
    main = '{ Modified by EdaAgentOfflineSetup: guarded menu state, 2026-10-16. }\n' + main
    status = originals["StatusForm.pas"].decode("utf-8-sig").replace("\r\n", "\n")
    anchor = "Function ProcessCommand(Command : String; Params : String; RequestId : String) : String;"
    status = replace_once(status, anchor, additions["MenuControl.pas"].decode("utf-8-sig") + "\n" + anchor)
    status = replace_once(status, "    Category, Action : String;", "    Category, Action, GuardError : String;")
    status = replace_once(status, "    DotPos := Pos('.', Command);", """    GuardError := EdaMenuGuard(Command, Params, RequestId);
    If GuardError <> '' Then Begin Result := GuardError; Exit; End;
    If Pos('eda_menu.', Command) = 1 Then
    Begin Result := EdaMenuCommand(Command, Params, RequestId); Exit; End;
    DotPos := Pos('.', Command);""")
    status = replace_once(status, "    LoadMCPConfig(0);", "    LoadMCPConfig(0);\n    If Not EdaMenuAcquire(0) Then Exit;")
    status = replace_once(status, "    Running := True;", "    Running := True;\n    If EdaMenuEnabled Then EdaMenuPublish(0);")
    status = replace_once(status, "    If PumpQuitting Then Exit;", "    If PumpQuitting Then Begin EdaMenuRelease(0); Exit; End;")
    status = replace_once(status, "    HideStatusForm(0);\nEnd;", "    HideStatusForm(0);\n    EdaMenuRelease(0);\nEnd;")
    status = '{ Modified by EdaAgentOfflineSetup: local menu dispatch and lifecycle, 2026-10-16. }\n' + status
    project = originals["Altium_API.PrjScr"].decode("utf-8-sig").replace("\r\n", "\n")
    project = replace_once(project, "[Document1]\n", """[Document14]
DocumentPath=MenuForm.pas

[Document15]
DocumentPath=MenuForm.dfm

[Document1]
""")
    outputs = {"Main.pas": main.encode("utf-8"), "StatusForm.pas": status.encode("utf-8"),
               "Altium_API.PrjScr": project.encode("utf-8"),
               "MenuForm.pas": additions["MenuForm.pas"], "MenuForm.dfm": additions["MenuForm.dfm"]}
    manifest = {
        "schemaVersion": 1, "sourceCommit": commit,
        "patcherSha256": digest(Path(__file__).read_bytes()),
        "overlaySha256": {n: digest(b) for n, b in additions.items()},
        "originalSha256": ORIGINALS,
        "patchedSha256": {n: digest(b) for n, b in outputs.items()},
    }
    # All anchors and input hashes are checked before the first write.
    for name, data in outputs.items():
        (scripts / name).write_bytes(data)
    (scripts / "offline-menu-patch.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def verify(scripts, overlay):
    scripts, overlay = Path(scripts), Path(overlay)
    manifest = json.loads((scripts / "offline-menu-patch.json").read_text(encoding="utf-8"))
    if manifest["sourceCommit"] != PINNED_COMMIT or manifest["patcherSha256"] != digest(Path(__file__).read_bytes()):
        raise ValueError("Stale Altium menu patch; rebuild the bundle.")
    for name, expected in manifest["overlaySha256"].items():
        if digest((overlay / name).read_bytes()) != expected:
            raise ValueError(f"Stale Altium menu overlay: {name}")
    for name, expected in manifest["patchedSha256"].items():
        if digest((scripts / name).read_bytes()) != expected:
            raise ValueError(f"Modified Altium menu script: {name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scripts", type=Path)
    parser.add_argument("--overlay", type=Path, default=Path(__file__).with_name("altium"))
    parser.add_argument("--source-commit", default=PINNED_COMMIT)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.verify:
        verify(args.scripts, args.overlay)
    else:
        apply(args.scripts, args.overlay, args.source_commit)
