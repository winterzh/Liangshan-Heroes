# Scenario 格式（数据驱动关卡）

一份 scenario 就是一个 JSON 字典，由 `scripts/levels/scenario.gd`（`LevelBase` 子类）解释执行，
把地图 / 地形 / 装饰 / 布兵 / 波次 / 胜负全部从数据喂给战斗运行器 `Battle`。

加载途径：
- **编辑器试玩 / 分享码**：把字典塞进 `Campaign.scenario_data` 并置 `Campaign.scenario = true`。
- **环境变量（headless/调试）**：`SCENARIO=/abs/path/to.json`，菜单会自动进入战斗。

完整可运行示例见 `scenarios/example_liangshan_defense.json`（即第 5 关「梁山泊保卫战」的纯数据移植）。

---

## 顶层字段

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `id` | string | `"scenario"` | 关卡 id |
| `title` / `subtitle` | string | — | 标题 / 副标题 |
| `map` | object | — | 见下「地图」 |
| `camera_start` | `[x,y]` | 地图中心 | 开局镜头中心格 |
| `deploy_hint` | string | 默认提示 | 布阵阶段提示文字 |
| `intro` | array | `[]` | 开场剧情，元素 `{who, key, text}`（`key` 是头像键） |
| `economy` | bool | `false` | 是否开经营（采集/建造/训练） |
| `start_gold` / `start_wood` | int | `0` | 起始资源（`economy` 为真时生效） |
| `pop_cap` / `hero_cap` | int | `0` | 人口上限 / 英雄上限（0=不限） |
| `fog` | bool | `false` | 战争迷雾 |
| `start_age` | int | `3` | 起始时代（1 草莽 / 2 聚义 / 3 替天行道；3=全解锁） |
| `terrain` | array | `[]` | 地形绘制指令，见下 |
| `decor` | array | `[]` | 装饰物 `["贴图键",[x,y],尺寸]` |
| `deploy` | array | `[]` | 初始布兵，见下 |
| `gates` | object | `{}` | 命名出兵口 `{"E":[x,y], ...}` |
| `target` | `[x,y]` | ref `hall` 或镜头中心 | 波次进攻目标点 |
| `wave_faction` | string | `"GUAN"` | 波次单位阵营 |
| `wave_gap` | float | `8.0` | 波与波默认间隔秒 |
| `waves` | array | `[]` | 敌方波次，见下 |
| `start_msg` / `wave_gap_msg` | string | — | 开战提示 / 波间提示 |
| `win` / `lose` | array | 见「胜负」 | 胜 / 负条件（任一满足即结算） |
| `script` | res 路径 | — | 可选伴生 .gd，处理纯数据表达不了的定制逻辑 |
| `units` | object | `{}` | **本场景单位覆盖/新增**（魔兽编辑器式，仅本场景生效）；`{"<key>": {字段...}}` 字段级合并进本场 _defs |
| `abilities` | object | `{}` | **本场景技能覆盖/新增**；`{"<id>": {name,cd,radius,targeted,weak_global,passive,effect{...}}}` |
| `sprite_alias` | object | `{}` | 新建单位借用现有单位的贴图/动画：`{"新key": "现有key"}` |

> `units`/`abilities` 用「场景编辑器 → 🛠 单位/技能」可视化编辑：改任意单位/技能的全部参数、
> 新建单位(复制现有为模板并自动借美术)。所有改动只写进本场景 JSON，**不动全局**，别的关卡/模式不受影响。

### 地图 `map`
```json
{ "w": 60, "h": 60, "theme": "marsh", "base": "WATER" }
```
`base` 为地形名（见下）。`theme` 影响美术混色风格。

### 地形名（`t` / `base` / `of` / `into` / `only` 取值）
`WATER SHORE MARSH REEDS GRASS ROAD FOREST HALL DRYHILL CLIFF TOWN PLAZA FIELD PLAIN DOCK`
（`HALL` 是「地基」：渲染同草地但不可通行，用来垫在建筑下面。也可填整数枚举值。）

