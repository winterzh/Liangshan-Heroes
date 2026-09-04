"""Read-only source/art verification; write a separate web-batch evidence index."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa/web_chatgpt_art_20260831"
ART = ROOT / "assets/campaign"


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(name: str, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--huangnigang-dir", required=True)
    parser.add_argument("--daming-dir", required=True)
    args = parser.parse_args()
    checks = []

    def check(name: str, passed: bool, detail=None):
        checks.append({"name": name, "passed": bool(passed), "detail": detail})

    old_root = ROOT.parent / "_archive" / "campaign_history" / "campaign_rework_20260831_173850"
    baseline = read(old_root / "baseline_manifest.json")
    backup_bad = []
    original_missing = []
    original_assets_changed = []
    original_code_changed = []
    asset_count = 0
    for row in baseline:
        rel = Path(row["path"])
        expected = row["sha256"].lower()
        saved, current = old_root / "baseline" / rel, ROOT / rel
        if not saved.is_file() or sha(saved) != expected: backup_bad.append(row["path"])
        if not current.is_file(): original_missing.append(row["path"])
        elif str(rel).startswith("assets"):
            asset_count += 1
            if sha(current) != expected: original_assets_changed.append(row["path"])
        elif sha(current) != expected: original_code_changed.append(row["path"])
    check("all baseline backups intact", len(baseline) == 1025 and not backup_bad, backup_bad)
    check("original files remain present", not original_missing, original_missing)
    check("original 865 art files unchanged", asset_count == 865 and not original_assets_changed, original_assets_changed)
    legacy = read(ART / "web_art_legacy_baseline.json")["sha256"]
    legacy_bad = [p for p, h in legacy.items() if not (ART / p).is_file() or sha(ART / p) != h]
    check("232 prior campaign outputs/evidence unchanged", len(legacy) == 232 and not legacy_bad, legacy_bad)
    main_report = read(OUT / "final_regression/report.json")
    runtime = main_report["runtime"]
    drift = [p for p, h in runtime.items() if not (ROOT / p).is_file() or sha(ROOT / p) != h]
    check("runtime still matches final regression", main_report["passed"] and not drift, drift)
    write("runtime_manifest.json", [{"path": p, "sha256": h} for p, h in runtime.items()])

    manifest = read(ART / "web_art_manifest.json")
    source_results = []
    for key, source in manifest["sources"].items():
        valid = sha(ART / source["file"]) == source["sha256"]
        prompt_hash = sha(ART / source["prompt_file"])
        recorded_prompt_hash = source.get("prompt_sha256")
        if recorded_prompt_hash:
            valid &= prompt_hash == recorded_prompt_hash
        else:
            # Two rejected drafts retained only a prompt path; do not invent a
            # historical hash or treat the current hash as contemporaneous proof.
            valid &= source["status"] == "rejected"
        url = source["conversation_url"]
        valid &= url.startswith("https://chatgpt.com/c/") and "?" not in url
        source_results.append({"source": key, "passed": valid, "status": source["status"],
                               "prompt_sha256_current": prompt_hash,
                               "historical_prompt_hash_present": recorded_prompt_hash is not None})
    check("16 source hashes and all accepted-source prompt hashes verified", len(source_results) == 16 and all(r["passed"] for r in source_results), source_results)
    strips = sorted((ART / "anim").glob("*.png"))
    frame_count = 0
    for strip in strips:
        with Image.open(strip) as image:
            if image.width % image.height: raise ValueError(f"non-square frame strip {strip}")
            frame_count += image.width // image.height
    inventory = {"strips": len(strips), "frames": frame_count,
                 "objects": len(list((ART / "objects").glob("*.png"))),
                 "portraits": len(list((ART / "portraits").glob("*.png")))}
    check("physical inventory", inventory == {"strips": 300, "frames": 468, "objects": 23, "portraits": 36}, inventory)

    evidence_specs = [
        ("final existing regression", OUT / "final_regression/report.json", "automated gameplay/contracts"),
        ("web pixel contract", ART / "web_art_contract_qa.json", "read-only pixels/provenance"),
        ("normal recruitment", OUT / "roster_training/report.json", "real queues and rejection fixtures"),
        ("Huangnigang wiring", OUT / "huangnigang_wiring.json", "headless gameplay plus declared isolated fixtures"),
        ("Huangnigang visuals", Path(args.huangnigang_dir) / "report.json", "real events plus explicitly labeled movement/occlusion fixtures"),
        ("Daming visuals", Path(args.daming_dir) / "report.json", "real rescue, ordinary recruitment, restart"),
        ("town crowd visuals", OUT / "crowd_visual_size50/report.json", "static scene/crowd composition, not playthrough"),
    ]
    evidence = []
    for name, path, scope in evidence_specs:
        if not path.is_absolute(): path = ROOT / path
        report = read(path)
        check(name, report.get("passed") is True)
        images = sorted(path.parent.glob("*.png")) if "visual" in name else []
        evidence.append({"name": name, "path": path.relative_to(ROOT).as_posix(), "sha256": sha(path), "scope": scope,
                         "screenshots": [{"path": p.relative_to(ROOT).as_posix(), "sha256": sha(p)} for p in images]})
    passed = all(row["passed"] for row in checks)
    index = {"passed": passed, "checks": checks, "inventory": inventory, "baseline_count": len(baseline),
             "original_changed_non_art_files": original_code_changed, "runtime_file_count": len(runtime),
             "evidence": evidence, "not_proven": ["15-25 minute chapter content", "complete four-frame gait",
                 "all art finalized", "long-session performance/memory", "human playtest acceptance"],
             "boundary": "Local source and art only. No Steam export/upload/release. This audit adds no gameplay run."}
    write("verification_index.json", index)
    print(json.dumps({"passed": passed, "checks": len(checks), "inventory": inventory,
                      "failed": [row["name"] for row in checks if not row["passed"]]}, ensure_ascii=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
