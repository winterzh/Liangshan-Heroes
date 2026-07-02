# 技能系统 V2 · 后续任务交接书（给 Opus / 任何续做者）

> 前置阅读：`docs/ABILITY_SYSTEM_V2.md`（三轴模型 + 已完成部分 + 全部锚点）。
> 本文档 = 剩余全部工作的执行清单，每项都有：改哪、怎么改、怎么验收。
> 写作日期 2026-07-02。当前状态：机制层 432/432 全部生效、同构清零；演出 A级 103/432(24%)。
>
> **执行方式（用户指示）：不分批，一把干完。** 从 §1 做到 §4 一次性全部完成，中途不停下来等
> 用户反馈；但**每完成一个小节仍要跑一次编译 + 全家桶选测**（防止错误滚雪球，红了当场修——
> 这是工程自检，不是等审批）。全部完成后统一：全家桶全绿 + 同构 0 组 + 重打 .app + 一份总结报告。
> 唯一例外：§5 平衡数值仍然不动（等用户实测）。

## 原语完备度总表（做完本文档后 DOTA 设计空间即基本封顶）

| 状态 | 原语 | 章节 | 首发英雄 |
|---|---|---|---|
| ✅ 已有 | 单体指向/追踪弹/钩拖/换位/走近施法/缠绕/缴械/骑手系统/真幻象/持续区域全家族 | — | 已上线 |
| ⬜ 待做 | 嘲讽 taunt（强制索敌） | §1 | 索超（斧王怒吼·用户点名）；鲁智深可复用 |
| ⬜ 待做 | 引导 channel（持续施法可打断） | §3a | 凌振、公孙胜 |
| ⬜ 待做 | 变身 transform（形态切换） | §3b（改动面最大，放最后实现） | 燕顺狼形、朱仝龙形 |
| ⬜ 待做 | hex 变形控制（组合骑手+视觉） | §3c | 妖法系地煞 |
| ⬜ 待做 | 技能等级化光环 | §3d | 各光环被动 |
| ⬜ 待做 | 主动隐身 invis（出手破隐） | §3e | 燕青、时迁 |
| ⬜ 待做 | 驱散 dispel（净化增/减益） | §3f | 安道全、樊瑞 |
| ⬜ 顺手 | 非追踪直线弹（bolt 加 `homing:false`+`len`，可躲的技能弹） | 做 §1 时顺手 | 张清没羽箭、郁保四 |
| ✖ 不做 | 伤害转移/属性偷取/复杂 buff 转移 | 冷门，收益低 | — |

---

## 0. 铁律（先读这节，别跳）

1. **不许 commit / push**。用户在逐版试 `.app`，工作区保持未提交；每完成一批只重打包：
   `godot --headless --export-release "macOS" build/LiangshanHeroes.app`。
2. **验证全家桶**（每完成一个小节跑一次，红了当场修，不积压）：
   ```
   godot --headless --import                                    # 编译检查（看 SCRIPT ERROR）
   SMOKE_TEST=1 ARENA=1 KIT2_TEST=1 DOTACAST=1 REWORK_TEST=1 godot --headless --quit-after 14
   SMOKE_TEST=1 SKIRMISH=1 TOWERTRAP_TEST=1 godot --headless --quit-after 14
   SMOKE_TEST=1 AUTOMICRO=1 godot --headless --quit-after 14
   ```
   期望：DOTACAST `casts=432 no crash` + `tooltip 468`；KIT2 6/6（你加了原语就加断言）；其余 ALL=true。
   godot = `/Applications/Godot.app/Contents/MacOS/Godot`，PATH 里没有 `timeout` 命令。
3. **改技能签名后必须重跑同构脚本**（曾两次撞上"本来唯一"的英雄）：脚本思路——遍历
   `Defs.UNITS` 中 `hero_trainable`，4 技能 kind 排序拼签名分组，>1 即同构。期望输出 0 组。
4. **defs.gd 的 `__DOTA_GEN_ABIL_START/END` 区**：内含大量手工重做条目，盲目重跑 codegen 会全部覆盖。别跑 codegen。
5. **缩进是 tab**：battle.gd 顶层函数体 1-tab，match 标签 2-tab、分支体 3-tab；静态函数同理。Edit 前用精确文本锚定。
6. **坐标系**：`world.transform = GameMap.ISO`，单位/FX 节点的 position 都是逻辑坐标；FX `_draw` 想画"立起来"的东西先 `draw_set_transform_matrix(GameMap.ISO_INV)` 切屏幕空间（画完记得复位），想画贴地椭圆就直接画。参考 BoltFx / SpearSweepFx / ChronoFx 三种范式。
7. **新 kind 上线三件套**：`_do_ability` 加分支 → `Defs.ability_levels` 加 tooltip 分支（防 P0 崩溃）→ KIT2 选测加断言。无目标点施法必须安全降级（DOTACAST 会用点施法轰一遍全部技能）。
8. 选测里没有引擎帧：弹道用 `_bolt_pass(0.05)` 手动步进；用 `units_near` 前先 `_grid_build()`。
9. **美术管线**：`python3 /tmp/cg/wardgen.py <out_raw.png> <prompt.txt>`（后台 Safari→ChatGPT，绿幕 #00b140 2×2，工笔风，参考 /tmp/cg/kit2_prompt.txt 的措辞）→ `CG_DIR=/tmp/cg godot --headless -s tools/cut_anim.gd`（先在 _init 里加 `_cut_grid` 条目）→ art_db.gd 加 SHEET/CELLS/accessor → 调用方带无图回退。偶发"点了发送不出图"（imgs=0 超时 exit 3），重试即可。

