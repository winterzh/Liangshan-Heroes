# 战役终态与快活林起手姿态隔离

日期：2026-09-02。

本批只修两处运行时接线，不修改任何 PNG，也不操作 Steam。

## 状态语义

- `Unit.story_outcome` 是昏迷、制服、被擒等剧情非死亡结算，绘制时只查询 `down`。
- 普通生命值归零进入 `_dying`，绘制时只查询 `death`。
- 战役 variant 的 `animation_path()` 现在保留调用方给出的状态名，不再把 `death` 改写成 `down`。
- 战役 variant 缺少 `down` 或 `death` 时，不再回退同方向 `idle`。资源层继续查找基础人物的同名定向或旧无方向素材；同名素材也不存在时返回空数组，由 `Unit` 既有程序化终态处理。
- 因此剧情 `down` 不会借用死亡图，普通死亡也不会借用剧情制服图。其他非终态动作仍保留同方向 `idle` 兼容回退。

## 快活林

`jiang_menshen_fists` 的 `windup` 与 `rush_windup` 都读取当前方向 `attack` 的第一帧。条件同时限定 story pose 和 variant；其他 story pose 保持待机，其他人物即使带有同名 meta 也不进入蒋门神分支。

## 修改文件

- `scripts/campaign_art.gd`：删除 `death -> down` 状态改名。
- `scripts/art_db.gd`：`down`、`death` 缺图时禁止回退战役待机；方向来源判定使用相同规则。
- `scripts/unit.gd`：仅为 `jiang_menshen_fists/rush_windup` 增加攻击起手路由。
- `tools/campaign_art_contract.gd`：验证四向 `down/death` 路径分离、旧死亡帧兼容、程序化死亡回退和剧情 down 不借 death/idle。
- `tools/direction4_regression_test.gd`：验证蒋门神两个起手姿态四向来源，以及其他姿态和其他 variant 隔离。
- `tools/campaign_kuaihuolin_depth_test.gd`：在实际重拳与直冲流程中验证 attack 起手来源。

## 备份

修改前六个文件和 SHA-256 保存在：

`C:/Users/rsb/Desktop/AI项目/水浒/implementation_20260902/pre_campaign_state_isolation_20260902_114009/`

其中 `baseline_sha256.json` 记录源码基线，`production_png_sha256.json` 记录当时 `assets/anim` 与 `assets/campaign` 共 924 张生产 PNG 的逐文件哈希。

## 验证

- `campaign_art_contract.gd`：131/131 通过。四个方向均确认：武松孟州 `down` 读取战役 down；缺少战役 death 时读取旧 `wu_song_death.png`；鲁智深缺 down 不借旧 death；董超同时缺战役与旧 death 时保持空数组，交给程序化死亡。
- `campaign_art_motion_contract.gd`：74/74 通过，战役造型和自由模式资源隔离保持不变。
- `direction4_regression_test.gd`：63/63 通过；164 个普通可移动单位方向检查通过，临时 `assets/anim` 代理已清除。蒋门神 `windup/rush_windup` 的四个方向均命中对应 attack，其他姿态和武松 variant 均未误入。
- `campaign_kuaihuolin_depth_test.gd`：19/19 通过；实际重拳与直冲的预警、躲避和反击窗口均保持，两个起手都读取当前方向 attack。
- `test_early_episodes.gd`：4/4 主链、5/5 失败或偏离用例通过；快活林仍以 `subdued` 留命结算，完整原著奖励与自由路线均保留。
- 修改后复算修改前快照中的 924 张生产 PNG，结果 0 个新增、删除或内容变化。本批没有生成或改写图片。

证据集中在 `qa/campaign_state_isolation_20260902/`。这些结果是自动化运行时与资源契约证据，不代表真人节奏、平衡或视觉验收。
