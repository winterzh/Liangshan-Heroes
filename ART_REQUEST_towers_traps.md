# 美术委托：防御塔 + 陷阱（水浒英雄传 / Liangshan-Heroes）

> 把这个文件交给 Codex（或任意能按提示词出图的工具）。按下面的提示词出图 → 按**指定文件名**保存 → 压成一个 zip。
> 之后把 zip 给我（Claude），我负责抠绿幕、切图、放进 `res://assets/` 并重新导入测试。

---

## 0. 统一风格（所有图通用）

- **画风**：中国宋代《水浒》工笔淡彩 **卡通**，**粗而干净的深色描边**（cel-shaded gongbi cartoon），和本项目现有单位/建筑同一套。
- **视角**：**3/4 俯视等距**，完全照《帝国时代2 (AoE2)》的建筑/地面物件视角（不是正侧、不是纯正俯视）。
- **背景**：**纯平涂的纯绿幕**（chroma key green，`#00B140`），**不要渐变、不要花纹、不要绿色地面阴影**。物件下方可有极淡的接地投影，但主体周围必须是干净的纯绿，方便抠像。
- **排版**：按要求的网格（2×2 或 3×3）平均分格，**每个物件居中**、四周留出充足绿色边距，**格与格之间不要画网格线/边框/文字/标签**。
- **尺寸**：正方形输出，建议 **1024×1024**（3×3 那几张建议 **1536×1536** 或 1024×1024 亦可），网格铺满画面。
- **一致性**：同一张图里的多个物件要**同一比例、同一光照方向**。

---

## 1. 必做：两张 2×2 图集

### 1.1 陷阱图集 → 文件名 `traps_raw.png`

一张 **2×2** 网格，纯绿幕底，四个**俯视地面陷阱**各占一格：

- **左上**：滚木礌石 —— 几根捆扎的粗木与灰色巨石堆在一起、像随时会滚下，带绳索。
- **右上**：陷坑 —— 棕土里挖的坑，坑内朝上的削尖竹签，坑沿散落几根伪装树枝。
- **左下**：火油（猛火油）—— 地面上深色发亮的油渍 + 两个圆陶油罐，淡暖琥珀反光，几点火星。
- **右下**：备用 —— 散落一地的黑铁蒺藜（铁蒺藜/caltrops）。

> 英文提示词（直接喂给出图工具）：
> ```
> A 2x2 grid of four separate Song-dynasty Chinese tower-defense TRAP objects, traditional gongbi ink-and-color CARTOON style with bold clean dark outlines, each object centered in its own cell on a FLAT PURE GREEN background (chroma key green #00B140), viewed from a 3/4 top-down isometric angle like Age of Empires 2 ground props, soft top-down lighting, NO text, NO labels, NO grid lines, generous green margin around each object.
> Top-left: a rolling-logs-and-rocks trap — several thick lashed wooden logs stacked with grey boulders, rope bindings, ready to roll.
> Top-right: a covered pit trap — a dug hole in brown earth with sharpened bamboo stakes pointing up, a few camouflage branches around the rim.
> Bottom-left: a fire-oil (naphtha) trap — a dark glistening oil slick with two round clay oil pots, faint warm amber sheen, a couple of embers.
> Bottom-right: a cluster of black iron caltrops scattered on the ground.
> Consistent muted Song-dynasty palette: earth browns, weathered wood, grey stone, dark oil. Same scale and lighting; each reads clearly as a ground trap seen from above.
> ```

### 1.2 新防御塔图集 → 文件名 `towers_raw.png`

一张 **2×2** 网格，纯绿幕底，四座**防御塔建筑**各占一格（AoE2 建筑视角）：

- **左上**：霹雳炮 —— 木石攻城台上架一门粗短铁制火药炮（宋代霹雳炮），有排烟孔。
- **右上**：五雷法坛 —— 抬高的石木法坛塔，飞檐瓦顶，黄色道符旗幡，**塔尖悬一颗发光的紫色雷球**。
- **左下**：拒马 —— 低矮木寨，环绕捆扎的尖木拒马（cheval de frise）和铁蒺藜，中间一个小瞭望台。
- **右下**：备用 —— 一座朴素的灰石木顶瞭望塔。

> 英文提示词：
> ```
> A 2x2 grid of four separate Song-dynasty Chinese defensive TOWER buildings, traditional gongbi ink-and-color CARTOON style with bold clean dark outlines, each building centered in its own cell on a FLAT PURE GREEN background (chroma key green #00B140), viewed from a 3/4 top-down isometric angle EXACTLY like Age of Empires 2 buildings, soft top-down lighting, NO text, NO labels, NO grid lines, generous green margin around each building.
> Top-left: a "thunderclap bombard" tower — a square timber-and-stone siege platform with a stout iron gunpowder bombard cannon on top, smoke vents.
> Top-right: a Taoist "five-thunder altar" tower — a raised stone-and-wood altar pagoda with peaked tiled roof, yellow Taoist talisman banners, and a glowing PURPLE orb of crackling lightning floating just above its peak.
> Bottom-left: an anti-cavalry barricade tower — a low timber fort ringed with lashed wooden spike frames (cheval de frise) and iron caltrops, a small watch platform in the middle.
> Bottom-right: a plain grey stone watchtower with a wooden roof.
> Consistent muted Song-dynasty palette: weathered timber, grey stone, dark iron; the altar's purple glow is the only bright accent. All four same scale and lighting.
> ```

---

## 2. 可选·进阶：四张「塔的八方向开火」3×3 图