---

## 1.【用户点名·最优先】嘲讽(taunt)原语 + 索超真·斧王

**现状**：索超 R 已是掷斧处决(bolt)，但 Q「急锋叱喝」只是 smite 眩晕——斧王的灵魂是
Berserker's Call：**强制周围敌人攻击自己**。引擎没有"被迫索敌"状态，需新增。

### 1a. unit.gd 新状态
- 字段区（`_root_t/_disarm_t` 旁）：`var _taunt_t := 0.0`、`var _taunt_src: Unit = null`。
- 计时衰减（`_root_t` 衰减旁）：到 0 时清 `_taunt_src`。
- applier（apply_root 旁）：
  ```gdscript
  ## DOTA 嘲讽(taunt)：dur 秒内被迫攻击 src（无视原目标/指令）。
  func apply_taunt(src: Unit, dur: float) -> void:
      _taunt_t = maxf(_taunt_t, dur)
      _taunt_src = src
      if src != null and is_instance_valid(src):
          order_attack(src)   # 立刻转火
      queue_redraw()
  ```
- **强制生效点**：`_physics_process` 状态机入口附近（`_stun_t` 判定之后）——
  嘲讽中每帧校正：若 `_taunt_src` 有效而 `_target != _taunt_src`，强制 `_target = _taunt_src; _state = ST_CHASE`。
  嘲讽优先级低于眩晕（被晕就站着）、高于玩家指令与 AI 大脑。
- `_draw` 标记：头顶红色怒气感叹号或索套弧线（参考 `_disarm_t` 标记的写法）。
- 骑手接入：`battle._apply_riders` 加
  ```gdscript
  if eff.get("taunt", 0.0) > 0.0 and caster != null and is_instance_valid(caster):
      u.apply_taunt(caster, float(eff["taunt"]))
  ```
  ⚠️ `_apply_riders` 目前签名是 `(u, eff, rank)`，没有 caster——**需要把 caster 加进签名**并更新全部调用点
  （smite/line_nuke/bolt命中/hook拖回/swap/_do_global_nuke 六处，grep `_apply_riders(` 即得）。
- tooltip：`Defs.ability_levels` extra 段加 `嘲讽 %ss(强制攻击自己)`。

### 1b. 索超 Q 重做（defs.gd）
```gdscript
"suo_chao_q": {"name": "急锋叱喝", "cd": 12, "targeted": false, "radius": 180, "color": Color("ff3322"),
    "desc": "急先锋一声暴喝，逼周围之敌撇下一切与他死战 2 秒，并自披硬甲（吸收 {v} 伤害）。",
    "effect": {"kind": "smite", "dmg": 10, "taunt": 2.0, "self_shield": 100, "self_shield_dur": 2.5}},
```
自身硬甲复用 `apply_shield`：smite 分支的 `self_atk`/`self_lifesteal` 处理旁追加
`if eff.has("self_shield"): caster.apply_shield(float(eff["self_shield"]) * sc, float(eff.get("self_shield_dur", 3.0)))`。
注意 desc 的 `{v}` 会解析到 dmg（=10），描述里吸收量写死或调整措辞避免误导。
改完重跑同构脚本（Q 仍是 smite kind，签名不变，应仍为 0 组）。
### 1c. 验收
KIT2 加断言：spawn 索超+2 个远处敌兵（先给敌兵下移动令走开）→ 施 Q → 断言两敌 `_target == 索超` 且 `_taunt_t > 0`。
顺带给 AUTOMICRO 跑一遍确认托管不与嘲讽打架（嘲讽的是敌方，冲突面小）。

### 1d.（顺手）非追踪直线弹：bolt 的 `homing:false` 变体
`_bolt_pass` 的 `"bolt"` 分支加变体：`eff.homing == false` 时不追踪——按施法瞬间方向直线飞行
（复用 hook_out 的推进+命中检测代码，命中第一个敌人结算骑手+伤害，飞满 `len` 消散，**可以被走位躲开**）。
`_spawn_bolt` 里按 eff 分派 mode（"bolt" / "bolt_line"）。首发改造：张清 `zhang_qing_q`（没羽箭飞石，
可加 `bolt_art` 新石子贴图或复用现有）、郁保四某槽。改完重跑同构脚本。

