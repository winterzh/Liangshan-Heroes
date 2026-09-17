# -*- coding: utf-8 -*-
"""Build and package the official 6-file Steam Windows release ZIP."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path(r"C:\Users\rsb\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe")
TEMPLATE_APPDATA = Path(r"D:\tools\GodotExportTemplates\user_data")
OUTPUT_DIR = Path(r"D:\CodexTemp\steam_release_20260911")

VENDOR_FILES = [
    (ROOT / "vendor/godotsteam/win64/steam_api64.dll", "steam_api64.dll"),
    (ROOT / "vendor/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll", "libgodotsteam.windows.template_release.x86_64.dll"),
    (ROOT / "vendor/steam_stats_reader/win64/steam_stats_reader.dll", "steam_stats_reader.dll"),
    (ROOT / "vendor/godotsteam/license.md", "GODOTSTEAM_LICENSE.txt"),
    (ROOT / "vendor/steam_stats_reader/GODOT_CPP_LICENSE.md", "STEAM_STATS_READER_GODOT_CPP_LICENSE.txt"),
]

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()

def sha1_file(path: Path) -> str:
    h = hashlib.sha1()
    with path.open("rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()

def main():
    print(f"[1/5] Preparing output directory: {OUTPUT_DIR}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    content_dir = OUTPUT_DIR / "content"
    if content_dir.exists():
        shutil.rmtree(content_dir)
    content_dir.mkdir(parents=True, exist_ok=True)

    exe_path = content_dir / "LiangshanHeroes.exe"
    print(f"[2/5] Exporting Godot release binary with preset 'Windows Steam' to {exe_path}...")
    env = os.environ.copy()
    env["APPDATA"] = str(TEMPLATE_APPDATA)
    
    cmd = [
        str(ENGINE),
        "--headless",
        "--path", str(ROOT),
        "--export-release", "Windows Steam",
        str(exe_path)
    ]
    res = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if res.returncode != 0 or not exe_path.exists():
        print(f"Export failed with code {res.returncode}:\n{res.stdout}\n{res.stderr}")
        sys.exit(1)
    print(f"Export successful. EXE size: {exe_path.stat().st_size:,} bytes.")

    print(f"[3/5] Copying vendor runtime libraries and licenses...")
    for src, dst_name in VENDOR_FILES:
        dst = content_dir / dst_name
        shutil.copyfile(src, dst)
        print(f"  + {dst_name} ({dst.stat().st_size:,} bytes)")

    print(f"[4/5] Running pre-package smoke test on LiangshanHeroes.exe...")
    smoke_env = os.environ.copy()
    smoke_env["APPDATA"] = str(OUTPUT_DIR / "smoke_profile/appdata")
    smoke_env["LOCALAPPDATA"] = str(OUTPUT_DIR / "smoke_profile/localappdata")
    smoke_env["TEMP"] = str(OUTPUT_DIR / "smoke_profile/temp")
    smoke_env["TMP"] = str(OUTPUT_DIR / "smoke_profile/temp")
    smoke_env["STEAM_DISABLED"] = "1"
    smoke_env["SMOKE_TEST"] = "1"
    for k in ["smoke_profile/appdata", "smoke_profile/localappdata", "smoke_profile/temp"]:
        (OUTPUT_DIR / k).mkdir(parents=True, exist_ok=True)

    smoke_cmd = [
        str(exe_path),
        "--headless",
        "--max-fps", "60",
        "--quit-after", "60"
    ]
    smoke_res = subprocess.run(smoke_cmd, cwd=str(content_dir), env=smoke_env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
    print(f"Smoke test exit code: {smoke_res.returncode}")
    if smoke_res.returncode != 0:
        print(f"Smoke test stdout: {smoke_res.stdout}")
        print(f"Smoke test stderr: {smoke_res.stderr}")
        sys.exit(1)

    print(f"[5/5] Creating Steam distribution ZIP archive...")
    zip_path = OUTPUT_DIR / "LiangshanHeroes_Steam_build_20260911.zip"
    if zip_path.exists():
        zip_path.unlink()

    files_info = []
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for file in sorted(content_dir.iterdir()):
            if file.is_file():
                zf.write(file, arcname=file.name)
                files_info.append({
                    "name": file.name,
                    "bytes": file.stat().st_size,
                    "sha256": sha256_file(file),
                    "sha1": sha1_file(file)
                })

    receipt = {
        "zip_path": str(zip_path),
        "zip_bytes": zip_path.stat().st_size,
        "zip_sha256": sha256_file(zip_path),
        "files_count": len(files_info),
        "files": files_info
    }
    receipt_file = OUTPUT_DIR / "build_receipt.json"
    with receipt_file.open("w", encoding="utf-8") as f:
        json.dump(receipt, f, indent=2, ensure_ascii=False)

    print("\n==========================================")
    print("STEAM RELEASE BUILD COMPLETE")
    print("==========================================")
    print(f"ZIP Archive : {zip_path}")
    print(f"ZIP Size    : {zip_path.stat().st_size:,} bytes")
    print(f"ZIP SHA256  : {receipt['zip_sha256']}")
    print("\nArchived files (6 items):")
    for f in files_info:
        print(f" - {f['name']:50s} {f['bytes']:>12,} bytes  (SHA1: {f['sha1']})")
    print(f"\nBuild receipt written to {receipt_file}")

if __name__ == "__main__":
    main()
