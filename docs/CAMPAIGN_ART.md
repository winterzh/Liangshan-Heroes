# 战役专用美术交接

2026-08-31。此前批次使用内置 image_gen 实际生成并接入，未调用 API/CLI 付费后备；用户后续明确要求改用网页ChatGPT，新增网页批次由主任务操作浏览器，独立切片记录如下。源图保存在 `assets/campaign/source/`，该目录有 `.gdignore`，运行时只用 `anim/`、`objects/`、`portraits/`。完整提示词、淘汰原因见 `assets/campaign/generation_manifest.json`；后续人物补帧见其引用的 `motion_generation_manifest.json` 和 `constable_generation_manifest.json`。

## 2026-09-02 图鉴素材复用复核

英雄图鉴不是只有头像：`scripts/codex.gd`会直接读取`assets/anim/<key>_walk.png`和`<key>_attack.png`。重新交叉八关需求后，347个唯一人物/状态中有95项已经存在四方向文件，其中37项已满足当前严格来源合同，另58项先做视觉、原著和来源复核，不因旧记录不完整就立即重画。其余252项中，124项已有同人物同动作的图鉴单视角帧带，可以上传给网页版ChatGPT作为造型和动作参考；128项才是没有同状态原图、需要从零制作。

图鉴里的1024×256横条通常是同一视角的四个动作帧，不是四个方向，所以不能直接把`walk/attack/idle/death`横条登记为真四向完成。但允许从现有原图做连续矩形取帧，或作为网页参考补足真实`se/sw/ne/nw`，不再重复设计脸、服装和武器。通用李逵虽已有五状态四方向，但穿黑褐上衣，只保留给其他模式；江州法场“赤条条”的章节造型仍需独立`li_kui_jiangzhou`，图鉴图只能参考脸、体型和板斧。按缺方向项计算，四行网页图集的理论最低量由78张降为63张；旧四向复核不通过以及新增章节variant的项目另计。当前复核清单和四张总览位于`qa/campaign_direction4_reuse_audit_20260902/`。高俅帅船等带旗文字的旧图仍须单独检查网页空旗面与运行时文字是否分离，不能因文件齐全自动采用。

### 2026-09-03 普通官军、公差与庄客九项生产替换

原58项中的九项 `WEB_REGENERATE_REFERENCE_OK` 已重画并接入：柴进、乐和公人伪装，刀盾官军、弓手、骑枪兵，江州刽子、押牢，黄泥冈挑担军汉和祝家庄客。造型分别依据百二十回本第十六、四十、四十七至四十八、六十六回，避免把公人画成将领、把军汉画成常备重甲或把庄客画成精锐军官。四张原图先在网页执行 `alpha<=15` 精确归零并验证其余RGBA逐字节不变；本地只做固定单元格内连续矩形裁切、人物级统一等比缩放和透明补边。36张四向idle与两张头像均有生产清单和覆盖审计。

Godot重新导入38个文件；战役美术160项、动作74项、四向回归63项、大名府渗透50项通过。专项真实Vulkan渲染77项、3张1280×720同屏图通过，完整大名府图形流程129项、12张图通过。人工复核未见错向、串行、武器侵入、棋盘底或邻格碎片。严格来源覆盖更新为`85/347`，原58项完成43项、剩15项；详情与回滚证据见`qa/ordinary_officials_p0_direction4_production_20260903/`。这些结果不代表完整八关真人通关或性能验收，Steam目录未修改。

### 2026-09-03 大名府获救卢俊义两项生产替换

原58项中的 `daming_rescued_lu_junyi idle/walk` 已整套重画并接入。百二十回本第六十六回明确柴进开枷放出卢俊义、石秀，卢俊义随后能够引人回家并在天明会合，因此本批只把“开枷后无枷无绳、能够移动”作为正文硬边界；灰白长袖旧布衣、深灰裤、鞋袜和黑髯发髻用于保持游戏同一人物连续，不冒充逐字原文。新图不提前添加铠甲、官服、披风、马或武器。

采用源为1224×1285 RGBA三行四列：`idle/walk_a/walk_b × se/sw/ne/nw`。网页端仅执行 `alpha<=15` 精确归零，`alpha>15` 逐字节不变；本地独立复验后，只在固定格内作连续矩形裁切、十二格共用等比缩放、透明补边及两帧横排。8张动画与1张头像有生产前备份和来源清单，没有镜像、补画、遮罩或连通域清除。

