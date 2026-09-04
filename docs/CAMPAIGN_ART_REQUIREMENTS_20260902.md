# 八关实装美术需求清单（2026-09-02）

本清单按当前八个关卡脚本、`Defs.UNITS`、`campaign_art.gd` 与已落盘素材反查生成。它是网页端 ChatGPT 后续出图的任务单，不是“已有素材全部验收通过”的声明。常规移动战斗单位的完整目标为四向 `idle / walk / attack / hurt / down`；剧情人物、建筑和船只只列代码实际需要的专用状态，不把静态物件说成完整动作。

读取时共享目录已有地表/阴影并发改动。本轮的 SHA 清单在仓库外的 `C:\Users\rsb\Desktop\AI项目\水浒\_archive\baselines\art_requirements_baseline_20260902_024451\source_material_mixed_sha256.json`，标记为 **concurrent/mixed observation**，不能说成改动前完整备份。静态合同报告在同目录 `campaign_art_requirements_static_20260902.json`；连续两次输出 SHA-256 相同，说明该报告在相同输入下可重复。没有改渲染、没有生成或裁切图片、没有导出、没有触碰 Steam 目录或上传。

## 统一制作规则

- 新图由网页端 ChatGPT 实际生成；保留原始 PNG、对话链接、完整提示词和 SHA-256。接入只允许透明缝裁切、统一缩放、透明补边和 Godot 导入，不镜像、不本地补画、不把单张平移伪装成 walk。
- 人物四向固定为 `se / sw / ne / nw`。移动切向稳定、攻击起手锁朝向和脚底锚点的代码规则已有时，素材仍须给出真实四向，不以左右翻转补齐。
- `down` 是倒地/昏迷/受制的终态；`unconscious`、`subdued`、`captured`、`retreated`、`embarked` 是剧情结算，不可用普通死亡画面混淆。船只的 `damaged / flooding / disabled` 是物件状态图，不等同人物受击帧。
- 每批只做本表中实际被关卡引用的 key/variant/物件；完成一批后同步记录来源、取舍、哈希、自动合同、视觉 QA 和真人试玩。后三者必须分开表述。

## 关卡需求

| 原著顺序 / 脚本 | 当前代码实际对象与状态 | 下一批需要的美术 |
| --- | --- | --- |
| 野猪林 `level6` / `level6_yezhulin.gd` | 林冲依次为 `lin_chong_prisoner`、`lin_chong_bound`、`lin_chong_escort`；鲁智深 `lu_zhishen_rescue`；董超、薛霸为 escort variant。事件有鲁智深 `intercept`、林冲 `assisted`，两公人结算为 `subdued`。 | 林冲带枷、绑缚、伤臂护送、双人搀扶；鲁智深拦杖；董超、薛霸护送 walk。林冲与搀扶已有较完整专用状态；鲁智深只有 idle/intercept、两公人只有 idle/walk，若允许与玩家战斗，仍需 attack/hurt/down。 |
| 智取生辰纲 `level1` / `level1_huangnigang.gd` | 晁盖、吴用、公孙胜、刘唐、阮氏三雄、白胜均用 `hn_*`；白胜携酒用 `carry_idle/carry_walk`。押运为杨志、虞候、老都管、军汉；中计应为 `unconscious`，强攻分支仍有普通倒地。物件为 `tribute_load`、`jujube_cart`、`wine_buckets`、`wine_bowls`。 | 八名布衣客 idle/walk，白胜肩挑酒桶两状态；押运方行军、交战、受击、昏迷/down。纲担、枣车、酒桶/酒碗必须与“饮酒—麻倒—搬走”流程对应，不能画成歼灭守卫。 |
| 醉打蒋门神 `level7` / `level7_kuaihuolin.gd` | 武松 `wu_song_mengzhou`，蒋门神 `jiang_menshen_fists`；`roadside_tavern`、`heyang_tavern` 和招牌。蒋门神结算为 `subdued`；有 `windup` 和酒店恢复事件。 | 武松徒手 idle/walk/attack/hurt/down；蒋门神蓄拳、冲撞、受制/向后倒地告饶；沿途酒肆、快活林大酒店和恢复招牌。核心拳脚五状态目前相对完整，后续优先补事件姿态和场景物件。 |
| 江州劫法场 `level2` / `level2_jiangzhou.gd` | 宋江、戴宗先为 `*_bound`，获救后为 `*_rescued`，并以 `embarked` 结算；援军含晁盖、李逵、花荣、燕顺、梁山刀弓，官军含刽子手、牢子、蔡九、后续刀弓。物件有白龙庙、刑台、快船/栈桥。 | 被缚 idle、获救 idle/walk、登船转移；救援/官军完整战斗状态；白龙庙、法场、岸船和栈桥。`jiangzhou_scaffold` 已明确路由到现有通用 `scaffold`，本轮不把它冒充独立网页刑台美术。 |
| 三打祝家庄 `level3` / `level3_zhujiazhuang.gd` | 三日重部署：第一日探路，第二日擒扈三娘，第三日孙立内应、开门救囚。祝家门为 `subdued`；扈三娘为 `captured`。七囚被缚后才恢复战斗。 | 三段不同兵力/环境的衔接图，扈三娘被擒/押送，孙立与顾大嫂内应，开门/救囚。六个缺失的 `bound_*` 已补为严格人物归属的程序绳缚覆盖，不再串用石秀造型；这只是兼容表现，后续专用网页素材仍按需求批次制作。 |
| 大破连环马 `level4` / `level4_lianhuanma.gd` | 演练有徐宁、汤隆、钩镰枪手和 `hook_training_dummy`；决战有 12 钩镰兵、12 连环马、韩滔（`captured`）与呼延灼（`retreated`）。物件/事件图有 `hook_spear_team`、`linked_cavalry`、`broken_cavalry`。 | 钩镰协同移动/攻击/受击/倒地，连环马行进/冲锋/受击/破阵，徐宁操练、汤隆诱骑与破阵事件姿态。普通四向目录主要只有钩镰与连环马 idle，不能把事件插图当作单位动作。 |
| 智取大名府 `level8` / `level8_dongchangfu.gd` | 潜入三人是 `shi_qian_lantern`、`chai_jin_officer`、`yue_he_officer`；卢俊义、石秀由 `daming_bound_*` 切为 `daming_rescued_*`，获救后撤离。场景有 `daming_south_gate`、`cuiyun_tower` 的 `signal`、`prison_gate` 的 `open`、灯市百姓。 | 伪装潜行、举火、解枷、获救步行、百姓惊逃；牢门/城门、翠云楼火号和灯市。伪装三人目前只有 idle；获救二人已有 idle/walk，尚未补完整战斗动作是合理的，因为代码将其设为非战斗撤离角色。 |
| 三败高太尉 `level5` / `level5_liangshan.gd` | 水军真实 key 为阮氏三船、刘唐火船、张顺小艇、梁山战船、官军战船、`official_vanguard`、`gao_flagship`，均为 `movement_profile="water"`。高俅最终为 `gao_qiu_captured`；船有撤离、失能、凿船、救人与俘虏路线。 | 船只真实四向静态状态：官船/先锋/高俅座船 `default/damaged/flooding/disabled`，梁山船 default；其后才考虑划行/攻击动效。另需张顺凿船、火船撤离、落水救人、高俅湿衣束手。先锋头船双旗为第八十回编制旗文，普通官船保持无文字；不得把旗文做成个人姓名旗。 |

