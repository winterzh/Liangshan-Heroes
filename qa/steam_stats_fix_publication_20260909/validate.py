from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re

QA = Path(__file__).resolve().parent
ROOT = QA.parents[1]
def read(path):
    return json.loads(path.read_text(encoding="utf-8"))
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
copy = read(ROOT / "marketing/steam_stats_fix_20260908/copy.json")
observed = read(QA / "public_rendered.json")
receipt = read(QA / "publication_receipt.json")
checks = []
def check(name, ok):
    checks.append({"name": name, "passed": bool(ok)})
check("exactly_four_languages", set(observed["languages"]) == set(copy) == {"schinese", "tchinese", "english", "japanese"})
for lang, item in copy.items():
    body = [line.strip() for line in re.sub(r"\[/?(?:h2|list)\]|\[\*\]", "", item["body_bbcode"]).splitlines() if line.strip()]
    expected = [item["title"], item["subtitle"]] + body
    actual = observed["languages"][lang]["lines"]
    check(lang + "_nine_segments", len(expected) == len(actual) == 9)
    for i, value in enumerate(expected):
        check(lang + "_ordered_segment_" + str(i + 1), i < len(actual) and actual[i] == value)
    check(lang + "_public_url", observed["languages"][lang]["url"] == receipt["announcement"]["public_url"] + "?l=" + lang)
check("copy_sha256", sha(ROOT / receipt["announcement"]["copy_path"]) == receipt["announcement"]["copy_sha256"])
check("cover_sha256", sha(ROOT / receipt["announcement"]["cover"]["path"]) == receipt["announcement"]["cover"]["sha256"])
check("preflight_sha256", sha(QA / "preflight.json") == "3aa77980ab1678e1f1bd4abc76a4fa3030402f8e39fb6b8ec57a540651dff81e")
check("published_identity", receipt["status"] == "PUBLISHED" and receipt["steam"]["branch"] == "default" and receipt["steam"]["build_id"] == receipt["announcement"]["linked_build_id"] == "25185242")
check("manifest_kept_as_string", receipt["steam"]["manifest_id"] == "1883518997850700800")
check("event_identity", receipt["announcement"]["event_id"] == "708907988310559239")
check("resume_remains_gated", receipt["limits"]["resume_entrypoints_open"] is False)
report = {
    "schema_version": 1,
    "checked_at_utc": datetime.now(timezone.utc).isoformat(),
    "status": "PASS" if all(x["passed"] for x in checks) else "FAIL",
    "scope": "Local evidence integrity and exact four-language rendered-text comparison; not a fresh live server fetch.",
    "checks_passed": sum(x["passed"] for x in checks),
    "checks_total": len(checks),
    "checks": checks,
}
(QA / "validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: report[k] for k in ("status", "checks_passed", "checks_total")}))
raise SystemExit(0 if report["status"] == "PASS" else 1)