Godot重新导入9项；战役美术160项、动作74项、四向回归63项、大名府渗透50项通过。专项真实Vulkan渲染38项覆盖三行四方向和头像；完整大名府图形流程129项、12图再次通过，实拍确认解救前仍戴颈枷，真实开锁后同一角色换成无枷造型并实际播放两张不同走姿。严格来源覆盖更新为`87/347`，原58项完成45项、剩13项；完整来源、回滚和视觉证据见`qa/daming_lu_rescued_p0_direction4_production_20260903/`。这些结果不代表完整八关真人通关或性能验收，Steam目录未修改。

### 2026-09-03 江州法场宋江、戴宗六项生产替换

原58项中的 `song_jiang_bound/rescued idle/walk` 与 `dai_zong_bound/rescued idle/walk` 六项已重画并接入。百二十回本第四十回明确戴宗受拷后加枷，二人被缚、头发绾成鹅梨角并插红纸花，临刑前才开枷；劫法场后被背走，至白龙庙方醒。因此被缚图使用法场颈枷、捆缚、鹅梨角和红纸花，获救图才去枷去绳；宋江米白囚衣、戴宗灰褐短衣，同一人物前后保持面貌与衣色。用户要求的“手套进枷孔”在采用的前侧方向明确成立，其余方向也不以手臂覆盖枷面糊弄。

四张采用源分为被缚/获救待机底图与获救四帧步行图。两轮网页版ChatGPT只执行 `alpha<=15` 精确归零，`alpha>15` RGBA逐字节不变；本地只做固定格内连续矩形裁切、每个人跨两张源共用等比缩放、透明补边和横排，不镜像、不补画、不遮罩、不按连通域擦像素。生产共24张动画条带与4张头像，获救walk每个方向均为四张真实姿态，生产前28文件已完整备份。

Godot重新导入28项；战役美术160项、动作74项、四向回归63项、江州纵深29项均通过。专项生产合同213/213，真实1280×720 Vulkan渲染148/148；另从正常HUD启动并由既有任务动作推进至白龙庙阶段，实拍确认宋江、戴宗已切换获救造型并实际行走。严格来源覆盖更新为`93/347`，原58项完成51项、剩7项；来源、回滚、合同和视觉证据见`qa/jiangzhou_prisoners_p0_direction4_production_20260903/`。这些结果不代表完整八关真人通关、战斗高峰或长时性能验收，Steam目录未修改。

### 2026-09-03 原58项最后七项收口

原58项中最后七项已经重画并接入：`lin_chong_escort idle`、董超与薛霸各自的`idle/walk`、`shi_qian_lantern idle`和`bound_shi_xiu idle`。林冲依据第八至九回保留七斤半团头铁叶护身枷与受缚双手；董超、薛霸使用素色公服和单根直杆水火棍，宽/瘦、褐/灰衣只作保守游戏区分；时迁依据第六十六回提元宵货篮与闹鹅儿，不画成常驻火把兵；石秀依据第五十回“自把囚车装了”表现为双手后缚，不臆加原文未写的颈枷。

网页生成的薛霸首稿和两张V2稿因跨行粘连判退，采用稿的五行之间有完整透明带。网页端只执行`alpha<=15`精确归零，`alpha>15` RGBA逐字节不变；本地只作固定格连续矩形裁切、同源统一等比缩放、透明补边与横排，没有镜像、补画、遮罩或连通域清除。生产共28张动画条带和5张头像，生产前33文件已完整备份；董超、薛霸每个方向的walk均为四张真实姿态。

Godot重新导入33项；专项运行合同246项全部通过，真实1280×720 Vulkan渲染163项与7张总览全部通过，设备为NVIDIA GeForce RTX 4060 Laptop GPU。第3、6、8关从正常任务流程推进至目标事件，3张场景均成功截取。严格来源覆盖更新为`100/347`（`28.818%`），原58项已完成58项、剩0项；247项缺失或方向不全仍是后续工作。完整来源、回滚、合同和视觉证据见`qa/yezhulin_remaining_p0_direction4_production_20260903/`。按用户要求，本批收口后暂停；候选源图不自动计入生产覆盖。未做完整八关真人通关、战斗高峰或长时性能验收，Steam目录未修改。

## 2026-09-01 普通资源四向idle追加

