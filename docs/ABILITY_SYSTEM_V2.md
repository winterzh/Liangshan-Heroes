# 技能系统 V2 —— 三轴解耦设计（基础设施版）

> 目标：108 将对标 DOTA，不是为了"补 108 套特效"，而是把技能系统做成**可长期迭代的基础资产库**。
> 本文档是设计+落地手册：已实现的部分标 ✅（含 file:func 锚点），未实现的部分是路线图，任何后续
> 会话（或 Opus handover）可直接按锚点续做。
>
> 2026-07-02 首版：核心引擎（骑手/单体指向/弹道/钩/换位/缠绕/缴械/走近施法）已落地并通过 KIT2 选测 6/6。

---

## 0. 诊断：为什么会同质化

旧模型只有一根轴：`effect.kind`（36 种），并且**瞄准方式被压扁成一个布尔**（`targeted: true`=点地，
false=以自身为圆心）。这导致：

- 设计空间 = kind 数量，而 DOTA 的设计空间 = 瞄准 × 递送 × 效果 的**笛卡尔积**；
- smite（点地圆 AoE + 伤害 + 若干控制）成为万能容器 → 129/428 槽是 smite、27 个英雄 kit 完全同构；
- 每种 kind 的控制/减益结算是复制粘贴的 if 堆 → 新效果（如缠绕）要改 N 处；
- 没有单体指向、没有弹道飞行时间、没有引导、没有以单位为对象的位移（钩/换位/推）。

## 1. 三轴模型

任何一个技能 = **瞄准（怎么点）× 递送（怎么到）× 效果骑手（到了干什么）**，三轴正交、自由组合。

### 轴 1 瞄准 `target`（✅ 已实现）
| 值 | 含义 | 数据写法 |
|---|---|---|
| `"point"`(默认) | 点地（现有全部 targeted:true） | `"targeted": true` |
| `"unit"` ✅ | **单体指向**：点一个单位 | `"targeted": true, "target": "unit", "unit_team": "enemy"/"ally"/"any"` |
| 自身/无目标 | 现有 targeted:false | 不变 |
| 方向（隐式） | line/hook/charge 用点击点只取方向 | 不变（点地即方向） |

**落地锚点**：
- `battle.cast_ability`（待指向提示分支）→ `battle._cast_armed_at`（`target=="unit"` 时用
  `_armed_unit_at(p, team)` 解析单位；点空地保持待指向态）→ `_begin_cast(caster, slot, lp, tgt)`。
- **走近施法（DOTA式）** ✅：目标超射程 → `_queue_walk_cast` 入队，`_walk_cast_pass`（0.4s 节流追点）
  自动接近、进射程即施放；玩家下任何新指令（`unit._order_serial` 变化）立即让路取消。
- **抬手跟踪** ✅：`_pending_casts` 条目带 `tgt`，`_do_ability` 结算时取目标**当前**位置；
  目标抬手途中阵亡 → 单体技能取消且**不进 CD**。
- **AI 兜底** ✅：AI（托管/敌将）不给 tgt 时，`_begin_cast` 自动以落点最近敌方单位为目标。

### 轴 2 递送 `delivery`（✅ 弹道已实现，引导未实现）
| 递送 | 状态 | 说明 |
|---|---|---|
| 瞬发 | ✅（默认） | 现有全部 |
| **追踪弹 bolt** | ✅ | `_bolts` 数组 + `_bolt_pass(delta)` 逐帧推进；`proj_speed` 可调；目标死亡落空 |
| **方向弹 hook** | ✅ | 三阶段：`hook_out` 贯线飞出（len/width 判定首个命中）→ `hook_drag` 拖回 → 结算 |
| 持续区域 zone | ✅（既有） | ward/ground_dot/chrono/ice_wall/fire_line… 已是成熟资产 |
| 引导 channel | ⬜ 路线图 | `unit._channel_t` + 被眩晕/沉默打断 + 每 tick 结算 + 头顶引导条 |

**落地锚点**：`battle._spawn_bolt` / `_spawn_hook` / `_bolt_pass`（在 `_physics_process` FIGHT 段与
`_ward_pass` 同排注册）；演出 `class BoltFx`（battle.gd 底部 FX 区，链条模式画回施法者的连节锁链，
`draw_set_transform_matrix(GameMap.ISO_INV)` 切屏幕空间——这是所有"立起来"的 FX 的既定约定）。