## 当前素材清点与文档对账

| 范围 | 当前实数 | 处理结论 |
| --- | ---: | --- |
| `assets/direction4/manifest.json` | 6 个来源、96 个输出 | 20 类普通单位四向 idle 为 80，另有虞候/老都管各四向 idle + down 共 16。旧文档仍写 80 且说二人未覆盖，须标为过期历史数。 |
| `assets/direction4/campaign_object_manifest.json` | 4 个来源、48 个输出 | 高俅座船 16、先锋头船 16、官船 12、梁山船 4。它只是四向物件批次，不等于整个物件目录。 |
| 运行目录 | `campaign/anim` 300、`campaign/objects` 72、`campaign/portraits` 36、通用 `assets/anim` 464 PNG | 当前总数应以目录为准；不可用网页批次或旧合同数代替。 |
| `web_art_manifest.json` | 16 个网页来源、129 个 artifact | 只覆盖网页批次，和 72 张当前物件不是同一统计范围。 |
| `motion_contract_qa.json` | 历史 188 条帧带 / 312 帧 / 22 物件 / 20 variant | 保留为当时合同证据，不能被回写成当前总库存。 |

静态合同目前检查：八个注册关卡和脚本存在、字面 spawn key 可解析为全局或关卡局部定义、四向角色/物件 manifest 的落盘文件及哈希、网页清单产物与来源哈希。它不跑 Godot；自动合同通过后仍需要编辑器导入、1280×720视觉 QA 和真人试玩分别复核。

## 严格四向覆盖门禁（更新于 2026-09-02）

`tools/campaign_direction4_coverage_audit.py` 进一步把八关实际部署拆成 444 条逐关需求和 347 个唯一人物/变体/状态，并拒绝连通块归属、清除相邻人物像素或来源不完整的旧成品。`qa/campaign_direction4_coverage_20260902/report.json` 当前认可 13 项（3.746%）；71 项有四向文件但来源处理不合规，263 项缺失或方向不全。理论最少需 84 张四行网页图，首批八类样板 10 张，其余 74 张。

其中喽啰、梁山朴刀、长枪和弓手 idle 已从具备完整透明分隔带的原网页图重新按整格矩形裁切，格内像素零清除；改前 16 张及 manifest 已单独保存。其余旧图透明分隔带不满足整格裁切，不作为最终来源，必须网页重生。该覆盖报告只证明来源和文件门禁，未替代 Godot 导入、1280×720近景、动作防抖、性能或真人试玩。
