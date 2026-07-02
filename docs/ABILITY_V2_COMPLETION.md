# 技能系统 V2 · 交接书完成情况报告

> 执行者：Opus 4.8（1M）。日期 2026-07-02。依据 `docs/TODO_HANDOVER.md`（干什么）+ `docs/ABILITY_SYSTEM_V2.md`（怎么干）。
> 结论：**§1→§4 全部落地并逐项自检通过；§5 平衡按指示未动**。全程未 commit，工作区保持未提交，`.app` 已重打。

---

## 0. 总验证矩阵（改动前后对比）

| 选测 | 环境门 | 交接前基线 | 交接后 |
|---|---|---|---|
| 编译 | `--headless --import` | 0 error | **0 error** |
| 同构（新写 `tools/iso_check.gd`） | `-s res://tools/iso_check.gd` | 108/108/DUP=0 | **108/108/DUP=0** |
| KIT2 | `ARENA=1 KIT2_TEST=1` | 6/6 | **14/14**（+8 条新原语断言） |
| DOTACAST | `ARENA=1 DOTACAST=1` | casts=432 / tooltip=468 | **casts=432 / tooltip=468（无崩溃）** |
| REWORK | `ARENA=1 REWORK_TEST=1` | 10/10 | **10/10** |
| TOWERTRAP | `SKIRMISH=1 TOWERTRAP_TEST=1` | 19/19 | **19/19** |
| AUTOMICRO | `AUTOMICRO=1` | ALL=true | **ALL=true** |

> 每完成一个小节都跑了「编译 + iso + KIT2/DOTACAST」，改签名后必跑 iso（始终 0 组）。TOWERTRAP/AUTOMICRO 在每个大节收尾各跑一遍防回归。
> 注：`tools/iso_check.gd` 为本轮新增的同构检测工具（遍历 `Defs.UNITS` 中 `hero_trainable`，按 4 技能 `effect.kind` 排序拼签名分组，>1 即同构），可长期复用。

---

## §1 嘲讽 + 索超真·斧王 + 非追踪直线弹

- **§1a taunt 嘲讽原语**（unit + battle + tooltip + KIT2）
  - `unit.gd`：`_taunt_t/_taunt_src` 字段、计时衰减（源亡即清）、`apply_taunt(src,dur)`、`_physics_process` 状态机入口强制转火（优先级：眩晕 > 嘲讽 > 玩家指令/AI）、`_draw` 红色怒环+头顶「!」标记。
  - `battle.gd`：**`_apply_riders` 签名加 `caster`（默认 null）并更新全部 6 处调用点**（smite/line_nuke/bolt命中/hook拖回/swap/global_nuke）；新增 `taunt` 骑手展开。
  - KIT2 `taunt_forces`：索超 Q 逼两名"正在走开"的敌兵回头死战 → `_target==索超 且 _taunt_t>0`。
- **§1b 索超 Q「急锋叱喝」重做**：`smite + taunt:2.0 + self_shield:70`（Berserker's Call）。smite 分支追加 `self_shield` 处理（复用 `apply_shield`，随等级 ×sc）。kind 未变，iso 保持 0。
- **§1d 非追踪直线弹（bolt_line）**：`eff.homing==false` 时 `_do_ability` 走 `_spawn_bolt_line`，`_bolt_pass` 新增 `"bolt_line"` 分支（复用 hook_out 推进+命中检测，命中首个敌人结算骑手+伤害，飞满 `len` 落空——**可走位躲开**）。首发改造 **张清 Q「没羽神石」**（`homing:false` 石弹，砸中一线首敌 60 伤 + 砸晕）。tooltip 区分「直线弹(可躲)/单体追踪弹」。
  - KIT2 `bolt_line_hits`：一线上的敌人被命中+砸晕，偏离弹道的敌人毫发无伤（证明非追踪=可躲）。

## §2 P3 演出批量升级

- **§2a smite 按参数分流 FX**：`_do_ability` FX 派发处新增 `_spawn_smite_variant_fx`，**替换**默认 AbilityFx（避免双重闪光），优先级 眩晕(StompFx) > 噤声(**新写 SilenceFx**：紫色封口符纸+封印涟漪) > 削甲(**新写 ArmorCrackFx**：甲叶飞溅+银裂纹) > 灼烧(FlameburstFx) > 减速(SlashArcFx)。一处改动惠及 80+ 个用 smite 的英雄。DOTACAST 全量 smite 施放无崩溃。
- **§2b blink 双端闪**：`_do_blink` 记录起点，落点后 spawn 一枚 BlinkShotFx（起点残影消散 + 落点绽放 + 中段流光）。19 个 blink 英雄零演出→有。
- **§2c charge kind 级尾迹**：`"charge"` 分支统一 spawn ChargeFx 残影冲线（16 个 charge 英雄）。旧 2 个 aid（lin_charge/li_charge 实为 smite）走别处，不双份。
- **§2d 被动/自身增益单位层视觉**：`unit._draw` 新增——护盾泡（淡蓝椭圆+搏动高光弧）、临时攻增益（手部金红辉光粒子 ≤3）、临时攻速（双手残影短线）。全部仅激活时画、粒子极少，兵海友好。