### 轴 3 效果骑手 `riders`（✅ 已实现）
**任何 kind** 的 effect 里都可以声明这些字段，命中单位时统一由 `battle._apply_riders(u, eff, rank)` 挂上：

```
slow + slow_dur / stun / def_down(+def_down_dur) / blind / silence / amp(+amp_dur)
root（缠绕：不能移动可反击）✅新 / disarm（缴械：不能普攻可移动）✅新
```

- 已接入骑手的 kind：smite、line_nuke（21 条直线技瞬间获得全套控制）、bolt、hook、swap。
  其余 kind 迁移是纯机械工作：把各分支里的 if 堆替换为一行 `_apply_riders`。
- 新状态落地锚点（unit.gd）：`_root_t`/`_disarm_t` 字段 + `apply_root`/`apply_disarm` +
  `_follow_path` 头部 root 闸门 + `_attack` 头部 disarm 闸门 + `_draw` 里的藤蔓/斜杠剑标记。
- tooltip 自动化：`Defs.ability_levels` 的 extra 段已识别 root/disarm（与 silence/amp 同款）。

### 新增 kind 一览（✅ 全部带 KIT2 选测断言）
| kind | 轴组合 | 样板 | 说明 |
|---|---|---|---|
| `bolt` | unit × 追踪弹 × 骑手 | 扈三娘 W 红锦套索 | 单体指向控制/爆发的通用容器 |
| `hook` | 方向 × hook 弹 × 骑手 | 彭玘 Q 钩镰拖钩 | 真·Pudge 钩：链条可见、拖回身前 |
| `swap` | unit(any) × 瞬发 | 扈三娘 R 乾坤挪移 | 换敌入阵/换友脱险，VS 签名 |

## 2. 数据 schema 备忘（defs.gd）

```gdscript
"xxx_w": {"name": "…", "cd": 12, "targeted": true,
    "target": "unit",            # 轴1：单体指向（省略=点地）
    "unit_team": "any",          # enemy(默认)/ally/any
    "radius": 0,                 # 点地 AoE 半径；单体技能填 0
    "effect": {"kind": "bolt",   # 轴2+3 的容器
        "dmg": 30, "proj_speed": 460,          # 递送参数
        "stun": 1.4, "root": 0, "disarm": 0,   # 骑手（任意组合）
        "cast_range": 480}}                    # 施法距离覆写（省略=380+radius；宋江/花荣/global 豁免）
```

⚠️ 生成块 `__DOTA_GEN_ABIL_START/END` 内的手工修改（含本次样板）会被盲目重跑 codegen 覆盖——
重跑前必须把手工条目摘出来（同 dota-rework-108 的备忘）。

## 3. 本次接线的内容（✅）

- 彭玘 Q `hook`（原 pull 瞬移贴脸 → 真钩，链条演出）
- 扈三娘 W `bolt` 红锦套索（游戏第一个单体指向技能）、R `swap` 乾坤挪移（unit_team:any）
- 时迁 Q 绊索：slow → `root` 1.2s（骑手经 line_nuke 生效的证明）
- 呼延灼 Q：stun 1.6 → stun 0.8 + `disarm` 2.5（双鞭打脱兵器）
- 三套孤儿 kit 接线：呼延灼/凌振/单廷圭 换上已生成的 4 技能组（DOTACAST 428→432）

## 4. 去同质化路线图（P2 已完成，其余按收益排序）

### P2 签名机制迁移 ✅（2026-07-02 完成：同构 31→0）
24 位英雄各换 1 条签名技，kind 签名全库唯一。速查（改动都在 defs.gd GEN 区）：
bolt 单体指向×11（朱仝龙尾拍/索超掷斧斩首[axe]/刘唐裂血amp/李衮天火/黄信噩梦[dark]/孙立掷鞭/
郝思文寒冰锁体[ice·root]/蔡庆亡魂弹[dark]/李云暗噬[dark]/裴宣一言定谳[dark·silence]/施恩→改毒瘴桩ward)、
hook（汤隆钩镰试锋——他就是造钩镰枪的）、echo（李俊翻江倒海）、global_nuke+silence（裴宣满堂封口）、
heal_wave（曹正放血引魂）、fissure（陶宗旺掘地裂沟）、fire_dot（王英燎原）、black_rain（李云黑天罩follow/孟康天降神火）、
charge（宣赞郡马冲撞/欧鹏金翅掠袭）、chain_nuke（单廷圭圣水连雷）、ward attack（凌振架设神炮）、line_nuke stun（解宝穿地突刺）。
`_do_global_nuke` 已接 `_apply_riders`（全图技吃全套骑手）。