本批由网页版ChatGPT实际生成五张透明1254×1254原图：[梁山步兵](../assets/direction4/source/web_direction4_core_liangshan_v1.png)、[梁山/官军主力](../assets/direction4/source/web_direction4_core_official_v1.png)、[精锐/攻城器械](../assets/direction4/source/web_direction4_elite_siege_v1.png)、[剧情杂兵/守卫](../assets/direction4/source/web_direction4_story_guards_v1.png)和[军汉/钩镰/连环马/打手](../assets/direction4/source/web_direction4_story_convoy_lianhuan_v1.png)。第五张SHA-256为`440a44c45fce2572d56ed3b45ab5379902cdb8f486f5f098f737be1d57f550ac`。逐字prompt、对话地址、五张源图及prompt SHA、每格裁切区域、主体连通块、每行统一缩放、透明补边位置和成品SHA统一记录在`assets/direction4/manifest.json`。生产切片保留源RGBA，只做人物归属裁切、同一行统一缩放和透明补边，没有用镜像补方向，也没有重绘或替换背景。

当前产物严格为20个key×4个真实方向的80张单帧idle：`lou_luo`、`liang_dao`、`liang_qiang`、`liang_gong`、`liang_ma`、`guan_dao`、`guan_gong`、`guan_qi`、`guan_jingqi`、`guan_zhanzi`、`siege_cata`、`siege_ram`、`zhu_keke`、`zhu_gong`、`zhu_qi`、`guan_laozi`、`jun_han`、`gou_lian`、`lian_huan_ma`、`jiang_thug`。方向均为`se/sw/ne/nw`，写入`assets/anim/<key>_idle_<direction>.png`；Godot导入成功，manifest现有80个输出。当前战役实际使用的15个普通可移动key覆盖13个，余下`yu_hou`、`lao_duguan`；水战船不是这套普通Unit idle入口，仍需独立方向接口。本批没有新增四向walk、attack、hurt、down或death，也没有给108英雄或全部164个普通可移动定义补齐四向素材；未覆盖者仍按公共回退链使用旧无方向素材及镜像。

最新版公共契约`qa/direction4_20260901/headless_convoy_lianhuan_final.log`为39/39、exit 0，无ObjectDB、Leaked instance、orphan StringName或其他退出告警。最新版真实Unit夹具证据为`qa/direction4_20260901/runtime_visual_convoy_lianhuan_final/report.json`与`qa/direction4_20260901/visual_convoy_lianhuan_final.log`：真实1280×720 Vulkan覆盖上述20个key，165/165、exit 0，没有Texture RID泄漏、RenderingServer析构警告或其他日志问题，并写出五张分组图。165项只证明这20个key的四个idle资源经真实Unit绘制入口选中且不被二次镜像。该批完成时尚未重新导出或上传，Steam BuildID `25051529` 不包含这些资源；其后已随 `2026-09-04` 测试构建进入 BuildID `25121101`。

## 2026-09-01 死亡残留追加

在此前冻结的23张物件PNG之外，运行目录新增`objects/death_remains_default.png`，所以当前为24张物件PNG；旧交付文档中的23张仍是当时批次的准确历史数，不回写旧manifest。新图由网页版ChatGPT实际生成，原图、完整提示词、对话链接、透明边界、生产哈希和1280×720实机结果见 [CAMPAIGN_DEATH_REMAINS_20260901.md](CAMPAIGN_DEATH_REMAINS_20260901.md)。生产只选六格克制的新鲜血迹/装备/破布，保留两格骨片供以后陈旧战场布景使用。

## 接入契约

- `Art.unit_anim_frames(key, state, direction="", variant="")` 保留旧二参调用。新图缓存含 variant/state/direction，不使用全局武松别名。
- `Art.unit_texture(key, variant="", direction="")` 保留旧一参/两参调用；世界绘制可显式传当前方向。`Art.avatar_texture(key, variant="")`保持原签名。指定造型的头像从新角色帧裁取，不回退行者武松头像。
- `Art.campaign_variant_has_direction(variant, direction)` 用于判断是否应取消左右镜像；四向固定 `se/sw/ne/nw`。
- `Art.unit_anim_uses_directional_source(key, state, direction, variant="")`按实际选中的精确方向帧或同方向idle回退回答是否为定向源；Unit主绘制和坡面阴影据此决定是否允许旧式水平镜像。
- `Art.campaign_variant_has_animation(variant, state, direction)` 精确查询该动作的纹理文件并复用缓存，不经过idle回退。双人合绘只能在此方法为true时隐藏伙伴世界立绘，未知方向或缺文件为false。
- `Art.campaign_object_texture(key, state="default")` 返回战役单体资源，无匹配返回 null。所有角色帧 256×256，所有物件画布 512×512，脚底/基础锚点均为 `(0.5, 0.82)`。
- 素材、造型目录由 `scripts/campaign_art.gd` 管理，显式 variant 才启用。不写 `content/art/wu_song.png`，不改变自由模式原图集。
- 指定造型或普通四向资源缺少非终态动作时保留同方向idle，避免跳回另一时期衣服或旧单视角；普通资源的`death/down`不以idle冒充终态，而是继续查旧同状态素材或程序化倒地。此规则不意味着静态姿态已补成动画。

