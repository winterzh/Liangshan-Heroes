# 基于本引擎做游戏（Modding / Fork 指南）

本项目是一个**数据驱动的等距 RTS 引擎** + 一套《水浒》内容。引擎与内容已尽量分离：
做新关、改数值、加单位、甚至整体换皮，大多不必改引擎代码。

> 三种典型用法：
> 1. **做自定义关卡**（不写代码）→ 用「场景编辑器」或手写 scenario JSON（见 `docs/SCENARIO_FORMAT.md`）。
> 2. **改数值 / 加单位 / 换美术**（少量数据文件）→ 内容包 `res://content/`。
> 3. **写定制机制 / 全新模式**（写代码）→ 继承 `LevelBase` 钩子，或加自定义伴生脚本。

---

## 1. 架构总览（引擎 vs 内容）

| 层 | 文件 | 职责 |
|---|---|---|
| **战斗运行器** | `scripts/battle.gd` | 通用引擎：选取/指挥、寻路、阵型、技能、经济、迷雾、AI、等距渲染、桌面+触屏交互 |
| **关卡契约** | `scripts/level_base.gd` | `LevelBase` 钩子：地图/布兵/流程/胜负。各关只覆写需要的钩子 |
| **数据驱动关卡** | `scripts/levels/scenario.gd` | 读一份 JSON 把所有钩子喂出来（编辑器/分享码/`SCENARIO=` 用） |
| **单位/技能/科技/护甲表** | `scripts/defs.gd` | 纯数据字典 `UNITS / ABILITIES / TECHS / ARMOR` |
| **美术注册表** | `scripts/art_db.gd`（autoload `Art`） | key → 图集格 / 独立图 / 逐帧动画 |
| **关卡注册 + 进度** | `scripts/campaign.gd`（autoload `Campaign`） | 战役表、模式开关、存档 |
| **地图地形** | `scripts/game_map.gd` | 地形枚举、绘制原语、等距投影、A* |

战斗启动链：`Campaign.make_level()` → `Battle._resolve_level()` → `level.paint_map/deploy/on_start/process` 钩子。
`Battle._ready()` 里 `_defs = Defs.UNITS.duplicate(true)`，随后 `Defs.apply_content_pack()` 叠加内容包——
**引擎跑的是一份可被内容包覆盖的副本，不是写死的常量。**

---

## 2. 做关卡

### 2a. 可视化（推荐，无需代码）
主菜单 →「更多 → 🗺 场景编辑器」。刷地形 / 放兵 / 设出兵口与镜头起点，右栏调地图、波次、胜负预设，
「保存」存到 `user://scenarios/`，「▶ 试玩」直接进战斗。做好的关在「更多 → ▶ 玩自定义关卡」里玩。

### 2b. 手写 scenario JSON
完整字段见 **`docs/SCENARIO_FORMAT.md`**；可运行示例 `scenarios/example_liangshan_defense.json`
（即第 5 关「梁山泊保卫战」的纯数据移植，headless 验证可通关）。调试：
```
SCENARIO=/abs/path/to.json /Applications/Godot.app/Contents/MacOS/Godot --path . --headless --quit-after 4000
```

### 2c. 写代码（定制机制 / 全新模式）
继承 `LevelBase`，覆写需要的钩子（见 `level_base.gd` 注释），在 `Campaign.LEVELS` 注册脚本路径。
若只想给数据关卡加一点定制逻辑，用 scenario 的 **伴生脚本** `"script": "res://..."`（见 SCENARIO_FORMAT「伴生脚本」节），
可实现 `deploy/on_start/process/on_wave/on_unit_died/on_ability/top_status/cond` 任意子集。

---

## 3. 内容包（改数值 / 加单位 / 换美术，不改引擎）

在 `res://content/` 放可选文件，引擎启动每场战斗时自动叠加；**没有这些文件则行为完全不变**。

- **`content/units.json`** —— 覆盖或新增单位/建筑。字段级合并：
  ```json
  { "liang_dao": { "hp": 140, "atk": 16 },
    "my_new_unit": { "name": "新兵", "hp": 100, "atk": 12, "cd": 1.0, "range": 26, "speed": 70,
                     "pop": 1, "cost_gold": 50, "trained_at": "barracks" } }
  ```
- **`content/abilities.json`** —— 同理覆盖/新增技能（`cd / radius / effect` 等）。
- **`content/art/<key>.png`** —— 该 key 的贴图覆盖（单位/建筑），优先于内置图集。换皮丢同名 png 即可。

单位/建筑常用字段（详见 `defs.gd` 现有条目）：
`name, hp, atk, cd, range, speed, radius, pop, cost_gold, cost_wood, train_time/build_time,
ranged, cavalry, hero, worker, building, buildable, build_order, garrison_cap, provides_pop,
drop_off, is_main_base, trained_at, produces, researches, trades, min_age, ability, abilities, aura/aura_r/aura_p`。

---

## 4. 引擎用到的「标记字段」（换皮关键）

引擎不写死《水浒》的具体 key，而是认这些 def 标记——你的内容包照标即可：

| 标记 | 含义 |
|---|---|
| `is_main_base: true` | 主基地（「退守基地」「默认目标」等引擎逻辑找它；回退兼容 key=="hall"） |
| `buildable: true` + `build_order: N` | 出现在建造菜单，按 N 排序 |
| `drop_off: true` | 工人卸资源点（聚义厅/仓库） |
| `provides_pop: N` | 提供人口上限 |
| `garrison_cap: N` | 可驻军、容量 N |
| `produces / researches / trades` | 该建筑能训练 / 研究 / 交易 |
| `res_kind` | 资源点（金矿/树），不参与战斗 |

> 仍属内容专属、未抽象的地方：`battle.gd` 里少数英雄的「自动微操 AI 脑」（`_brain_song` 等）按英雄 key 分派，
> 你的新英雄会走通用托管逻辑，不受影响；各 `_*_selftest` / 截图函数引用了具体 key，是测试脚手架，fork 时按需替换即可。

---

## 5. 构建与测试

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
# 关卡冒烟（6×、自动开战、打印 [smoke]/[end]）：
SMOKE_TEST=1 LEVEL=5 $GODOT --path . --headless --quit-after 4000
# 数据关卡冒烟：
SMOKE_TEST=1 SCENARIO="$PWD/scenarios/example_liangshan_defense.json" $GODOT --path . --headless --quit-after 8000
# 建造链路自检：
BUILD_TEST=1 SKIRMISH=1 $GODOT --path . --headless --quit-after 4000
# 全工程解析检查：
$GODOT --headless --editor --quit-after 600
# 导出（预设见 export_presets.cfg）：
$GODOT --headless --path . --export-debug "Android" build/LiangshanHeroes.apk
```
注意：本机 shell 无 `timeout`，靠 `--quit-after <帧>` 兜底；截图需带 GPU（去掉 `--headless`，设 `SCREENSHOT_DIR`）。

---

## 6. 整体换皮（做一款别的游戏）的步骤清单

1. 替换内容：`content/units.json`+`content/abilities.json`（或直接改 `defs.gd`），`content/art/*.png` 换贴图。
2. 标好引擎标记字段（§4），尤其 `is_main_base` 与 `buildable/build_order`。
3. 关卡：用场景编辑器/JSON 做新关；战役关在 `Campaign.LEVELS` 注册。
4. 文案：`scripts/bios.gd`（人物生平）、`scripts/codex.gd`（图鉴）、各关 `intro` 文本。
5. 需要全新机制时再写 `LevelBase` 子类或 scenario 伴生脚本。