### P3 演出批量升级（一次改动惠及 N 人）
1. smite 按参数分流现成 FX（85 人/129 条，只改 `_do_ability` smite 分支的 FX 选择）：
   stun→StompFx、slow→SlashArcFx、silence→紫雾、amp→AmpCastFx(已有)。
2. blink 消失/出现双闪（19 人，零演出→BlinkShotFx 两端）。
3. charge kind 级冲刺尾迹（16 人，ChargeFx 已存在只挂了 2 个旧 aid）。
4. buff 类单位层持续视觉：武器辉光/护盾泡（unit._draw 加分支，`_buff_glow` 已有基础）。

### P4 系统缺口（引导/变身/光环升级）
- channel 引导（凌振炮击、萨满束缚类）；
- transform 变身（燕顺狼形/朱仝龙形：`apply_form(form_def, dur)` 换 atk/speed/皮肤）；
- 技能光环（随 rank 升级的 aura，现在 aura 是单位字段不吃技能等级）；
- hex 变形控制（沉默+缴械+减速的组合骑手即可近似，做个皮）。

### P5 UI（点将体验）
- 竞技场点将菜单复用关卡编辑器的 108 将分类二级菜单（commit 7ac8ab5 有现成实现）；
- 悬浮卡显示 4 技能名+kind 图标；~400 条生成技能的 ICON_TOKENS 色块升级。

## 5. 美术管线与 prompt 清单

管线（已两次验证）：`/tmp/cg/wardgen.py <out.png> <prompt.txt>` 驱动后台 Safari→ChatGPT 生成
2×2 绿幕(#00b140)图集 → `tools/cut_anim.gd` `_cut_grid` 切格抠绿 → `art_db.gd` `_atlas` 加载，
全部带"贴图缺失→程序化绘制"的优雅回退。

已生成：`assets/wards.png`（三桩）、`assets/fx_kit2.png`（钩头/红锦套索/换位玉符/缠绕藤蔓）。

后续批次 prompt 模板（每张 2×2、宋代工笔、纯绿底、无文字无阴影）：
1. **smite 分流四件套**：震地裂纹环 / 挥砍弧光 / 噤声紫雾符 / 破甲裂纹盾。
2. **弹道皮肤**：没羽箭飞石 / 月光长箭 / 火炮弹丸 / 毒镖。
3. **buff 图腾**：武器金辉 / 护盾水泡 / 狂暴红焰 / 加速风纹。
4. **变身形态**（P4 用）：狼形剪影 / 龙形剪影 ——需要 2×2 动作帧时改用 cut_anim 的动画切法。

## 6. 验证矩阵

| 选测 | 环境门 | 覆盖 |
|---|---|---|
| KIT2 6/6 | `ARENA=1 KIT2_TEST=1` | bolt 命中+骑手 / swap 换位 / hook 拖回 / root 定身 / disarm 禁手 / walk-cast |
| DOTACAST | `ARENA=1 DOTACAST=1` | 108 将 432 施放无崩溃 + 468 tooltip 渲染 |
| REWORK 10/10 | `ARENA=1 REWORK_TEST=1` | 第一批 10 技能机制 |
| TOWERTRAP 19/19 | `SKIRMISH=1 TOWERTRAP_TEST=1` | 塔/陷阱/经济策略/倍率/分路/手动保护 |
| AUTOMICRO 13/13 | `AUTOMICRO=1` | 托管脑 |

新 kind 上线守则：①`_do_ability` 加分支时同步给 `Defs.ability_levels` 加 tooltip 分支（防 P0）；
②跑一遍 DOTACAST（无目标点施法必须安全降级）；③KIT2 加一条断言。