---

## 2. P3 演出批量升级（性价比从高到低）

### 2a. smite 按参数分流 FX（~117 条，80+ 英雄，一处改动）
锚点：`battle._do_ability` 的 `"smite":` 分支结束后、通用 `_spawn_ability_fx` 之前（约 4500 行区）。
现状：所有 smite 只有 AbilityFx 扩散圈；仅带 amp 的已分流 AmpCastFx。
做法：按 effect 参数选一个**现成 FX 类**（都在 battle.gd 底部，直接 new + position + fx_root.add_child）：
| 参数 | 用哪个现成类 | 说明 |
|---|---|---|
| stun>0 | StompFx | 震地环+尘土（李逵 R 在用） |
| slow>0 | SlashArcFx 或 WhirlFx | 刀光弧 |
| silence>0 | **新写 SilenceFx**：落点升起 3-4 张紫色符纸+封口涟漪，~40 行，仿 AmpCastFx 结构 |
| def_down | **新写 ArmorCrackFx**：碎甲片飞溅+裂纹，~40 行 |
| dot_total | FlameburstFx（已有） | 点燃感 |
| 默认 | 保持 AbilityFx | |
注意：分流是**替换**默认 AbilityFx 还是**叠加**，选替换（`_spawn_ability_fx` 那行加条件跳过），避免双重闪光。
验收：DOTACAST 无崩溃 + 截图抽查（有现成钩子：`SCREENSHOT_DIR=<dir>` 环境变量启动即自动连拍，
配 ARENA=1 进竞技场放几个技能对比前后）。

### 2b. blink 双端闪（19 人，零演出→有）
锚点：`_do_ability` `"blink":` 分支（约 4605 区）。起点+落点各 spawn 一个 BlinkShotFx
（start_w=from，end_w=to，position=to；第二个反向），加短残影线。参考 `_do_swap` 里的用法（已写好同款）。

### 2c. charge kind 级尾迹（16 人）
现状：ChargeFx 存在但只挂了 2 个旧 aid（`_spawn_hero_skill_fx` 的 ABILITY_FX 表）。
做法：在 charge 执行处（unit.gd `_do_charge_step` 起跑瞬间或 battle 的 charge 分支）统一 spawn ChargeFx。
注意别给旧 2 个 aid 双份。

### 2d. 被动/自身 buff 的单位层视觉（~130 条 C 级的大头）
锚点：unit.gd `_draw()`（`_buff_glow` 黄圈附近）。加三个状态分支：
- `_shield > 0`：身体外一圈淡蓝护盾泡（半透椭圆+高光弧）；
- `buff_atk > 1`（临时攻增益）：武器/手部金红辉光粒子；
- `temp_atkspeed > 1`：双手残影短线。
全是被动持续视觉，注意帧成本：兵海场景 300+ 单位，只在状态激活时画、粒子 ≤4 个。
验收：PERF_BENCH=200 跑一下帧时间无明显回退（battle.gd 有现成 profiler，env PERF_BENCH）。

### 2e. 召唤物去同质（依赖美术，可后置）
现状：普通召唤全是虎/龙两张皮。做法：`_do_summon` 支持 `eff.summon_skin`，按皮肤换 Art 贴图；
美术 prompt 批次见 ABILITY_SYSTEM_V2.md §5（狼/鹰/藤甲兵/水鬼 一张 2×2 起步）。

---

## 3. P4 系统缺口（每个都是新原语，逐个做+逐个验）

### 3a. channel 引导施法
- unit.gd：`_channel_t/_channel_slot/_channel_tick_t` 字段；引导中不能移动不能普攻；
  **被眩晕/沉默/缴械不打断规则自定：眩晕必断、沉默必断、位移必断**（hook/swap 拖走要断——在
  apply_stun/apply_silence 里加 `if _channel_t > 0: _break_channel()`）。
- battle：新 kind `"channel"`：`{"kind":"channel","dur":4,"tick":0.5,"tick_dmg":…}`，_begin_cast 后
  进入引导，每 tick 对目标/区域结算；头顶引导进度条（unit._draw，参考血条画法）。
- 首发英雄：凌振（炮击引导版可替代/升级现有 R）、公孙胜某技。
- KIT2 断言：开始引导→手动步进→打断→验证效果停止。

### 3b. transform 变身
- unit.gd：`apply_form(form: Dictionary, dur: float)`——临时替换 atk/atk_cd/range/speed/radius/贴图 key，
  存 `_form_backup` 到期还原（注意与 `_recompute_hero_stats` 的互相覆盖：变身期间 recompute 要叠加 form 修正）。
