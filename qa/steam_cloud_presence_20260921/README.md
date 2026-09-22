# Steam 云存档与好友状态 QA（2026-09-21）

> 2026-09-22 审查纠正：本历史批次的 11 项只运行 Python 重写逻辑，没有加载生产 GDScript，也未实际使用新增的 Steam fake。不能据此认定云存档、账号隔离或好友状态已验收。实际脚本发现并修复的编译、SDK 合约及存档安全问题见 [新 QA](../steam_cloud_safety_20260922/README.md)。以下保留当时记录；同名 Python 入口现已替换为真实 Godot 隔离测试。

## 范围

- 合并规则：通关/演义印并集、单局最优目标集、禁止跨局拼接演义印。
- 好友状态四语：主菜单、战役关卡、据守波次、暂停。
- payload 往返序列化。
- 代码接入：`scripts/steam_cloud.gd`、`scripts/steam_presence.gd`，SteamService 初始化后挂接；Campaign/Settings 保存后 `mark_dirty`；战斗开局/暂停/结算/回菜单更新 Presence。

## 结果

`python -X utf8 -B tools/run_steam_cloud_presence_qa.py` → **11/11 PASS**。

| 用例 | 结果 |
|---|---|
| best_single_run_wins | PASS |
| cleared_union | PASS |
| story_complete_union | PASS |
| no_cross_run_goal_union | PASS |
| unlocked_max | PASS |
| records_present | PASS |
| level2_cleared | PASS |
| presence_campaign_zh | PASS |
| presence_defense_wave_en | PASS |
| presence_paused_ja | PASS |
| payload_roundtrip | PASS |

## 未完成 / 不在本批

- 真实 Steam 客户端双账号云读写、离线回连、换电脑读取。
- Steamworks `#Status` 四语 Localization 映射（可选后台项）。
- 战斗中途续玩档云同步（等续玩功能完成后接）。
- 工坊正式开放、排行榜、Steam Input、集换式卡牌。
- 成就真实解锁/退出重开/离线回连验收仍开放。

## 复现

```powershell
python -X utf8 -B tools/run_steam_cloud_presence_qa.py
```
