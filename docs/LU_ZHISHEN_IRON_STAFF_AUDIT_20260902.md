# 鲁智深浑铁禅杖路由审计（2026-09-02）

## 结论

审计确认两处生产错误：`Unit._weapon_kind()` 曾把 `lu_zhishen` 与李逵一起归入 `AXE`；`Battle.ABILITY_FX` 曾把 `lu_sweep` 交给绘制两道大刀光弧的 `SlashArcFx`。攻击音效虽使用 `atk_staff`，注释和波形语义仍写成木响。

本批把鲁智深收敛为独立的 `iron_staff` 武器契约。中央单位定义、通用模式、野猪林 `lu_zhishen_rescue` 变体和旧自定义定义的兼容回退都解析到 `WK.IRON_STAFF`。基本攻击拥有独立的重杖节奏、命中时点、位移、转体、直杖扫击和金铁声；`禅杖横扫` 改用只画直身铁杖与双端束箍的 `IronStaffSweepFx`，不再借用刀弧或蛇矛特效。

## 修改范围

- `scripts/defs.gd`：鲁智深增加 `weapon_profile: iron_staff`；技能说明明确为浑铁禅杖。
- `scripts/unit.gd`：新增 `WK.IRON_STAFF`，并为攻击节奏、重击、音效、位移、旋转和扫击绘制提供独立分支；保留按 `lu_zhishen` 键识别的旧定义兼容路径。
- `scripts/battle.gd`：`lu_sweep` 改走 `iron_staff`，新增程序化 `IronStaffSweepFx`。
- `scripts/sfx.gd`：`atk_staff` 改为金铁重响语义。
- `tools/lu_zhishen_weapon_contract.gd`：真实运行时契约。
- `tools/lu_zhishen_weapon_static_audit.py`：生产源码与文案静态契约。

没有修改网页原图、生产人物 PNG、Steam 发布目录或玩家存档。

## 验证

- 新静态契约：14/14，通过。
- 新运行时契约：23/23，通过。覆盖中央定义、旧定义回退、普通攻击入口、专属特效真实绘制、野猪林救援变体，以及竞技场、遭遇战、AI 战、自定义防守四种真实场景实例。
- 现有四向回归：63/63，通过；164 个普通可移动单位方向更新仍通过。
- 战役美术隔离：131 项，通过。
- 野猪林路线与重开：10/10，通过。
- 上述最终日志没有 `SCRIPT ERROR`、`ERROR`、`WARNING`、泄漏或资源残留提示。

## 边界证据

源码修改前的外部备份位于 `C:\Users\rsb\Desktop\AI项目\水浒\implementation_20260902\pre_lu_zhishen_iron_staff_20260902_122900`。

本批基线之后，共享工作区的另一个环境批次新增了 16 张 `assets/campaign/environment/level5` PNG，网页批次新增了 7 张下载原图。因此整棵图片目录的聚合哈希发生变化。逐文件对比证明：本批基线已有的 1055 张生产 PNG 和 46 个网页源文件均为 0 修改、0 删除；新增项和时间戳记录在 `qa/lu_zhishen_iron_staff_20260902/shared_tree_concurrency_delta.json`，不能归入本批。

Steam 目录 597 个文件的聚合 SHA-256 在修改前后均为 `5ef638db4e95fcc9893dfaa2312c9146e844b8717e4cb62631ea424ac9dd422c`。