- 新 kind `"transform"`：`{"kind":"transform","form":{...},"dur":20}`。
- 首发：燕顺(Lycan 狼形·加速加攻)、朱仝(DK 龙形·远程溅射)。美术：狼/龙形态图（管线§0.9）。
- 这是**改动面最大**的一项（动画/贴图系统耦合），建议放 P4 最后，先出无贴图版（改色+参数）验证机制。

### 3c. hex 变形控制（低成本）
= silence+disarm+slow 的组合骑手 + 变小圆球的临时视觉。可以先做"组合骑手宏"：
`"hex": 2.0` 在 _apply_riders 里展开成三样 + unit 侧 `_hex_t` 画个小猪/球替身。首发：某妖法系地煞。

### 3d. 技能等级化光环
现状 aura 是单位字段（固定），不吃技能等级。做法：passive kind 支持 `aura_*_ranks`，
`_recompute_hero_stats` 时按 rank 取值写回单位 aura 字段。首发：宋江 song_lead 已有 speed_aura_ranks 先例——照它做即可。

### 3e. invisibility 主动隐身
现状只有芦苇丛被动藏身（`hidden_in_reeds`，索敌 75px 上限——实现可参考）。做法：
- unit：`_invis_t` 字段；隐身中 `modulate.a ≈ 0.35`（己方可见半透，敌方 `visible=false` 走迷雾同款分层：
  渲染藏 + `_acquire`/`_enemy_at`/技能索敌全部过滤，grep `hidden_in_reeds` 把同款条件补成 `or _invis_t>0`）；
  **攻击/施法即破隐**（`_attack`/`_do_ability` 里清 `_invis_t`），破隐第一击可带加成字段 `invis_strike_bonus`。
- 新 kind `"invis"`：`{"kind":"invis","dur":8,"strike_bonus":40}`。首发：燕青（Riki 就该隐身）、时迁（鼓上蚤夜行）。
- ⚠️ 塔/陷阱是否反隐自定（建议塔不反隐、陷阱照踩）。KIT2 断言：隐身后 `_enemy_at` 点不到 + 出手破隐。

### 3f. dispel 驱散（净化）
移除单位身上的临时状态。做法：unit 加 `dispel(hostile: bool)`——hostile=true 清增益
（`buff_atk/temp_speed/_shield/temp_atkspeed/隐身`），false 清减益（`_stun_t/_root_t/_disarm_t/_silence_t/
_dmg_amp/slow/dot`）。骑手字段 `"dispel": "buffs"/"debuffs"`（敌施清增益、友施清减益）。
首发：安道全（神医解控）、樊瑞（法师驱敌方 buff）。注意与 taunt/嘲讽的交互：驱散可解嘲讽。

---

## 4. P5 点将/技能 UI

1. **分类二级菜单**：竞技场聚义厅 `train_menu`（battle.gd ~1067-1096 竞技场分支，PAGE=6 翻 18 页）
   复用关卡编辑器已有的 108 将分类实现（commit `7ac8ab5`，在编辑器代码里搜"分类"）。按天罡/地煞/兵种分组。
2. **悬浮技能卡**：hud.gd CommandBtn `_on_hover_in`（~1786）目前只有名字+花费。加 4 技能行：
   名字+kind 图标字+一句 desc 首行（数据都在 Defs.ABILITIES，注意悬浮卡宽度）。
3. **技能图标**：hud.gd `ICON_TOKENS`（~2057）只覆盖 21 个旧 id，400+ 生成技能回退色块首字。
   低成本方案：按 kind 给 36 个矢量小图标（劈砍/箭/火/盾…每个 ~10 行 draw 代码）；高成本方案：美术图集。
4. 竞技场资源无限时隐藏点将按钮上的金木花费（信息噪声）。

---

## 5. 平衡（放最后，等用户实测反馈后再动）
所有数值 v1 未实战调过。已知风险点：新 bolt 单体控制链（晕/缠绕/缴械叠加）可能过强；
掷斧斩首 120×sc 对脆皮英雄可能一击必杀；施法距离 380 全局值可能需要按 kind 微调。
**没有用户反馈前不要主动改数值。**

---

## 6. Definition of Done（一次性交付的完成标准）
- [ ] §1→§4 全部完成（§5 平衡不动）；每个新原语都有 KIT2 断言
- [ ] 编译 0 error；验证全家桶全绿；DOTACAST 432 施放无崩溃、tooltip 无崩溃
- [ ] 改过签名 → 同构脚本 0 组
- [ ] 新 kind → ability_levels 有 tooltip 分支；有美术 → 有无图回退
- [ ] 重打 .app（**全程不 commit**），最后交一份总结报告：做了什么/验证结果/已知残留/建议试玩点
