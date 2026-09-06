"""Install only pinned Windows runtime files; ordinary Godot imports ignore vendor/."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
URL = "https://codeberg.org/godotsteam/godotsteam/releases/download/v4.22.1-gde/godotsteam-4.22.1-gdextension-plugin-4.4.zip"
SHA256 = "2b12b3499434c50da16104a0d22b725aee15cc5cd41223c1cea825bae59bfa8f"
FILES = ["win64/libgodotsteam.windows.template_release.x86_64.dll", "win64/libgodotsteam.windows.template_debug.x86_64.dll", "win64/steam_api64.dll", "license.md", "readme.md"]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    archive = args.archive or ROOT / ".godot/steam_dependency/godotsteam.zip"
    if not archive.exists():
        archive.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(URL, archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise SystemExit("Dependency archive hash mismatch")
    target = ROOT / "vendor/godotsteam"
    target.mkdir(parents=True, exist_ok=True)
    (target / ".gdignore").write_text("", encoding="utf-8")
    records = []
    with zipfile.ZipFile(archive) as z:
        for relative in FILES:
            content = z.read("addons/godotsteam/" + relative)
            path = target / relative
            if path.exists() and path.read_bytes() != content:
                raise SystemExit("Refusing to overwrite modified dependency: " + str(path))
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
            records.append({"path":relative,"bytes":len(content),"sha256":hashlib.sha256(content).hexdigest()})
    manifest = {"godotsteam":"4.22.1", "steamworks":"1.65", "godot_minimum":"4.4", "archive_url":URL, "archive_sha256":SHA256, "files":records}
    (target / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"installed":len(records), "archive_sha256":SHA256}))

if __name__ == "__main__":
    main()