### 地形指令 `terrain[]`
按顺序执行，后面的覆盖前面的。`only` 可选——只在指定地形上落笔。
```json
{ "op": "fill_ellipse", "c": [20,30], "rx": 19, "ry": 16, "t": "MARSH" }
{ "op": "fill_rect",    "x": 15, "y": 29, "w": 3, "h": 3, "t": "HALL" }
{ "op": "paint_path",   "pts": [[59,22],[42,22],[20,30]], "brush": 1, "t": "ROAD" }
{ "op": "scatter",      "of": "MARSH", "into": "REEDS", "density": 6, "seed": 0 }
{ "op": "set_cell",     "c": [16,30], "t": "HALL" }
{ "op": "fill_ellipse", "c": [36,25], "rx": 3, "ry": 2, "t": "REEDS", "only": ["MARSH"] }
```

### 布兵 `deploy[]`
```json
{ "key": "hall", "faction": "LIANG", "cell": [16,30], "ref": "hall" }
```
- `faction`：`LIANG`（梁山/玩家）或 `GUAN`（官军/敌）。
- `ref`（可选）：给这个单位起个名字，供胜负条件 `ref_dead`/`ref_alive` 引用（如基地、护送目标）。

### 波次 `waves[]`
```json
{
  "msg": "官军先锋已上长堤！",
  "delay": 6.0,
  "groups": [
    { "key": "guan_dao", "n": 6, "gate": "E" },
    { "key": "gao_qiu",  "n": 1, "gate": "E", "ref": "boss" }
  ],
  "reinforce": {
    "msg": "芦苇荡伏兵杀到！",
    "units": [ { "key": "lin_chong", "faction": "LIANG", "cell": [33,40] } ]
  }
}
```
- 第 0 波在开战后 `delay` 秒出；之后每波在**上一波被全歼后**等 `delay`（缺省 `wave_gap`）秒出。
- `gate`：命名出兵口字符串，或直接写 `[x,y]`。
- `groups[].ref`：给波次里某单位起名（常用于 boss）。
- `reinforce`（可选）：该波触发时额外刷一批单位（任意阵营），常用于"援军杀到"。

### 胜负 `win[]` / `lose[]`
每帧检查；**先判 `win` 再判 `lose`**（击杀/守关优先于全军覆没）。任一条件满足即结算。
省略时给默认值：有波次 → 胜=`survive_waves`、负=`no_army`；无波次 → 胜=`kill_all`、负=`no_army`。

| `type` | 含义 |
|---|---|
| `survive_waves` | 所有波次出完且场上无敌人 |
| `kill_all` | 场上无敌人（无波次的歼灭战） |
| `no_army` | 我方可动单位为 0 |
| `ref_dead` + `ref` | 某个已出场的 ref 单位死亡（守关用在 `lose`、斩首用在 `win`；未出场不误判） |
| `ref_alive` + `ref` | 某 ref 单位存活 |
| `timer` + `t` | 开战满 `t` 秒（限时胜/负、坚守 N 秒） |
| `hook` + `name` | 交给伴生脚本 `cond(b, name, scenario)` 判定 |

每个条件可带 `msg` 作为结算台词。

---

## 伴生脚本 `script`（定制那 20%）

纯数据表达不了的机制（指路、专属技能、特殊胜负、阶段事件等）写一个伴生 `.gd`，
在 scenario 里 `"script": "res://scenarios/my_hooks.gd"`。它可实现以下任意子集，签名都带 `s`（scenario 实例）：

```gdscript
func deploy(b, s) -> void           # 布兵后追加
func on_start(b, s) -> void         # 开战时
func process(b, delta, s) -> void   # 每帧（波次系统照常跑，这里加自定义）
func on_wave(b, i, s) -> void       # 第 i 波刷出后
func on_unit_died(b, u, s) -> void  # 单位阵亡
func on_ability(b, caster, ability_id, lp, s) -> bool   # 关卡自定义技能，处理了返回 true
func top_status(b, s) -> String     # 顶栏文字（返回非空则覆盖默认）
func cond(b, name, s) -> bool       # 供 win/lose 里的 {"type":"hook","name":...} 调用
```
可读写 `s._refs`（ref 名→Unit）、用 `b.spawn_at/spawn_group/msg/win/lose` 等 Battle API。