## 内置生成阶段已接入内容（网页追加另见后节）

| 用途 | key / variant | 实际内容 |
|---|---|---|
| 孟州武松 | `wu_song_mengzhou` | 2026-09-02网页重做版：idle/walk/attack/hurt/down 各四张真实方向单帧，共20张；万字头巾、土色布衫、腰系红绢褡膊、脸贴遮金印膏药、腿絣和八搭麻鞋，赤手空拳。attack为转身后第二脚高踢。旧80帧批次已由本批生产路径替换，只在备份中保留 |
| 野猪林林冲 | `lin_chong_bound` / `lin_chong_prisoner` / `lin_chong_escort` | 四方向绑树、带枷、抱伤臂跛行、受伤、坐下歇息。获救walk已由两帧换成四帧；新增四向×四帧`assisted`，真实画出鲁智深支撑林冲的双人动作。其余剧情状态仍有单帧，不冒充完整循环 |
| 野猪林公人 | `dong_chao_escort` / `xue_ba_escort` | 董超宽体褐色素公服、薛霸瘦体灰色素公服，包头、持直杆水火棍，无重甲无马；每人四向idle单帧、每方向walk四张真实姿态，以及各自同造型头像。未制作攻击/受伤/倒地循环 |
| 蒋门神 | `jiang_menshen_fists` | 2026-09-02网页重做版：idle/walk/attack/hurt/down各四张真实方向单帧，共20张。白布衫、紫褐黝黑皮肤、青筋、黄髯、徒手；hurt为活着护腹弯身，down为额部受击后向后倒地告饶，不再使用旧褐背心、黑髯、跪地图 |
| 鲁智深救人 | `lu_zhishen_rescue` | 2026-09-02网页重做版：idle/walk/attack/hurt/down各四张真实方向单帧，共20张；直杆六十二斤水磨浑铁禅杖。野猪林 `intercept` 明确读取同方向attack图，不再读取旧双月牙拦棍图 |
| 大名府伪装 | `shi_qian_lantern` / `chai_jin_officer` / `yue_he_officer` | 四方向独立姿态；柴进、乐和使用另制宋式素圆领袍，弃用初图的明式方补 |
| 劫牢前后 | `bound_lu_junyi` / `bound_shi_xiu` / `rescued_lu_junyi` / `rescued_shi_xiu` | 同人物衣色保持，绑缚和获救不同四向姿态；尚无完整行走帧 |
| 江州获救前后 | `song_jiang_bound` / `song_jiang_rescued` / `dai_zong_bound` / `dai_zong_rescued` | 各自同脸同衣；被缚四向单帧idle，获救四向idle与四帧walk。宋江米白囚衣、戴宗灰褐短衣，不借首领官服或骑兵造型 |
| 黄泥冈 | `wine_buckets` / `tribute_load` / `jujube_load` / `wine_bowls` | 酒桶酒瓢、绳束纲担、枣担、碗凳；纲担不是车 |
| 江州与快活林 | `bailong_temple` / `roadside_tavern` / `heyang_tavern` | 独立庙宇、小酒肆、大酒店，留空匾额由程序写字 |
| 大名府 | `cuiyun_tower` / `prison_gate` / `daming_south_gate` | 翠云楼 default/signal，牢门 default/open，砖城门独立图；火号图和建筑未拆开后会共同淡化 |
| 钩镰破阵 | `hook_training_dummy` / `hook_spear_team` / `linked_cavalry` / `broken_cavalry` | 木马练钩、双人配合 default/engaged、连接骑阵和失阵图；后两类是战场事件插图，不能代替单位碰撞或战斗规则 |
| 梁山水战 | `official_warship` / `liangshan_boat` | 官船 default/damaged/flooding/disabled 四状态；梁山低矮小舟单独图，不再借官船 |
| 落水被擒的高俅 | `gao_qiu_captured` | 四向idle和跪地咳水down，各一帧；湿蓝灰圆领袍、束手、无马无武器，独立同造型头像。NW另外生成，不镜像NE；没有制作walk |