> 塔不能移动，用**转向**表达瞄准/开火。每座塔出一张 **3×3** 图：**同一座塔画 9 次**，只有炮口/法杖/雷球的**朝向**变化。
> 做了这个就比 1.2 的静态塔更好；不做也行（我有程序化转向炮管兜底，1.2 已够用）。
> **关键**：9 格里必须是**同一座塔、同一比例、同一配色**，只转武器方向，否则会看着像 9 座不同的塔。

3×3 各格的**朝向 = 该格相对中心的方位**（炮口指向该格所在的方向）：

```
左上=西北   上=正北     右上=东北
左 =正西    中=待机/正面  右 =正东
左下=西南   下=正南     右下=东南
```

- **中心格**：塔静止/正面（也用作 HUD 头像）。
- **其余 8 格**：塔朝该格方位开火（炮口/法杖/雷球指向外侧那个方向）。

文件名（四张）：

| 塔 | 文件名 | 该塔武器（转向的部分） |
|---|---|---|
| 箭楼 | `tower_arrow.png` | 弓弩手/箭口朝向目标 |
| 霹雳炮 | `tower_thunder.png` | 铁炮炮口朝向目标 |
| 五雷法坛 | `tower_altar.png` | 紫色雷球/法杖朝向目标 |
| 拒马 | `tower_caltrop.png` | 抛索/钩镰朝向目标（伤害低，可弱化武器，主要是转向） |

> 英文提示词模板（**每座塔替换 `<TOWER DESCRIPTION>` 与 `<WEAPON>`**）：
> ```
> A 3x3 sprite sheet of the SAME single Song-dynasty Chinese defensive tower drawn nine times, traditional gongbi ink-and-color CARTOON style with bold clean dark outlines, on a FLAT PURE GREEN background (chroma key green #00B140), 3/4 top-down isometric angle like Age of Empires 2, NO text, NO grid lines, even spacing, generous green margin per cell.
> The tower is: <TOWER DESCRIPTION>.
> It is IDENTICAL in all nine cells (same building, same scale, same colors, same lighting) — ONLY its <WEAPON> rotates to aim in a different compass direction per cell, pointing toward that cell's position relative to the center:
> top-left aims NORTH-WEST, top-center aims NORTH, top-right aims NORTH-EAST, middle-left aims WEST, CENTER cell is at rest facing the viewer, middle-right aims EAST, bottom-left aims SOUTH-WEST, bottom-center aims SOUTH, bottom-right aims SOUTH-EAST.
> Consistent muted Song-dynasty palette.
> ```
> 各塔填空：
> - 箭楼：`<TOWER DESCRIPTION>` = a two-story wooden arrow watchtower with tiled roof；`<WEAPON>` = crossbow/arrow slit
> - 霹雳炮：`<TOWER DESCRIPTION>` = a timber-and-stone bombard platform with an iron gunpowder cannon；`<WEAPON>` = iron cannon barrel
> - 五雷法坛：`<TOWER DESCRIPTION>` = a Taoist five-thunder altar pagoda with yellow talisman banners and a glowing purple lightning orb；`<WEAPON>` = floating purple lightning orb / Taoist staff
> - 拒马：`<TOWER DESCRIPTION>` = a low timber anti-cavalry barricade fort with wooden spikes and caltrops；`<WEAPON>` = throwing hook/rope

---

## 3. 最终文件清单 + 打包要求

把生成的 PNG **按下表文件名命名**，放在 zip **根目录**（不要套子文件夹），zip 命名为 **`liangshan_art.zip`**：

**必做：**
- `traps_raw.png`  （2×2，第 1.1 节）
- `towers_raw.png` （2×2，第 1.2 节）

**可选·进阶（做了 §2 就一并放进去）：**
- `tower_arrow.png`、`tower_thunder.png`、`tower_altar.png`、`tower_caltrop.png` （各 3×3，第 2 节）

打包命令（macOS/Linux）：
```sh
zip -j liangshan_art.zip traps_raw.png towers_raw.png \
    tower_arrow.png tower_thunder.png tower_altar.png tower_caltrop.png
```
> `-j` = 不带路径、扁平打包。可选文件没做就从命令里删掉对应名字。

**验收要点（出图时自检）：**
- 背景是干净的纯绿 `#00B140`，物件四周有绿边距、彼此不粘连。
- 2×2 / 3×3 分格均匀、每格物件居中。
- 同一张图里比例/光照一致；3×3 里是同一座塔只转武器方向。
- 无文字、无网格线、无水印。

---

## 4. 交付后我（Claude）会做什么（你不用管，仅备注）

1. 解压 `liangshan_art.zip` 到隔离目录 `/tmp/cgtt/`。
2. 跑 `tools/cut_anim.gd`（绿幕抠像 + 切片）：`traps_raw.png → res://assets/traps.png`、`towers_raw.png → res://assets/buildings2.png`。
3. 若有 3×3：用 grid=3 切成 `res://assets/tower_*.png`（我会补一个 grid3 切割分支）。
4. `--headless --import` 导入 → 解析检查 → 跑 `TOWERTRAP_TEST` 烟囱测试。
5. 代码侧的美术槽位（`BUILDING2_CELLS` / `TRAP_CELLS` / `TOWER_DIR_SHEETS`）已经全部接好，图一就位就自动替换掉当前的程序化占位，无需再改代码。

> 文件名/格子顺序对应（务必一致，否则图会装错位置）：
> - `traps_raw.png`：左上=滚木礌石、右上=陷坑、左下=火油、右下=备用
> - `towers_raw.png`：左上=霹雳炮、右上=五雷法坛、左下=拒马、右下=备用
