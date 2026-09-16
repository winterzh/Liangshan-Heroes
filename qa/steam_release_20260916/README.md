# Steam 角色动作与场景美术更新发布准备（2026-09-16）

目标 App5088120 / Windows Depot5088121 / default。固定生产来源 `c08c14635a5a5db99d923ff6b5ec1a8fb3ff37c9`。本目录只记录本地候选准备与四语公告文案；Steam 上传、default 切换和公告公开需用户在 Steamworks 后台完成。

## 本次内容

- 祝朝奉、陆谦补齐四向待机/行走/攻击/受击/死亡动画，并匹配头像。
- 官军精骑、弓手、刀盾兵新增受击动作；投石车、撞车新增攻击动作。
- 晁盖、鲁智深、武松、公孙胜统一独立头像。
- 梁山水泊蒲苇、树木与黄泥冈松林统一场景风格。
- 修复快活林酒望在 Unit 绘制路径中的白色方块显示异常。

本轮不修改玩法数值、镜头、存档、导出预设或 macOS depot。

## 本地验证

| 检查 | 结果 |
| --- | ---: |
| 原生 Steam 整合 QA | 185 |
| 候选包内检查 | 1128 |
| 来源/内容身份探针 | 10 + 10 |
| 实际 EXE 短测 | 11 |

- 候选：`.godot/steam_candidates/20260916_090547_b0bcf4b4`
- smoke：`qa/steam_release_20260916/smoke_20260916_091102_94730228`
- 证据归档：`candidate_delivery.json`、`evidence_copy_manifest.json`
- 上传副本：`D:/CodexTemp/steam_release_20260916/upload/LiangshanHeroes_Steam_candidate.zip`

候选 ZIP SHA256 `32ca92f250ba3aeb1a52fdfa2af22dd0cfe898340f6f181bc8034dc5c6a00871`，六个成员：主 EXE、GodotSteam DLL、steam_api64.dll、steam_stats_reader.dll 和两份许可证。

## 公告文案

四语文案见 `announcement_notes_20260916.json`。拟定标题（简中）“角色动作与场景美术更新｜附本次原画”。

原画展示候选（待上传 Steam 后回填 `{STEAM_CLAN_IMAGE}`）：

1. 核心人物头像 `assets/characters/art_full_20260916/liangshan_core_portraits_source_20260916.png`
2. 祝朝奉攻击动作 `assets/characters/art_full_20260915/zhu_zhaofeng_attack_direction4_source.png`
3. 陆谦受击动作 `assets/characters/art_full_20260916/lu_qian_hurt_direction4_source.png`

## Steamworks 待办

1. 上传候选 ZIP（App5088120 / Depot5088121）。
2. 核对服务器六成员名称、字节数与 SHA1。
3. 将新 Build 切换到 default，完成手机验证器确认。
4. 发布四语公告，回读各语言标题与正文。

本批不验收完整战役通关、真人无攻略趣味、长时间性能或客户端下载；这些仍是独立门槛。
