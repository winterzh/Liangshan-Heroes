#!/usr/bin/env python3
"""Pure-logic checks for Steam Cloud campaign merge and presence text."""
from __future__ import annotations

import json
import sys
from typing import Any

FAILURES: list[str] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    if ok:
        print(f"PASS {name}")
    else:
        print(f"FAIL {name} {detail}".rstrip())
        FAILURES.append(name)


def normalize_record(raw: Any) -> dict:
    out = {
        "cleared": False,
        "story_complete": False,
        "best_done": 0,
        "story_total": 0,
        "best_goal_ids": [],
        "contract_version": 1,
    }
    if not isinstance(raw, dict):
        return out
    out["cleared"] = bool(raw.get("cleared", False))
    out["story_complete"] = bool(raw.get("story_complete", False))
    out["best_done"] = max(0, int(raw.get("best_done", 0)))
    out["story_total"] = max(out["best_done"], int(raw.get("story_total", 0)))
    ids: list[str] = []
    for item in raw.get("best_goal_ids", []):
        goal_id = str(item).strip()
        if goal_id and goal_id not in ids:
            ids.append(goal_id)
    out["best_goal_ids"] = ids
    out["contract_version"] = max(1, int(raw.get("contract_version", 1)))
    return out


def better_record(left: dict, right: dict) -> dict:
    out = dict(left)
    out["cleared"] = bool(left.get("cleared")) or bool(right.get("cleared"))
    out["story_complete"] = bool(left.get("story_complete")) or bool(right.get("story_complete"))
    out["contract_version"] = max(int(left.get("contract_version", 1)), int(right.get("contract_version", 1)))
    left_done = int(left.get("best_done", 0))
    right_done = int(right.get("best_done", 0))
    if (
        right_done > left_done
        or (int(left.get("story_total", 0)) == 0 and int(right.get("story_total", 0)) > 0)
        or (bool(right.get("story_complete")) and not bool(left.get("story_complete")) and right_done >= left_done)
    ):
        out["best_done"] = right_done
        out["story_total"] = int(right.get("story_total", 0))
        out["best_goal_ids"] = list(right.get("best_goal_ids", []))
    return out


def merged_campaign(a: dict, b: dict) -> dict:
    unlocked = max(int(a.get("unlocked", 1)), int(b.get("unlocked", 1)))
    records: dict[str, dict] = {}
    for source in (a.get("records", {}), b.get("records", {})):
        if not isinstance(source, dict):
            continue
        for level_id, raw in source.items():
            incoming = normalize_record(raw)
            if level_id in records:
                records[level_id] = better_record(records[level_id], incoming)
            else:
                records[level_id] = incoming
    return {"schema": 2, "unlocked": unlocked, "records": records}


def presence_status(locale: str, mode: str, level_title: str, wave: int, wave_total: int, paused: bool) -> str:
    table = {
        "menu": {"zh_CN": "主菜单", "zh_TW": "主選單", "en": "Main menu", "ja": "メインメニュー"},
        "campaign": {"zh_CN": "正在 %s", "zh_TW": "正在 %s", "en": "Playing %s", "ja": "%s をプレイ中"},
        "defense_all": {"zh_CN": "据守梁山 · 第 %d/%d 波", "zh_TW": "據守梁山 · 第 %d/%d 波", "en": "Defending Liangshan · Wave %d/%d", "ja": "梁山を防衛中 · 第 %d/%d 波"},
        "paused": {"zh_CN": "已暂停", "zh_TW": "已暫停", "en": "Paused", "ja": "一時停止"},
    }
    if mode == "menu":
        body = table["menu"][locale]
    elif mode == "campaign":
        body = table["campaign"][locale] % level_title if level_title else "campaign"
    elif mode == "defense":
        body = table["defense_all"][locale] % (wave, wave_total)
    else:
        body = mode
    if paused:
        return table["paused"][locale] + " · " + body
    return body


def main() -> int:
    left = normalize_record({"cleared": True, "story_complete": False, "best_done": 1, "story_total": 3, "best_goal_ids": ["a"], "contract_version": 1})
    right = normalize_record({"cleared": False, "story_complete": False, "best_done": 3, "story_total": 3, "best_goal_ids": ["a", "b", "c"], "contract_version": 1})
    merged = better_record(left, right)
    check("best_single_run_wins", merged["best_done"] == 3 and merged["best_goal_ids"] == ["a", "b", "c"])
    check("cleared_union", merged["cleared"] is True)

    sealed = better_record(
        normalize_record({"cleared": True, "story_complete": False, "best_done": 2, "story_total": 2, "best_goal_ids": ["x", "y"]}),
        normalize_record({"cleared": True, "story_complete": True, "best_done": 2, "story_total": 2, "best_goal_ids": ["x", "y"]}),
    )
    check("story_complete_union", sealed["story_complete"] is True)
    check("no_cross_run_goal_union", sealed["best_goal_ids"] in (["x", "y"], ["a", "b", "c"]))

    campaign = merged_campaign(
        {"unlocked": 3, "records": {"level1": left}},
        {"unlocked": 5, "records": {"level1": right, "level2": {"cleared": True}}},
    )
    check("unlocked_max", campaign["unlocked"] == 5)
    check("records_present", set(campaign["records"]) == {"level1", "level2"})
    check("level2_cleared", campaign["records"]["level2"]["cleared"] is True)

    check(
        "presence_campaign_zh",
        presence_status("zh_CN", "campaign", "三打祝家庄", 0, 0, False) == "正在 三打祝家庄",
    )
    check(
        "presence_defense_wave_en",
        presence_status("en", "defense", "", 18, 30, False) == "Defending Liangshan · Wave 18/30",
    )
    check(
        "presence_paused_ja",
        presence_status("ja", "menu", "", 0, 0, True) == "一時停止 · メインメニュー",
    )

    payload = {
        "schema": 1,
        "owner": "111",
        "updated_at": 1,
        "campaign": campaign,
        "settings_text": "[audio]\nbgm=0.5\n",
        "language_text": "[language]\nlocale=\"zh_CN\"\n",
    }
    decoded = json.loads(json.dumps(payload, ensure_ascii=False))
    check("payload_roundtrip", decoded["owner"] == "111" and decoded["campaign"]["unlocked"] == 5)

    if FAILURES:
        print(f"FAILED {len(FAILURES)}")
        return 1
    print("ALL PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