初批输出为136条帧带、208帧、22张物件PNG、13张造型头像。林冲/江州/高俅补帧后为172条帧带、288帧、22张物件PNG、18张造型头像；该轮新增36条帧带，林冲既有四条walk帧带从两帧换为四帧。最后补董超/薛霸16条帧带、24帧、两张头像后，网页批次追加前的目录为**188条帧带、312帧、22张物件PNG、20张造型头像**。物件没有增加。帧带数量包含剧情单帧状态，不等同于188段完整动画。

## 重建和验证

1. 原图透明掩码的连通区域仅做坐标分析，记录在 `assets/campaign/slice_manifest.json`。Python只读图并输出坐标；没有用Python代画、抠图或修改像素。
2. 运行 `Godot --headless --path . --script tools/campaign_art_slice.gd`，由Godot统一缩放、裁切、对齐、保存。全程不镜像、不重新画角色；武松同一原图所有姿态共用比例，不按每帧包围盒各自拉伸。
3. 运行 `Godot --headless --path . --editor --quit` 导入，再运行 `tools/campaign_art_contract.gd`。初批65项，此前70项，新增公人后为`checks=72 passed=true`；报告在 `assets/campaign/contract_qa.json`。
4. 旧通用72项曾验证武松五动作每方向四帧。2026-09-02重做后，当前合同改为逐项验证五动作×四方向的20张独立单帧、精确路径、定向来源、透明边界和脚底误差≤3px；不得继续引用旧“四帧循环”口径。
5. 另运行 `tools/campaign_art_motion_contract.gd`，此前54项，新增公人后74项通过，报告为`motion_contract_qa.json`。林冲walk/assisted、宋江walk、戴宗walk的16组方向帧带各四帧；两公人的八组方向帧带各两帧，均检查像素与腿部轮廓实际不同，透明边界未截断、脚底误差≤3px。另验证精确动作查询不会被idle回退冒充、高俅状态与头像、自由模式资源未覆盖，以及188/312/22/20库存。公人本轮日志为`qa/campaign_art_constables_*.log`。

## 内置生成阶段的动作与双人合绘交接（历史）

- 该阶段的林冲、江州与高俅新动作由内置imagegen实际绘制；没有用镜像、平移单张图、交叉淡入或Python绘图凑帧。新的八张选用源图及透明通道分析在`motion_source_analysis.json`。Python只读alpha并记录区域坐标，Godot执行标准atlas裁切/统一比例/脚底对齐。每个源图采用统一比例，不按每帧高度单独拉伸。
- 补帧过程中首个林冲参考编辑输出RGB棋盘格，已淘汰；第二稿NW朝向和高抬腿不合适，也未接入。宋江、戴宗初稿只有前两行的被缚/获救idle被使用，步行行存在同侧步重复、人物变小问题，另制横向周期图替换。高俅初图最后一列朝向不对，只取前三方向；NW单独补画。完整prompt和取舍在`motion_generation_manifest.json`。
- `lin_chong_escort/assisted`通过与walk相同API读取，每方向四帧，每帧256×256。锚点`(.5,.82)`按双人组的水平中心和最低脚底线对齐，不是单独林冲的脚。建议合绘中心取双方投影脚点的中点，实机复查前后脚造成的纵向偏差；不得直接沿用林冲单脚位置而令鲁智深瞬移到画内。两人仍需各自保留逻辑单位、受伤、选择与移动规则，离开搀扶条件立即恢复独立立绘。
- 单人林冲walk可见轮廓高174–184px，双人组179–202px，NW方向略高。双人图包含两个人但仍按单人相同scale绘制，不要再以人数除二缩小。此为位图整体边界测量，不把它误称作精确骨架身高。
- 已查看生成原图后再切片，并查看规范化的SE/NW搀扶、林冲NE行走、宋江SE/戴宗SW行走以及宋江/高俅头像。RGBA源图的一些极低alpha背景RGB在文件查看器会显示黑色或红色区域；亮红背景样本alpha均不超过10/255，不能根据忽略alpha的预览直接认定烘焙红块，最终以Godot合成为准。
- 四帧可见迈步、收步和支撑姿态变化，但两次接触姿态仍较接近，属于简化短步循环，尚未达到更多中间帧的平顺程度；哈希和轮廓不同只证明真实资源不同，不能替代动画流畅度检查。双人接近/走散/死亡/选择、江州实际逃离、高俅俘虏在水边的尺寸和遮挡由root继续实机验证。
- 在该内置生成阶段，大名府卢俊义、石秀没有补完整walk；按优先级先补了终章不该骑马的高俅。其余既有单pose动作仍按表中边界记录，没有因本轮补帧一并声称完成。

