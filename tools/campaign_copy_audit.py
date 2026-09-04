#!/usr/bin/env python3
"""Static campaign-copy audit. This script never launches Godot."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIT_DIR = ROOT / "qa" / "campaign_copy_audit_20260902"
BEFORE_DIR = AUDIT_DIR / "before"
REPORT_PATH = AUDIT_DIR / "report.json"
COPY_RESULT_SNAPSHOT_DIR = (
    ROOT.parent / "implementation_20260902" / "pre_environment_consumers_20260902_045453"
)
COPY_RESULT_SNAPSHOT_MANIFEST = COPY_RESULT_SNAPSHOT_DIR / "sha256.json"
COPY_RESULT_SNAPSHOT_HASHES = {
    "scripts/levels/level3_zhujiazhuang.gd": "bc0d5ca62f152c94950b593850d737695bbb11c0e032c56bcd631c726877a180",
    "scripts/levels/level7_kuaihuolin.gd": "e30278b005038d20da7327c83c6a5857488b8bf9cb98127852404d002d70e8db",
}
WIKISOURCE_BASE = (
    "https://zh.wikisource.org/zh-hans/"
    "%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/"
)

LEVELS = [
    {
        "id": "level6",
        "title": "野猪林",
        "file": "scripts/levels/level6_yezhulin.gd",
        "chapters": [8, 9],
        "原文明确": [
            "董超、薛霸在野猪林下手；鲁智深以禅杖拦棍、听林冲求情后留二人性命，并以戒刀解缚。",
            "120回本网页分段中，押解与抵达野猪林在第八回，鲁智深出手及继续护送在第九回。",
        ],
        "游戏压缩": ["把十七八日护送和七十里外分别压缩为林中解缚、照料和离场。"],
        "仍不确定": ["不同版本把“大闹野猪林”的回目分界排在第八回或相邻页；本审计按当前120回本网页第八、九回合看。"],
    },
    {
        "id": "level1",
        "title": "智取生辰纲",
        "file": "scripts/levels/level1_huangnigang.gd",
        "chapters": [16],
        "原文明确": [
            "七星扮贩枣客，白胜单独卖酒；吴用借瓢下药，白胜夺瓢遮掩。",
            "押送一行药倒后，七星搬走十一担金珠宝贝，不以杀尽押送者取胜。",
        ],
        "游戏压缩": ["十一担缩成三担，七辆枣车及十五名押送者缩为代表性单位。"],
        "仍不确定": [],
    },
    {
        "id": "level7",
        "title": "醉打蒋门神",
        "file": "scripts/levels/level7_kuaihuolin.gd",
        "chapters": [29, 30],
        "原文明确": [
            "“河阳风月”写在酒望上，不是酒店正式店名。",
            "蒋门神原在绿槐树下，酒保报信后赶来，与武松在大路相迎；他并非从店内出来。",
            "三项条件为交还家当、请众人向施恩赔话、离开快活林并回乡。",
        ],
        "游戏压缩": ["原文沿路十来处酒店，本关用四处三碗表现“无三不过望”。"],
        "仍不确定": [],
    },
    {
        "id": "level2",
        "title": "江州劫法场",
        "file": "scripts/levels/level2_jiangzhou.gd",
        "chapters": [40],
        "原文明确": [
            "梁山四路人马依锣声动手，李逵随后从茶坊跳下，先杀刽子手。",
            "宋江、戴宗被救后经白龙庙与江上好汉会合，必须活着脱险。",
        ],
        "游戏压缩": ["四路乔装与白龙庙后大队水路追逃缩成少量具名单位和登船交互。"],
        "仍不确定": ["“李逵先动手”在本关解释为先扑刽子手的演义目标，不解释为梁山四路在他之前完全未动。"],
    },
    {
        "id": "level3",
        "title": "三打祝家庄",
        "file": "scripts/levels/level3_zhujiazhuang.gd",
        "chapters": [47, 48, 49, 50],
        "原文明确": [
            "林冲阵前生擒扈三娘，随后连夜送交宋太公看管，扈三娘不当场反戈。",
            "孙立把旗号改作“登州兵马提辖孙立”；孙新在门楼插原带旗号；邹渊、邹润开陷车救七人。",
            "孙立守吊桥接应，顾大嫂另在堂前等信号，她不是开陷车或换旗的人。",
        ],
        "游戏压缩": [
            "第三打数日部署缩为一次转场。",
            "现有交互仍以顾大嫂的任务动作代理救囚、以孙立守桥触发开门；玩家文字明确顾大嫂在堂前发信号、邹渊邹润守监门开陷车。",
        ],
        "仍不确定": ["“登州兵马提辖孙立”有原文依据，但当前没有祝家庄专用旗面物件，本批只修任务文字，不建立全局姓名旗路由。"],
    },
    {
        "id": "level4",
        "title": "大破连环马",
        "file": "scripts/levels/level4_lianhuanma.gd",
        "chapters": [56, 57],
        "原文明确": [
            "徐宁镇家宝甲全称“雁翎砌就圈金甲”，人称“赛唐猊”。",
            "军士不到半月练熟钩镰枪；韩滔被擒，呼延灼败走后投青州。",
        ],
        "游戏压缩": ["五七百钩镰军与大队连环甲马缩为两路十二骑。"],
        "仍不确定": [],
    },
    {
        "id": "level8",
        "title": "智取大名府",
        "file": "scripts/levels/level8_dongchangfu.gd",
        "chapters": [65, 66],
        "原文明确": [
            "时迁独自越墙入城，元宵夜扮卖闹鹅儿者上翠云楼举火。",
            "柴进、乐和另去蔡福家，由蔡福给旧衣并引入牢中。",
            "火号起后柴进开枷救卢俊义、石秀；城外各路同时响应。",
        ],
        "游戏压缩": ["三名内应同过侧门、衣帽点和核验文书是可玩的潜入压缩，不是原文路线。"],
        "仍不确定": ["当前未部署蔡福为可操作单位；本批只在任务文案中补回其原著作用。"],
    },
    {
        "id": "level5",
        "title": "三败高太尉",
        "file": "scripts/levels/level5_liangshan.gd",
        "chapters": [78, 79, 80],
        "原文明确": [
            "首败为刘梦龙统水军、党世雄监战；再败有牛邦喜、刘梦龙、党世英；三败由高俅亲临。",
            "第八十回先锋头船两面红旗合书十四字；张顺率水军凿船，把高俅抛入水中后生擒。",
            "山寨旗文“替天行道”“山东呼保义”“河北玉麒麟”见第七十一回。",
        ],
        "游戏压缩": ["数百海鳅船、多条火船及水下多人凿船缩为少量战船、单火船和一次任务交互。"],
        "仍不确定": [
            "第八十回另有李俊、张横、张顺具名旗文；当前关卡没有一一对应的专船旗面上下文，未路由。",
            "“梁山泊阮氏三雄”已列入文字白名单，但尚无动态路由，当前不会显示。",
        ],
    },
]

SOURCE_TITLES = {
    8: "林教头刺配沧州道 鲁智深大闹野猪林",
    9: "柴进门招天下客 林冲棒打洪教头",
    16: "杨志押送金银担 吴用智取生辰纲",
    29: "施恩重霸孟州道 武松醉打蒋门神",
    30: "施恩三入死囚牢 武松大闹飞云浦",
    40: "梁山泊好汉劫法场 白龙庙英雄小聚义",
    47: "扑天雕双修生死书 宋公明一打祝家庄",
    48: "一丈青单捉王矮虎 宋公明两打祝家庄",
    49: "解珍解宝双越狱 孙立孙新大劫牢",
    50: "吴学究双掌连环计 宋公明三打祝家庄",
    56: "吴用使时迁盗甲 汤隆赚徐宁上山",
    57: "徐宁教使钩镰枪 宋江大破连环马",
    65: "托塔天王梦中显圣 浪里白条水上报冤",
    66: "时迁火烧翠云楼 吴用智取大名府",
    71: "忠义堂石碣受天文 梁山泊英雄排座次",
    78: "十节度议取梁山泊 宋公明一败高太尉",
    79: "刘唐放火烧战船 宋江两败高太尉",
    80: "张顺凿漏海鳅船 宋江三败高太尉",
}

TOUCHED = [
    "scripts/levels/level7_kuaihuolin.gd",
    "scripts/levels/level3_zhujiazhuang.gd",
    "scripts/levels/level4_lianhuanma.gd",
    "scripts/levels/level8_dongchangfu.gd",
    "scripts/bios.gd",
]

EXPECTED_TEXT = {
    "scripts/levels/level7_kuaihuolin.gd": [
        "到挂着“河阳风月”酒望的店前佯醉换酒，惊动酒保，引蒋门神赶来",
        "武松佯醉换酒寻衅，酒保报信；蒋门神闻报赶来，与武松在大路相迎",
        "蒋门神倒地告饶",
    ],
    "scripts/levels/level3_zhujiazhuang.gd": [
        "孙立把旗号改作“登州兵马提辖孙立”",
        "顾大嫂在堂前发出内应信号",
        "邹渊、邹润开陷车",
        "孙新在门楼插起原带旗号",
        "扈三娘仍以俘将身份看押",
    ],
    "scripts/levels/level4_lianhuanma.gd": [
        "祖传雁翎砌就圈金甲",
        "生擒韩滔",
        "呼延灼骑踢雪乌骓败走青州",
    ],
    "scripts/levels/level8_dongchangfu.gd": [
        "时迁越墙潜入",
        "柴进、乐和由蔡福换装引入牢中",
        "卢俊义与石秀终于脱险",
    ],
    "scripts/bios.gd": [
        "白日鼠。黄泥冈挑酒卖酒，配合吴用下蒙汗药",
        "家传宝甲雁翎砌就圈金甲，人称「赛唐猊」",
        "跳楼劫法场救卢俊义，一身是胆",
    ],
    "scripts/levels/level6_yezhulin.gd": [
        "听林冲求情，留董超、薛霸性命",
        "取戒刀割断绑绳，扶起林冲",
    ],
    "scripts/levels/level1_huangnigang.gd": [
        "七星施计，白胜卖酒。押送人麻倒松阴",
        "三担生辰纲",
    ],
    "scripts/levels/level2_jiangzhou.gd": [
        "宋江、戴宗活着登船",
        "李逵先扑向刽子手",
    ],
    "scripts/levels/level5_liangshan.gd": [
        "刘梦龙为头统制，党世雄率精兵上船监战",
        "牛邦喜与刘梦龙、党世英掌管水路再进",
        "高俅被生擒，送往忠义堂",
    ],
}

FORBIDDEN_TEXT = {
    "scripts/levels/level7_kuaihuolin.gd": ["河阳风月店前", "引蒋门神出店"],
    "scripts/levels/level3_zhujiazhuang.gd": [
        "顾大嫂打开囚车",
        "顾大嫂：打开七辆囚车",
        "顾大嫂到监门",
        "顾大嫂赶到监门",
        "孙立在庄门内换旗开门",
        "孙立换旗开门",
    ],
    "scripts/levels/level4_lianhuanma.gd": ["雁翎圈金甲"],
    "scripts/levels/level8_dongchangfu.gd": ["柴大官人、乐和兄弟，你们换公人衣帽去牢里接应"],
    "scripts/bios.gd": ["白日鼠。黄泥冈挑酒下蒙汗药", "救卢俊义,一身"],
}

FLAG_TEXTS = {
    "gao_flagship_command": "帅",
    "liangshan_hilltop_standard": "替天行道",
    "zhongyi_hall_standard_west": "山东呼保义",
    "zhongyi_hall_standard_east": "河北玉麒麟",
    "official_vanguard_red_pair": "搅海翻江冲巨浪，安邦定国灭洪妖",
    "ruan_three_heroes_lure": "梁山泊阮氏三雄",
}


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8-sig")


def sha256(rel: str) -> str:
    return hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()


def before_path(rel: str) -> Path:
    return BEFORE_DIR / rel.replace("/", "__").replace("\\", "__")


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def quoted_strings_normalized(text: str) -> str:
    return re.sub(r'"(?:\\.|[^"\\])*"', '"__STRING__"', text)


def action_ids(text: str) -> dict[str, list[str]]:
    return {
        "goal_ids": re.findall(r'\{"id"\s*:\s*"([^"]+)"', text),
        "mission_begin_ids": re.findall(r'b\.mission\.begin\("([^"]+)"', text),
        "action_ids": re.findall(r'b\.mission\.add_action\("([^"]+)"', text),
        "stage_values": re.findall(r'\bstage\s*(?:=|==|!=)\s*"([^"]+)"', text),
    }


def line_of(rel: str, needle: str) -> int | None:
    for number, line in enumerate(read(rel).splitlines(), 1):
        if needle in line:
            return number
    return None


def chapter_url(chapter: int) -> str:
    return f"{WIKISOURCE_BASE}%E7%AC%AC{chapter:03d}%E5%9B%9E"


def main() -> int:
    checks: list[dict[str, object]] = []

    def check(name: str, passed: bool, details: object = "") -> None:
        checks.append({"name": name, "passed": bool(passed), "details": details})

    for level in LEVELS:
        check(f"level_file_exists:{level['id']}", (ROOT / level["file"]).is_file(), level["file"])

    for rel, needles in EXPECTED_TEXT.items():
        text = read(rel)
        for needle in needles:
            check(f"expected_copy:{rel}:{needle[:18]}", needle in text, {"line": line_of(rel, needle)})

    for rel, needles in FORBIDDEN_TEXT.items():
        text = read(rel)
        for needle in needles:
            check(f"obsolete_copy_absent:{rel}:{needle}", needle not in text)

    snapshot_manifest_hashes: dict[str, str] = {}
    snapshot_manifest_error = ""
    try:
        manifest_rows = json.loads(COPY_RESULT_SNAPSHOT_MANIFEST.read_text(encoding="utf-8-sig"))
        snapshot_manifest_hashes = {
            Path(str(row["path"])).resolve().as_posix().casefold(): str(row["sha256"])
            for row in manifest_rows
        }
    except (OSError, ValueError, KeyError, TypeError) as exc:
        snapshot_manifest_error = f"{type(exc).__name__}: {exc}"

    before_hashes: dict[str, str] = {}
    copy_result_hashes: dict[str, str] = {}
    after_hashes: dict[str, str] = {}
    for rel in TOUCHED:
        old_path = before_path(rel)
        check(f"before_copy_exists:{rel}", old_path.is_file(), old_path.relative_to(ROOT).as_posix())
        if not old_path.is_file():
            continue
        old = old_path.read_text(encoding="utf-8-sig")
        current = read(rel)
        copy_result_path = ROOT / rel
        snapshot_validation: dict[str, object] = {"source": "current"}
        snapshot_valid = True
        if rel in COPY_RESULT_SNAPSHOT_HASHES:
            copy_result_path = COPY_RESULT_SNAPSHOT_DIR / rel
            expected_hash = COPY_RESULT_SNAPSHOT_HASHES[rel]
            manifest_hash = snapshot_manifest_hashes.get(copy_result_path.resolve().as_posix().casefold())
            actual_hash = file_sha256(copy_result_path) if copy_result_path.is_file() else None
            snapshot_valid = (
                not snapshot_manifest_error
                and copy_result_path.is_file()
                and manifest_hash == expected_hash
                and actual_hash == expected_hash
            )
            snapshot_validation = {
                "source": "pre_environment_consumers_20260902_045453",
                "path": str(copy_result_path),
                "expected_sha256": expected_hash,
                "manifest_sha256": manifest_hash,
                "actual_sha256": actual_hash,
                "manifest_error": snapshot_manifest_error,
            }
        copy_result = copy_result_path.read_text(encoding="utf-8-sig") if copy_result_path.is_file() else ""
        check(
            f"only_string_literals_changed:{rel}",
            snapshot_valid and quoted_strings_normalized(old) == quoted_strings_normalized(copy_result),
            snapshot_validation,
        )
        ids_old = action_ids(old)
        ids_copy_result = action_ids(copy_result)
        ids_current = action_ids(current)
        check(
            f"stable_action_ids_unchanged:{rel}",
            snapshot_valid and ids_old == ids_copy_result == ids_current,
            {
                "copy_result_source": snapshot_validation,
                "old": ids_old,
                "copy_result": ids_copy_result,
                "current": ids_current,
            },
        )
        before_hashes[rel] = file_sha256(old_path)
        if copy_result_path.is_file():
            copy_result_hashes[rel] = file_sha256(copy_result_path)
        after_hashes[rel] = sha256(rel)

    campaign_art = read("scripts/campaign_art.gd")
    flag_start = campaign_art.index("const FLAG_TEXT_SPECS :=")
    route_start = campaign_art.index("const DYNAMIC_FLAG_ROUTES :=")
    static_start = campaign_art.index("const STATIC_FLAG_ROUTES :=")
    flag_block = campaign_art[flag_start:route_start]
    dynamic_block = campaign_art[route_start:static_start]
    for flag_id, flag_text in FLAG_TEXTS.items():
        id_pos = flag_block.find(f'"{flag_id}"')
        text_pos = flag_block.find(f'"text": "{flag_text}"', max(0, id_pos))
        check(f"flag_whitelist_exact:{flag_id}", id_pos >= 0 and text_pos >= id_pos)
    forbidden_flag_values = [text for text in ["梁山好汉", "梁山军", "宋军", "刘梦龙水军"] if f'"text": "{text}"' in flag_block]
    check("forbidden_generic_flag_values_absent", not forbidden_flag_values, forbidden_flag_values)
    check("ordinary_official_warship_has_no_text_route", '"official_warship": {' not in dynamic_block)
    check("ordinary_liangshan_boat_has_no_text_route", '"liangshan_boat": {' not in dynamic_block)
    check("gao_flagship_requires_chapter80_context", '"required_context": "chapter80_gao_flagship"' in dynamic_block)
    check("gao_flagship_uses_text_only_without_local_flag_repaint", '"text_only": true' in flag_block and '"unlettered_masks"' not in flag_block)
    check("vanguard_pair_requires_chapter80_context", '"required_context": "chapter80_vanguard_headship"' in dynamic_block)
    check("ruan_text_whitelisted_but_unrouted", '"ruan_three_heroes_lure"' in flag_block and '"ruan_three_heroes_lure"' not in dynamic_block)

    failed = [item for item in checks if not item["passed"]]
    chapters = sorted({chapter for level in LEVELS for chapter in level["chapters"]} | {71})
    sources = [
        {
            "chapter": chapter,
            "title": SOURCE_TITLES[chapter],
            "url": chapter_url(chapter),
        }
        for chapter in chapters
    ]

    correction_groups = [
        {
            "level": "level7",
            "file": "scripts/levels/level7_kuaihuolin.gd",
            "line": line_of("scripts/levels/level7_kuaihuolin.gd", "到挂着“河阳风月”酒望"),
            "原文明确": "把“河阳风月”恢复为酒望文字，并把蒋门神改为闻报赶来。",
            "source_chapters": [29],
        },
        {
            "level": "level3",
            "file": "scripts/levels/level3_zhujiazhuang.gd",
            "line": line_of("scripts/levels/level3_zhujiazhuang.gd", "邹渊、邹润开陷车"),
            "原文明确": "救囚归邹渊、邹润，门楼换旗归孙新；孙立守吊桥、顾大嫂在内策应。",
            "游戏压缩": "现有顾大嫂与孙立交互仍作为代理触发；玩家文字明确顾大嫂在堂前发信号、邹渊邹润守监门开陷车，不改动作ID或关卡逻辑。",
            "source_chapters": [50],
        },
        {
            "level": "level3",
            "file": "scripts/levels/level3_zhujiazhuang.gd",
            "line": line_of("scripts/levels/level3_zhujiazhuang.gd", "旗号改作“登州兵马提辖孙立”"),
            "原文明确": "采用原文完整旗号“登州兵马提辖孙立”。",
            "source_chapters": [50],
        },
        {
            "level": "level4",
            "file": "scripts/levels/level4_lianhuanma.gd",
            "line": line_of("scripts/levels/level4_lianhuanma.gd", "祖传雁翎砌就圈金甲"),
            "原文明确": "补全宝甲名称“雁翎砌就圈金甲”。",
            "source_chapters": [56],
        },
        {
            "level": "level8",
            "file": "scripts/levels/level8_dongchangfu.gd",
            "line": line_of("scripts/levels/level8_dongchangfu.gd", "原著路线是时迁越墙潜入"),
            "原文明确": "补回时迁越墙、柴进乐和另投蔡福并由其换装引入牢中的分工。",
            "游戏压缩": "同时明示当前关卡把入城路线压缩为三人同过侧门。",
            "source_chapters": [66],
        },
        {
            "level": "level1",
            "file": "scripts/bios.gd",
            "line": line_of("scripts/bios.gd", "白日鼠。黄泥冈挑酒卖酒"),
            "原文明确": "白胜负责挑酒卖酒，吴用借瓢下药。",
            "source_chapters": [16],
        },
        {
            "level": "level4",
            "file": "scripts/bios.gd",
            "line": line_of("scripts/bios.gd", "家传宝甲雁翎砌就圈金甲"),
            "原文明确": "小传同步采用宝甲全称，并把“赛唐猊”写作通称。",
            "source_chapters": [56],
        },
        {
            "level": "level3/level8",
            "file": "scripts/bios.gd",
            "line": line_of("scripts/bios.gd", "跳楼劫法场救卢俊义，一身是胆"),
            "原文明确": "修正石秀小传中的中英文逗号混用。",
            "source_chapters": [66],
        },
    ]

    report = {
        "schema_version": 1,
        "audit_date": "2026-09-02",
        "edition": "维基文库《水浒传》120回本",
        "scope": {
            "levels": [level["id"] for level in LEVELS],
            "areas": ["任务", "对白", "战报", "bios", "旗面白名单"],
            "not_executed": ["Godot", "网页端ChatGPT生图", "战斗数值修改", "地图修改", "结算逻辑修改"],
        },
        "status": "pass_with_documented_compressions" if not failed else "failed",
        "summary": {
            "levels_audited": len(LEVELS),
            "files_with_player_copy_corrections": len(TOUCHED),
            "correction_groups": len(correction_groups),
            "checks_total": len(checks),
            "checks_passed": len(checks) - len(failed),
            "checks_failed": len(failed),
        },
        "结论分类": {
            "原文明确": "只据原文直接改玩家可见称谓、动作归属、旗号和结局。",
            "游戏压缩": "保留现有规模、交互代理和路线压缩，并在玩家文字或本报告中明示。",
            "仍不确定": "没有专用对象或上下文的旗文不接入运行时；版本分回差异与未部署人物不作强改。",
        },
        "levels": LEVELS,
        "corrections": correction_groups,
        "flag_audit": {
            "whitelist": FLAG_TEXTS,
            "dynamic_routes": ["gao_flagship_command", "official_vanguard_red_pair"],
            "static_routes": ["liangshan_hilltop_standard", "zhongyi_hall_standard_west", "zhongyi_hall_standard_east"],
            "explicit_but_unrouted": [
                "梁山泊阮氏三雄",
                "水军头领，混江龙，李俊",
                "水军头领‘船火儿’张横",
                "头领‘浪里白条’张顺",
                "登州兵马提辖孙立",
            ],
            "ordinary_official_ships": "无字；动态旗路由中没有 official_warship。",
            "forbidden_generic_values_found": forbidden_flag_values,
            "note": "“梁山好汉”“梁山军”等词可出现在叙述或身份称谓中；本项只禁止把它们虚构成旗面文字。",
        },
        "sources": sources,
        "hashes": {
            "before": before_hashes,
            "copy_result": copy_result_hashes,
            "current": after_hashes,
        },
        "copy_result_evidence": {
            "purpose": "For level3 and level7, prove the copy-only change against the post-copy/pre-environment snapshot while separately checking current action IDs.",
            "snapshot_directory": str(COPY_RESULT_SNAPSHOT_DIR),
            "snapshot_manifest": str(COPY_RESULT_SNAPSHOT_MANIFEST),
            "pinned_snapshot_hashes": COPY_RESULT_SNAPSHOT_HASHES,
            "snapshot_manifest_error": snapshot_manifest_error,
        },
        "static_checks": checks,
        "failed_checks": failed,
        "verification": {
            "command": "py -3 -X utf8 -B tools/campaign_copy_audit.py",
            "godot_run": False,
        },
    }

    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], ensure_ascii=False))
    if failed:
        for item in failed:
            print(f"FAIL {item['name']}: {item['details']}", file=sys.stderr)
        return 1
    print(f"PASS report={REPORT_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