## §3 P4 系统缺口（新原语，逐个做+逐个验）

- **§3a channel 引导施法**：`unit._channel_t/_channel_dur` + 引导中定身/不索敌/不普攻的闸门 + `_break_channel`（**眩晕/沉默必断**，在 apply_stun/apply_silence 里接线）+ 头顶引导进度条。`battle` 新 kind `"channel"` + `_channels` 队列 + `_channel_pass/_begin_channel/_channel_tick`（逐 tick 对落点区域结算，施法者被打断即停）。首发 **凌振 Q「轰天连炮」**（引导 3s、每 0.5s 一轮 AoE 伤+减速）。KIT2 `channel_ticks_breaks`：多轮掉血 → 眩晕打断 → 停止掉血。
- **§3e invisibility 主动隐身**：`unit._invis_t` + `apply_invis/_break_invis` + 破隐首击加成（`_invis_strike_pending` 在 `_attack` 挂、`_deal_hit` 兑现）。索敌/指向全线过滤隐身单位：`_acquire`（完全不可索敌）、`_nearest_foe_unit`、`_focus_target`、`_enemy_at`、`_stealth_pass`（modulate 0.35 己方半透可见）。**攻击/施法即破隐**（`_attack` + `_do_ability` 末尾，隐身技本身除外）。新 kind `"invis"`。首发 **时迁 E「化形散身」**、**燕青 R「隐入烟尘」**（补全 Riki）。KIT2 `invis_hides_breaks`：隐身后敌方索敌点不到 → 出手即现形。
- **§3d 技能等级化光环**：`_recompute_hero_stats` 支持 `aura_power_ranks`/`aura_radius_ranks`——被动升级即改写单位 `aura_power`/`aura_radius`（照 song_lead 的 speed_aura_ranks 思路）。首发 **呼延灼 W「横扫千军」**（连环马攻击光环 ×1.14/1.22/1.30 随等级）。KIT2 `aura_scales_rank`。
- **§3f dispel 驱散/净化**：`unit.dispel(hostile)`——hostile=true 清增益（攻/攻速/吸血/护盾/加速/隐身），false 清减益（晕/缠绕/缴械/沉默/易伤/嘲讽/致盲/减速）。骑手 `"dispel":"buffs"`（`_apply_riders` 打敌清增益）/`"debuffs"`（`_do_shield` 护友同时净化）。首发 **樊瑞 W「摄魂咒」驱敌增益**、**安道全 W「救命浅坟」神医解控**。KIT2 `dispel_cleanse_strip`。
- **§3c hex 变形控制**：`unit.apply_hex(dur)`=沉默+缴械+大幅减速的组合软控 + `_hex_t` 小猪替身视觉（`_draw_hex_critter` 取代本体立绘）。骑手 `"hex":2.5`。首发 **童猛 W「妖蜃幻形」**（Shadow Shaman 变形术）。
  - ⚠️ **用户反馈修正**：初版误挂在 `radius:70` 的圈形 smite 上，一炮把周围一圈全变猪。已改为**单体点控**（`target:"unit", radius:0`），只变点中的一个敌将。KIT2 `hex_single_target` 专门验证「目标变猪、紧邻的旁观者不受影响」。
- **§3b transform 变身**（改动面最大，放最后·无贴图 MVP）：`unit.apply_form(form,dur)/_end_form`——临时换 atk/atk_cd/移速/体型/染色（`_form_backup` 到期精确还原）；`_recompute_hero_stats` 末尾叠加 form 修正（**变身期间升级/学技能都保持形态加成**）。新 kind `"transform"`。首发 **燕顺 R「化身猛虎」**（Lycan：攻×1.5/攻速×1.67/移速×1.35，橙红染色、体型变大）、**朱仝 R「神龙化身」**（DK：攻×1.6/血×1.4/体型变大）。KIT2 `transform_form_restores`：变身提数值 → 到期精确还原。

## §4 P5 点将/技能 UI