## 两名公人占位修复

- 查看`qa/campaign_story_visual/level6_assisted_1280.png`，新搀扶组合正常显示，旁边两团黄色三角对应董超/薛霸。旧`art_db.gd`只有二人的`portraits3`头像，世界图目录没有这两人；不是林冲/鲁智深新图透明度故障。
- 新增两个显式variant，旧一参头像及自由模式资源不改。每个variant四向idle单帧，walk为“迈步接地＋收腿经过”两张真实生成姿态；足部轮廓和承重位置有变化，没有用静态平移或淡入凑步幅。两帧并非完整左右步四阶段循环，未扩展攻击、受伤和倒地。
- 首版两张接地姿势太接近，弃用重复列，另制收腿图；薛霸首版SW朝向也未采用。规范化逐帧检查发现几处木棍换手，又补董超SE接地/NW收腿、薛霸NW接地，保持idle与walk的持棍侧一致。六张选用源图逐字节复制，alpha与来源哈希在`constable_source_analysis.json`；全部提示词与未用区域在`constable_generation_manifest.json`。
- 切片器允许某个单元格显式引用另一张源图、区域与该源图统一比例，只做Godot确定性裁切/缩放/脚底对齐；旧数组格式仍兼容。不逐帧拉伸身体，不绘制或镜像任何图像。单帧仍为256×256、锚点`(.5,.82)`。不同源图的衣褶、肩宽有少量变化，仍需实际播放观察。
- 已查看最终规范化的董超SE/NW、薛霸SW/NW步行及两张头像。运行时是否完全解除占位、世界尺寸和遮挡由root最终1280×720实机截图验证，不以静态切片契约代替。
- 公人这一轮结束时江州民众尚未有独立小民资产；后续网页批次已制成普通百姓四向idle，见下节。未借主角脸冒充小民。大名府完整walk在公人这一轮未扩充。

## 网页ChatGPT追加批次（资源已完成，实机另验）

- 用户明确指定网页ChatGPT后，新图均由主任务网页实际生成、下载源PNG，再由独立 `campaign_web_art_*` 工具切片。14张采用源、2张整体弃稿及未采用区域、逐字prompt、稳定对话链接与SHA在 `web_art_manifest.json`；原著核对见 `docs/WEB_CHATGPT_ART_BRIEF.md`，流程与验收细节见 `docs/WEB_CHATGPT_ART_PIPELINE.md`。未调用付费API/CLI后备。
- 黄泥冈 `hn_*` 八位布衣商客各有四向单帧idle、四向两关键帧walk与同造型头像；普通百姓 `town_vendor/porter/woman/elder` 各四向idle与头像，尚无walk。`jujube_cart_default`为新木枣车，旧枣担保留。白胜空手底图保留；另补同variant的carry_idle四向单帧及carry_walk四向两关键帧，真实画出竹杠压肩、两只酒桶悬挂，运行接线在携酒时选择这两状态并抑制地上酒桶叠图。肩挑批次未改头像；之后仅白胜头像获准修正邻格残片，见下文。
- 新 `daming_bound_lu_junyi` / `daming_rescued_lu_junyi` / `daming_bound_shi_xiu` / `daming_rescued_shi_xiu`各四向idle与同造型头像，两个rescued各四向两关键帧walk；旧四variant全部保留。新套为长袖布衣，被缚/获救/步行同脸同衣。参考上传被明确拦截，未上传、未绕过，本批据原著文字整套新绘。
- A首walk公孙胜串衣行、B重复步姿、Bpassing粘连的两个NW、石秀错误被缚NW均未直接接入；改选完整跨步并配独立收步或独立NW补图。两帧有真实腿部姿态变化，但不称完整左右交替四步周期。晁盖/吴用按人物整行统一比例匹配idle/walk，不逐方向拉伸。
- 该网页追加历史批次当时累计为300条帧带/468帧、23物件组、36头像。2026-09-02鲁智深、孟州武松和蒋门神生产替换后，当前物理目录为**316条帧带/416帧、72张物件PNG、36头像**。相对468帧净减52帧：鲁智深由旧少量姿态扩为20帧，孟州武松旧四帧条带改为20张单帧，蒋门神旧28帧改为20张单帧。不能把416张关键姿态称为416段完整动画；肩挑追加时的旧字节保护结论仍只属于当时历史快照。
- 独立网页契约最新**1454项通过**，报告 `web_art_contract_qa.json`；肩挑前1317项和肩挑批1419项均为历史轮次。129个产物记录通过，最后仅重切一张头像，日志 `qa/campaign_web_bai_portrait_revision_slice.log`。肩挑批verbose曾定位AudioStreamWAV/AudioStreamPlaybackWAV退出引用警告；最后单头像切片仍有ObjectDB退出警告，无SCRIPT/PARSE错误，不宣称零警告，未修改音频代码。关键规范化帧已查看。`resources_ready`不替代最终editor导入、HUD/场景实合成、动画流畅度或真人试玩；主任务/玩法任务继续验证最终版本。
- 肩挑源图首行SE/SW可见帽顶自y=8开始，顶沿仅alpha≤4的透明背景残值；没有补帽或加边伪装修复。统一source scale0.60，规范化主体高179–193px、肩担宽152–176px，脚底209–210px，不因肩担更宽缩小人物。每方向三帧压肩/握杆连续，跨方向的扶杆手/肩侧有切换，记录为美术限制，不强称严格同手骨骼动画。
- 旧动作契约改为验证旧20造型仍全注册，额外记录总注册数，存在网页清单时输出 `motion_contract_qa_with_web.json`以保留历史结果；该测试由主任务最终导入后复跑。新造型数量增长不应使旧资源保留契约误失败。

