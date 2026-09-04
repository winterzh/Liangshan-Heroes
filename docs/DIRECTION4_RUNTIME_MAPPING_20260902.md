# 四向动作运行时映射补充（2026-09-02）

本批只修运行时动作选择和武器类型，不接入新的生产位图。

- 通用单位在受击位移有效时会查询 `assets/anim/<key>_hurt_<se|sw|ne|nw>.png`。精确 hurt 不存在时，仍沿用 `Art.unit_anim_frames` 的原回退顺序：同方向 idle、旧无方向 hurt、之后由 Unit 继续正常动作选择。
- 通用 `wu_song` 明确使用刀类攻击表现；`wu_song_mengzhou` 和 `jiang_menshen_fists` 仍由战役 variant 明确使用拳脚，不改变快活林造型或技能。
- `lian_huan_ma` 明确使用枪类攻击表现，避免按短射程误判为刀。

`down` 与 `death` 保持两个独立的通用状态，不做隐式互转。剧情人物被制服、昏迷或被擒时读取 `<key>_down_<direction>.png`；真正死亡读取 `<key>_death_<direction>.png`。若同一张无血倒地源图获准同时服务两个状态，集成工具必须从同一个已登记源矩形分别产出两套文件，并分别记录输出哈希；不能只把清单中的 `down` 字段改成 `death`，也不能用运行时别名隐藏缺口。

战役 variant 继续遵循既有 `CampaignArt.animation_path` 规则，本批没有改动其 `death -> down` 兼容行为，也没有修改任何战役 variant 文件。

## 验证与回退

- `tools/direction4_regression_test.gd` 使用运行期临时代理走真实 `Art` 与 `Unit` 入口；四方向通用 hurt 均命中精确文件并标记为不可镜像，普通武松为刀、孟州武松为拳、连环马为枪，164个可移动定义的四向更新及既有攻击/施法锁向继续通过。测试结束后临时 `assets/anim/qa_direction4*` 文件和 `.import` 均已清除。
- `tools/campaign_art_contract.gd` 另跑 111 项，确认孟州武松五动作四方向、头像及战役 variant 隔离继续通过。
- `assets/anim` 与 `assets/direction4` 的生产树快照在改动后仍为 `12aeee091ad874c2236ad3094a0af5d416293739273313648890c72a7b5f3c77`，与首批候选接入前的冻结值相同。
- 改前源码和测试夹具备份位于 `C:/Users/rsb/Desktop/AI项目/水浒/implementation_20260902/pre_direction_runtime_mapping_20260902_112404/`，其中 `baseline_sha256.json` 记录逐文件哈希。回退时恢复 `scripts/unit.gd` 与 `tools/direction4_regression_test.gd`，删除本批新增的四张 `qa_direction4_hurt_<direction>.png` 测试夹具及本文档即可；生产素材无须回退。