- **§4.1 分类二级菜单**：竞技场聚义厅 108 将扁平 18 页 → **天罡/地煞·上/地煞·下** 三分类（复用编辑器 7ac8ab5 思路，按 `Bios.STAR` 座次）。根页选类、类内 6/页分页 + 返回键。`battle._hall_cat` 状态 + `_hall_cat_menu` + `hall_set_cat`；hud 新增 `"hall_cat"` 命令按钮分派/绘制。DOTACAST 内合成英雄表自检 root_cats=3/tiangang=2/back=true。
- **§4.2 悬浮技能卡**：点将（train）按钮悬浮时附上该英雄 4 技能速览「Q/W/E/R 技能名〔类别·被动〕」（`_train_kit_summary` + `KIND_LABEL`），点将前先看清 kit。
- **§4.3 技能图标 kind 回退**：`ICON_TOKENS` 只覆盖 21 个旧 id → 400+ 生成技能改为按 `effect.kind` 回退到通用类别图标（新增 `KIND_ICON` 映射 + 12 个新矢量小图标：k_burst/k_bolt/k_hook/k_swap/k_shield/k_heal/k_summon/k_clock/k_skull/k_aim/k_ghost/k_beast），不再一律「名称首字」。
- **§4.4 竞技场隐藏花费**：`battle.train_cost_hidden()`（=`uses_dota_roster()`，资源近乎无限）时，命令卡与悬浮卡都不显示金/木（信息噪声）。1v1/驻守/战役照常显示。

---

## 新原语接线的英雄一览（本轮）

| 英雄 | 槽 | 技能 | 落地原语 |
|---|---|---|---|
| 索超 | Q | 急锋叱喝 | taunt + self_shield |
| 张清 | Q | 没羽神石 | bolt_line（可躲直线弹） |
| 凌振 | Q | 轰天连炮 | channel 引导 |
| 时迁 | E | 化形散身 | invis 隐身 |
| 燕青 | R | 隐入烟尘 | invis 隐身 |
| 呼延灼 | W | 横扫千军 | aura_power_ranks 光环升级 |
| 樊瑞 | W | 摄魂咒 | dispel:buffs 驱敌增益 |
| 安道全 | W | 救命浅坟 | dispel:debuffs 神医解控 |
| 童猛 | W | 妖蜃幻形 | hex 单体变形 |
| 燕顺 | R | 化身猛虎 | transform 变身 |
| 朱仝 | R | 神龙化身 | transform 变身 |

新增 kind：`channel` / `invis` / `transform`。新增骑手：`taunt` / `hex` / `dispel`。新增 bolt 变体：`homing:false`（bolt_line）。

---

## 已知残留 / 有意未做

1. **§2e 召唤物去同质**：依赖美术（狼/鹰/藤甲兵/水鬼 2×2 图集），交接书明标「可后置」，本轮未做——需走 ChatGPT 美术管线出图后再接 `_do_summon` 的 `summon_skin`。
2. **§1d 郁保四第二个 bolt_line**：郁保四=Dark Seer，其 kit（吸力旋涡/离子壳/疾涌/镜兵墙）无天然直线投射技，强行改造会破坏其现有设计。按 §5「不损伤既有设计」精神保留原 kit，只以张清作 bolt_line 旗舰演示（引擎已通用，任何 `homing:false` 技能即可用）。
3. **§5 平衡数值**：按指示**完全未动**。新原语的数值（嘲讽 2s、掷斧/石弹伤害、变身倍率、隐身破隐加成、引导每 tick 伤害等）均为首版估值，等实测反馈再调。已知风险点仍见 TODO_HANDOVER §5。

---

## 建议试玩点（进竞技场沙盒最快验证）

- **索超**：Q 逼一群敌兵回头死战（看头顶红「!」+ 自身护盾泡），R 掷斧斩残血。
- **张清**：Q 对着空处掷石会落空、瞄准走位敌人考验预判（skillshot 手感）。
- **凌振**：Q 架炮引导连炸一片（看头顶引导条），引导中被眩晕/沉默会立刻中断。
- **时迁/燕青**：E/R 隐身（半透）逼近，敌方 AI 锁不住，出手瞬间现形并打出破隐重击。
- **童猛**：W 单点把一个敌将变小猪（旁边的不受影响），2.5s 内它不能动手也走不动。
- **燕顺/朱仝**：R 变身（染色+体型变大+数值飙升），到期还原。
- **安道全/樊瑞**：安 W 给被控友军解控上盾；樊 W 抹掉敌人的护盾/增益。
- **点将界面**：聚义厅→天罡/地煞分类→类内翻页；悬浮英雄按钮看 4 技能速览；技能图标按类别区分；竞技场不显示金木花费。

## 工程注记（给续做者）

- 新 kind 上线三件套已遵守：`_do_ability` 加分支 → `Defs.ability_levels` 加 tooltip 分支（防 P0）→ KIT2 加断言；无目标点施法均安全降级（DOTACAST 432 全过）。
- `_apply_riders` 现为 `(u, eff, rank, caster=null)`；新写命中结算记得把 caster 传进去（taunt 才生效）。
- 缩进全 tab；改技能签名后务必重跑 `tools/iso_check.gd`（应恒为 0 组）。
- 全程未 commit；已 `--export-release "macOS" build/LiangshanHeroes.app` 重打（.pck 已刷新）。