### 白胜头像归属修正（2026-08-31，最后一张PNG）

实机发现白胜头像左上独立金色弧片，alpha>8共389像素、最大255，边界`[15,10,60,21]`（末端不含）；确为前一行阮小七鞋尖，不是透明RGB预览假象。只修 `portraits/hn_bai_sheng.png`：保持B组idle原图、头像裁框`[95,915,149,152]`和比例不变，Godot按原图连通归属复制RGBA，排除132个源alpha>99邻人像素，保留白胜全部12810个源主体像素及完整帽沿。没有重画、擦画、补帽或改旧232文件。

修前头像、manifest、切片报告、1419项肩挑报告、351张基线与全359张PNG快照存于 `assets/campaign/source/history/web_bai_portrait_fix_20260831/`；原351基线未被重写。`web_bai_portrait_revision.json`记录明确授权、前后SHA与来源归属，契约只接受这一个准确路径的差异：其余350张肩挑前PNG及全部其余358张成品PNG均字节不变。新头像SHA为 `f8cc1f4068ba1bc93e9be71b8046fc48cd3cca134d824fa77844d56b75bf917c`，数量不变。

16张新头像已只读扫描独立alpha块；修后白胜仅余小型低alpha边缘碎片（最大7像素、alpha20），其余头像未发现同类邻人格块。契约新增头像实体块告警和源像素保留核对，但不自动删除头巾、衣角或抗锯齿碎片。规范化头像已视检同脸同衣、帽沿完整、金色残片消失。随后主任务最终导入及1280×720现场确认HUD残片消失、肩挑/卸酒正常、大名府解枷首帧头像同步；对应207项黄泥冈与129项大名府证据见 [本批交付记录](WEB_CHATGPT_ART_DELIVERY.md)。

## 明确的质量边界

- API/alpha/切片契约通过不等于八关视觉或真人试玩验收；人物与建筑实际尺寸、遮挡、碰撞和地形贴合由root进行1280×720实机检查。
- 两次参考图背景编辑返回了烘焙棋盘格，均已剔除。背向倒地最终重新生成，存在与主图衣褶略有差异，需在倒地演出检查连续性。
- 四向为分别生成的图像，无程序镜像。细微人物转向准确度仍需视觉检查，图像哈希不同只证明资源独立。
- 建筑的城门、庙名、酒望和火号说明交给程序文字层。白胜新增肩挑图的桶身“酒”字作为功能识别美术由主任务明确接受，不声称原著逐字规定该标记。
- 庙宇、楼房和船为小说背景下的游戏视觉诠释，不声称是某处宋代实物的考古复原。
- 不修改Steam目录，不导出、不上传。

## 2026-09-01 先锋头船双旗 v3（网页端 ChatGPT）

