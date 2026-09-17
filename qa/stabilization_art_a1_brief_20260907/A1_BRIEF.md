# A1 制作依据 · 2026-09-07

本批先补宋江四向独立受击，再修现有动作中可指认的问题。**不重做整套宋江或林冲。** 这份材料没有生成、上传、改生产或启动 Godot。

本轮实际用 `view_image` 看了全部 22 张当前生产原生 PNG、4 张身份参考及 2 张 2026-09-06 历史运行矩阵；22 张 PNG 的实际 SHA256 均与当前 manifest 一致。精确路径、SHA、原始采样矩形、脚锚及候选输入见 [inputs.json](inputs.json)，40 个“角色×状态×方向”逐项见 [current_states.csv](current_states.csv)。旧矩阵用于观察，**不是本轮新镜头验收**，也不宣称已经重新验证其全部截图来源绑定。

| 角色 / 状态 | SE | SW | NE | NW | 当前实际序列 |
|---|---|---|---|---|---|
| 宋江 idle | TRES | TRES | TRES | TRES | idle |
| 宋江 walk | TRES | TRES | TRES | TRES | idle → walk |
| 宋江 attack | TRES | TRES | TRES | TRES | idle → attack → idle |
| 宋江 hurt | 缺 | 缺 | 缺 | 缺 | 精确/旧无向 hurt 都没有 |
| 宋江 death | TRES | TRES | TRES | TRES | idle → fall → down → down |
| 林冲 idle | TRES | TRES | TRES | TRES | idle |
| 林冲 walk | TRES | TRES | TRES | TRES | idle → walk_a → idle → walk_b |
| 林冲 attack | TRES | TRES | TRES | TRES | windup × 2 → thrust × 2 → idle |
| 林冲 hurt | TRES | TRES | TRES | TRES | hurt |
| 林冲 death | TRES | TRES | TRES | TRES | hurt → fall → down → down |

现有 36 项均由同名 TRES 提供，没有优先级更高的同名四向 PNG。宋江受击调用见 `scripts/unit.gd:3744`；该分支只取 `hurt[0]`，而 `scripts/art_db.gd:677` 的缺动作回退会返回同向 idle，因此这次需要 4 个明确受击姿态，不需要先画长受击动画。

## 按次序交付的候选

1. **SJ-HURT-4，先做 4 姿态。** 逐方向以 `assets/characters/song_jiang_direction4_20260906/idle_<方向>.png` 为主要参考，身份辅以现有 `candidates/song_jiang.png`。胸肩遭击后小幅后仰、屈膝仍站立；剑继续握在解剖右手，左手空，保持金袍/黑围巾/左髋青绿穗带。NE/NW 保持背身，不能转成正脸。现有 fall 四图已是失衡跪倒且剑落地，不能拿来冒充普通受击。
2. **SJ-NW-IMPACT-1，定点新增 1 姿态。** 当前 `attack_nw.png` 是剑举过头的蓄力轮廓；其序列又只有 idle/该图/idle，没有另一幅实际挥出图。保留当前图作为蓄力候选，以 `idle_nw.png` 固定身份、`attack_ne.png` 只参考伸展动作，补向 NW 真正挥出/斩出的接触姿态。不得镜像 NE；SE/SW/NE 攻击继续保留。
3. **SJ-WALK-B-4，补 4 个反腿姿态。** 四向现序列只有站姿和单个迈步姿态，缺独立的另一条腿迈步图。保留已选迈步为 A，只增加 B；人物躯干宽度、袍纹和剑手不能随迈步换人。SE/NE/NW 的 A 来自 `walk_atlas.png`；**SW 的有效 A 是独立 `walk_sw.png`，不是 atlas 的右上图。** 采样范围已写入 JSON。候选验收后再决定节奏，不为增加帧数重画 idle。
4. **LC-NW-WALK-B-1，先核对再决定出图。** `nw.png` 的 A 区 `[632,64,254,307]` 与 B 区 `[124,427,268,289]`，静态轮廓都主要呈画面左侧脚向前，反腿辨识偏弱。这是静态疑点，不宣称已经看过慢放；确认同腿后仅替换 B 为明确反腿，保留 A、idle、攻击、hurt、death。
5. **LC-SW-NE-WALK-COSTUME-4，暂不直接下生成单。** `sw_walk.png`/`ne_walk.png` 的独立步态对比同向 `sw.png`/`ne.png` 的 idle，躯干宽窄、铠甲分片和腰带细节有变化；历史小尺寸矩阵中也能看出形体变化，但需要当前正常镜头确认是否值得修。若可见，只修这两方向各 A/B，共 4 姿态，保留已成立的反腿关系。manifest 已明确 **SE/NW 双手架枪，SW/NE 右手持枪**，不能把 SW/NE 的单手姿势误列成新缺陷。

前 3 项共 **9 个新姿态候选**；第 4 项最多 1 个定点替换，第 5 项最多 4 个条件候选。这些均不是已接入数量。已有 idle、林冲 attack/hurt/death、宋江 death 没有列入整批重制。

## 准入与镜头验收

- 来源：生成前使用 JSON 中对应文件的实际 SHA；每次保留提示词、工具产物标识、引用链、原生输出与 SHA。保留未选版本，不能覆盖旧 manifest 原文或按“来源修复”替换生产图。接入新版本时更新原生来源门禁的明确版本，不能放宽 SHA 检查。
- 动作：逐格核对完整头冠、剑尖/枪尖、脚和真透明留白；四向真实旋转，持械手与服饰一致；迈步 A/B 必须能辨认反腿，攻击必须有伸展接触姿态，hurt 不跪倒/掉武器，death 末帧保持倒地。依项目约定不镜像、不脚本补画。
- 合成：原图预览中的棕色/灰色不能直接当作不透明背景。实测林冲 `se.png` 的 `(512,768)=(21,9,6,0)`、宋江 `down_atlas.png` 的 `(768,512)=(95,71,43,0)`，这些颜色藏在零 alpha 中。**不据此批量去背景。** 新候选须在明暗底实际 alpha 合成检查边缘；本轮未制作合成图。
- 运行：先做独立候选图复核，再由根任务按独占窗口接入。固定方向矩阵和正常战斗镜头均须检查：真实受击触发、攻击伤害与画面时机、连续迈步/停步、转向不换手、脚锚无跳动、死亡停留。保留未修改状态的前后对照及新源 SHA；矩阵通过不替代动态检查。正常比例下才可判定林冲服装跳变是否需要上述条件修订。

## 后续两角色只附身份参考

- 孙立：`qa/character_direction4_inventory_20260905/candidates/sun_li.png`，已查看的现有小原画是黑金甲、棕袍、背弓的步行人物。`tools/contracts/sun_li_direction4_draft_20260906/generation.json` 保存的是**未接入草稿**；README 说明其中黑马、右手钢鞭属于尚待完成的设计选择。这里没有选中它的 36 张图，也不能当作已验收四向。
- 扈三娘：`qa/character_direction4_inventory_20260905/candidates/hu_sanniang.png`，已查看：绿裙银甲、双刀、棕马。后续先锁定骑乘身份、双刀和马具，不改成步行人物；此处仅附既有身份图的路径与 SHA，没有新增生成范围。

两张小原画的既有更早来源没有在本轮重新追溯；不能把“可作为身份参照”写成新来源链已获验收。