本批仅为第5关第八十回前队新增 `official_vanguard` 的 4 状态 × 4 真方向资源。v3 原图由网页端 ChatGPT 实际生成，来源会话为 <https://chatgpt.com/c/6a96b875-8320-83ea-80ad-57f1790022b9>；原图 `assets/direction4/source/web_direction4_official_vanguard_states_v3.png` 的 SHA-256 是 `ADE7510DB70BE9FC2FB0DC8F4442855CF3B3D921D9BEB09D65F810A18BF50FD0`，提示词 `assets/direction4/web_prompts_20260901/official_vanguard_states_4x4_v3.txt` 的 SHA-256 是 `1270E91A308CA1282A63CC33F1E004B1D0D54CE925C3BDAF3FC75A93AC0DD180`。未使用 image_gen API、CLI 或本地绘图后备。

源图为 1254×1254 真 alpha 4×4 图表：`default/damaged/flooding/disabled` × `se/sw/ne/nw`。生产只按审计透明缝裁切、统一缩放并透明补边，输出为 `assets/campaign/objects/official_vanguard_<state>_<direction>.png`；不镜像、不重画、不填补像素。v3 最小竖向透明缝 36 像素、横向 21 像素。v1 因旗布和可书写区域过小淘汰，v2 因首列前两行之间只有 6 像素透明横缝淘汰；两者保留在 `assets/direction4/source/` 作追溯，均未接入。

生成图只提供无字朱红旗布。游戏内白名单在不改旗布的前提下覆盖第八十回先锋双旗文字；它不是个人姓名旗，十四字作为一组编制旗文，分到两块旗布只是本作版面。具体原著依据和路由限制见 [CAMPAIGN_FLAG_SOURCES_20260901.md](CAMPAIGN_FLAG_SOURCES_20260901.md)。

本批尚未导出、未修改 Steam 发布目录、未上传。素材合同和画面夹具不是全战役美术、性能或真人试玩验收。

## 2026-09-04 驻守战四向首批与死亡血迹优化

普通单位四向路由修正为“精确四向同动作 → 旧无方向同动作 → 同方向待机”。因此只有四向 `idle`、尚无四向 `walk/attack` 的单位，移动和攻击时会继续播放原动作，不再静态滑行；`unit_anim_uses_directional_source()` 与真实取图顺序一致，只有精确四向资源会关闭旧水平翻面。通用回归覆盖164个可移动定义，驻守名单另按30波配置和投石车规则派生检查508项回退组合，错误待机覆盖为0。

本批用 Codex 内置浏览器为 `guan_musket` 生成 `idle × se/sw/ne/nw`。第一张2×2版因不适配固定单行管线且有低透明边界噪点判退，第二张单行版因误成日式红黑武士甲判退；第三张恢复灰蓝中式官军、红缨帽和细长火枪。网页端再用 Pillow 执行 `alpha<=15 → RGBA(0,0,0,0)`，本地复验29736个变化像素，`alpha>15` 区域RGBA不一致为0。之后本地只做固定矩形裁切、整组统一比例缩放、透明补边和逐字节生产复制，没有镜像、遮罩、本地清像素或补画。来源会话、参考图、提示词、判退稿和全部哈希见 `assets/direction4/skirmish_p0_direction4_manifest.json`。

Godot 4.6.3重新导入四张PNG。真实Vulkan 1280×720夹具191项通过，23类普通单位均命中各自精确四向待机且不二次镜像。默认30波敌军四向待机由682/778提升至709/778（91.131%）；这里只新增火枪手待机，火枪手行走/攻击仍用既有无方向动画，完整五状态四向仍只有李逵，四项完整度门仍未通过。

同轮死亡残留不更换位图，改为死亡后0.35秒显现、按四向作4至8像素倒地偏移、36像素内合并刷新并加深；普通兵种按远程、枪兵、甲兵/骑兵、轻兵做克制的低频装备变化，骆驼和战象只留小血土，投石车和撞车不再留下人形血迹。专项无头16/16、图形17/17、旧战役核心68/68。证据分别在 `qa/skirmish_direction4_20260904/` 与 `qa/skirmish_death_remains_20260904/`。

以上图形结果是自动固定机位，不等于真人30波试玩、转向手感或兵海性能验收；用户尚未对新火枪手造型做视觉确认。本轮没有导出、修改 Steamworks 目录或上传 Steam，BuildID `25121101` 不含这些后续增量。
