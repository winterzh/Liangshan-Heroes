# 战役实机画面核对

以下主体为网页美术追加前的content2实机记录，使用本机Godot 4.6.3、Forward+、1280×720。最新网页批次的黄泥冈挑酒/卸酒/搬纲、大名府解枷/出城和城镇人群另见 [WEB_CHATGPT_ART_DELIVERY.md](WEB_CHATGPT_ART_DELIVERY.md) 与`qa/web_chatgpt_art_20260831/`。布景夹具、真实任务事件和性能采样分开，不把截图或自动操作称为真人试玩。常规15—25分钟节奏没有通过。

## 2026-09-01 普通单位四向idle实机夹具

第五张网页版ChatGPT原图`web_direction4_story_convoy_lianhuan_v1.png`（SHA-256 `440a44c45fce2572d56ed3b45ab5379902cdb8f486f5f098f737be1d57f550ac`）导入后，`direction4_visual_test`通过真实Unit绘制入口在本机Godot 4.6.3、Vulkan、NVIDIA GeForce RTX 4060 Laptop GPU、1280×720下完成最新版夹具。夹具逐一实例化20个空`art_variant`普通key，其中新增`jun_han`、`gou_lian`、`lian_huan_ma`、`jiang_thug`；在`se/sw/ne/nw`四个方向核对实际帧路径及`_frame_directional=true`，确认80张真实定向idle没有再被旧`face_left`水平镜像；结果165/165、exit 0，日志无告警。最新报告为`qa/direction4_20260901/runtime_visual_convoy_lianhuan_final/report.json`，对应日志为`qa/direction4_20260901/visual_convoy_lianhuan_final.log`；画面入口为[梁山五类](../qa/direction4_20260901/runtime_visual_convoy_lianhuan_final/liangshan_1280.png)、[主力官军四类](../qa/direction4_20260901/runtime_visual_convoy_lianhuan_final/core_army_1280.png)、[精锐/攻城三类](../qa/direction4_20260901/runtime_visual_convoy_lianhuan_final/elite_siege_1280.png)、[剧情杂兵/守卫四类](../qa/direction4_20260901/runtime_visual_convoy_lianhuan_final/story_guards_1280.png)和[军汉/钩镰/连环马/打手四类](../qa/direction4_20260901/runtime_visual_convoy_lianhuan_final/story_convoy_lianhuan_1280.png)。

最新版headless公共契约`qa/direction4_20260901/headless_convoy_lianhuan_final.log`为39/39、exit 0，无ObjectDB、Leaked instance、orphan StringName或其他退出告警。它覆盖方向缓存、缺动作保持同向idle、旧death及旧API回退、实际帧镜像标记、164个普通可移动定义的四象限状态和攻击/施法锁向，临时`assets/anim`代理已清理。164只说明公共方向机制遍历通过，不表示164套四向美术完成。

最新版真实Vulkan夹具没有Texture RID泄漏、RenderingServer析构警告或其他日志问题。这些结果不外推为完整游戏长期内存或性能结论。五张图是20类定向idle的专用渲染夹具；当前战役15个实际普通可移动key覆盖13个，余下`yu_hou`、`lao_duguan`，水战船仍需独立方向接口。夹具不是实际战斗、全模式通关、108英雄/164单位全素材、四向walk/attack、兵海性能或真人试玩证据。Steam未重新导出或更新。

## 2026-09-01 死亡残留实机复查

网页版ChatGPT新绘的透明4×2图集已经接入。最终夹具通过正常`Unit.take_damage`与`died`让六名普通陆地单位死亡，并等待1.4秒倒地动画结束；六个单位节点均已释放，画面只剩血迹、断枪、破布、草鞋和倒旗。一名剧情“被擒”人物作为反例，没有生成残留。截图为 [death_remains_real_deaths_1280.png](../qa/death_remains_20260901/visual/death_remains_real_deaths_1280.png)，报告为同目录`report.json`，7项通过。

已实际查看1280×720截图：六处画面均为透明贴地物件，没有白框，道路接触关系正常，现存友军、河岸和建筑遮挡没有异常。非零坡面的基准与渲染高度另由核心测试中的真实死亡样本验证，不把这张平地截图说成坡面画面。普通新死亡刻意不选两格陈年骨片；因此本轮完成的是血迹和装备残留，不写成每次必出骨骸。夹具冻结相机和无关单位，只证明指定状态的画面与释放关系，不是完整战役、性能或真人试玩。

## 画面来源

网页追加批次的最新图形证据为`qa/web_chatgpt_art_20260831/huangnigang_visual_clear/`（207项、16图：真实事件5张、明确夹具11张）、`daming_prisoner_visual_synced/`（129项、12图）与`crowd_visual_size50/`（67项、5图）。实机确认七车集中歇脚区且有深度/软影、白胜肩挑/卸酒无重复桶、头像邻格残片已去除、两囚解枷首个绘制帧头像同步、获救后两关键步姿可见及跨模式复位。普通人群仅静态；这33张截图不是33次通关。Texture RID退出清理错误仍有，完整图形日志及真正文件SHA见最新交付记录的索引。

以下列表是content2历史工具与画面：

- `tools/campaign_rework_visual_test.gd`：菜单、原著顺序选关、八关开局、武松四向拳脚展示、梁山厅堂—寨门—码头。开局后冻结战场，调整相机。武松四向画面额外放置四个同造型单位，专用于比较四个方向，不是普通玩法中有四个武松。
- `tools/campaign_story_visual_test.gd`：从正常HUD开战，经真实任务请求、行走、战斗到达目标事件，随后冻结截图；不注入生命、人物位置、剧情终态或胜利。当前事件为野猪林拦棍、黄泥冈麻倒与挑担、蒋门神制服、江州二人获救行走、大名府火号与获救。
- `tools/campaign_finale_playthrough.gd`：`FINALE_CAPTURE`非空时，截取正常事件流程中的座船进水、水上救取、押俘返航和码头交接。此入口也已改走HUD开战按钮，避免夹具绕过按钮而在战斗中留下“开战”控件。

开局总览位于项目外层 `_archive/campaign_history/campaign_rework_20260831_173850/visual_final/`；后续城墙/门架调整的中间图在`visual_content2/`。实际任务事件PNG及JSON在`qa/campaign_story_visual/`。后续新增内容的最终重截以本文末尾补记为准，不混用旧图证明新机制。

## 已查看与修正

1. 菜单按野猪林、黄泥冈、快活林、江州、祝家庄、连环马、大名府、高俅排列，八关全部可选；旧`LEVEL=N`仍对应旧关卡ID。
2. 任务框按英雄栏实际宽度避让。已截开局中英雄栏最右x80、任务框左x92；多列英雄时动态向右移动。面板宽286，正文自动换行，完成阶段后收缩；地图标记与按钮编号对应。终章复查发现唯一目标的长标题仍压在船员名上，最终改为只保留编号，完整说明留在按钮和办理状态中。
3. 酒肆/酒店原先误走“被缚人物”的绘制分支，导致缩成小人尺寸。现在仅真正被缚人物走该分支，酒店按建筑尺寸绘制并实际占格，交互位置在门外。当前近景能区分武松的布衫拳脚和蒋门神向后倒地告饶；旧跪地图已停用。
4. 野猪林拦棍交互已收紧到大树旁，鲁智深朝向林冲，不能远处点完就做拦截姿态。搀扶成对素材接线、动作完整性另有专门验收，不能用此张拦棍图替代。
5. 梁山前院保持平整，忠义堂、主门、门外道路和码头处于连续关系，山麓向北/西接出，不是一个均匀椭圆岛。东门补齐屋顶，牌文字单独处理方向，不跟随门架镜像。码头水岸高差属于压缩地图表现，不声称考古复原。

### 2026-09-04 驻守战梁山环境复用

- 驻守战真实1280×720开局镜头确认：战争迷雾内忠义堂、堂前旗、寨墙、主门和东门均可辨，资源单位没有遮住主入口。
- 关闭迷雾的审查镜头只用于查看地图：总览可同时读到水泊、芦苇汊、林峦、堂前平地和山前大路；金沙滩码头有连续木板、船只和水面，后山道路不穿堂墙。
- 五张图与报告位于`qa/skirmish_liangshan_environment_20260904/visual_review/`。该组是实际Vulkan渲染，但不是玩家审美确认、30波平衡或性能证据。
6. 大名府外墙从临时木寨栅改为可复用砖土城墙mesh；牢院使用较低同类墙。偏门、牢门的视觉开闭直接读取相应导航格状态，不另设可能与碰撞脱节的美术开门标志。
7. 终章水上画面发现小艇立绘互相遮盖过多，已降低显示比例，未缩小碰撞半径或放宽水域规则。高俅已接入独立的无马湿衣造型，真实返航后出现在木码头；进水官船显示“正在进水”，不再显示人物制服简称“服”。旧骑马截图不作最终证据。

## 证据入口

- [原著顺序选关](../../_archive/campaign_history/campaign_rework_20260831_173850/visual_final/story_order_1280.png)
- [武松四向展示夹具](../../_archive/campaign_history/campaign_rework_20260831_173850/visual_final/wu_song_four_directions_1280.png)
- [梁山门厅码头关系](../../_archive/campaign_history/campaign_rework_20260831_173850/visual_content2/liangshan_hall_gate_dock_1280.png)
- [鲁智深拦棍事件](../qa/campaign_story_visual/level6_intercept_1280.png)
- [黄泥冈麻倒与搬担](../qa/campaign_story_visual/level1_unconscious_carry_1280.png)
- [蒋门神制服事件](../qa/campaign_story_visual/level7_menshen_subdued_1280.png)
- [翠云楼火号与获救者](../qa/campaign_story_visual/level8_fire_and_rescued_1280.png)

## 不由这些截图证明的事项

- 部分任务物件、配角和船只仍使用少帧/静态姿态；不能称八关所有人物都有完整四向循环。生成图哈希不同也不能单独证明方向、步幅和脚底对齐正确。
- 凝固帧里的FPS受载图、冻结、截图与加速驱动影响，不作为性能结果。真实交战帧时另见`CAMPAIGN_RUNTIME_QA.md`，终章仍有慢帧，不能称稳定60FPS。
- 截图和脚本选取任务按钮不等于陌生玩家能看懂，也不等于已经逐个用鼠标点过所有门洞、树下单位和拥挤战场。全路径人工操作、首次玩家理解与真人节奏仍未验收。
- 色彩、墙体、树木与新人物现在仍有新旧素材混用；当前是本地开发候选，不是最终美术封版。未导出、未操作Steam目录、未上传发布。

## 内容补强批次

黄泥冈的现场盘问/两桶酒、大名府的实际进城/入牢、林冲成对搀扶及获救者步行已合并。最新重截见下节，未完成的动画和真人项不会因这些局部通过而删除。

## content2最终画面复查

最新整套菜单/八关开局/武松方向夹具/梁山入口在项目外层`_archive/campaign_history/campaign_rework_20260831_173850/visual_delivery/`，运行日志`overview-delivery.log`。已逐图查看八关开局，重点复核酒店实际尺寸、城墙与牢院、梁山主东门、人物造型及任务面板；地图边缘黑区和部分重复地表仍可见，未作为最终美术封版。

`story-delivery.log`与`qa/campaign_story_visual/report.json`记录5/5真实事件抵达并保存1280×720图片：野猪林拦棍、黄泥冈麻倒后首担被挑起、快活林告饶、江州宋戴真实行走、大名府举火后解救。全部通过正常HUD开战和任务请求，事件前没有注入人物生命、坐标或结算状态。大名府仅调整截图相机，让牢区获救者与翠云楼同时避开左侧两列英雄/任务面板，不移动人物造假。

黄泥冈图中首担已由刘唐携带，原地只剩其余两担；旧伪装区、疑心与酒桶大段文字在麻倒阶段收起。专项`cargo_v1.json`另外经过反复生产可见性刷新，证实不是只在截图瞬间藏起。七星仍有旧服装/武器立绘，普通押送者麻倒沿用旧姿态，这些不算商客全套美术已完成。

搀扶专用`assisted-delivery.log`及`qa/campaign_story_visual/assisted_contract.json`通过12项：先走真实照料/行走事件，再检验双方独立脚点可选、走散、攻击、失能与重开边界。后面的位移/伤害是明确夹具，不能冒充真人操作。已查看`level6_assisted_1280.png`：双人搀扶、董超/薛霸独立世界图均已显示，黄色公人占位符消失；林冲名字缩为本名，避免与鲁智深长名字重叠。两解差是两帧简化步行，不是完整攻防循环；树下叠放和合绘的细微步态仍需人玩观察。

`finale-delivery-visual.log`再次从完整真实主链截取水上救取、押俘返航、木码头交接并最终获胜，215.40游戏秒，移动域违规0、无重复转移。已查看高俅在实际木板上、无马、押送舟仍在相邻水域，旗号/长任务标题没有盖住他的名字。游戏秒数不是墙钟或真人时长。水上几艘船仍可能有图像交叠，不能把逻辑不越岸当作所有船体遮挡达标。

补充入口：

- [最终原著顺序菜单](../../_archive/campaign_history/campaign_rework_20260831_173850/visual_delivery/story_order_1280.png)
- [最终武松四向拳脚夹具](../../_archive/campaign_history/campaign_rework_20260831_173850/visual_delivery/wu_song_four_directions_1280.png)
- [最终梁山门厅码头关系](../../_archive/campaign_history/campaign_rework_20260831_173850/visual_delivery/liangshan_hall_gate_dock_1280.png)
- [双人搀扶与两公人](../qa/campaign_story_visual/level6_assisted_1280.png)
- [宋江戴宗获救行走](../qa/campaign_story_visual/level2_rescued_walk_1280.png)
- [进水后水上救取](../qa/campaign_story_visual/level5_water_rescue_1280.png)
- [木码头接收高俅](../qa/campaign_story_visual/level5_capture_gao_1280.png)

本节content2结束时为188条帧带/312帧、22张任务物件状态图、20张造型头像，通用资源72项、动作74项通过。这些旧图中的江州/灯市几何占位、黄泥冈旧衣装与大名府旧获救姿态已经由后续网页批次替换；不能把旧截图当成新造型验收。完整循环、连续钩镰动作、15—25分钟节奏、长时间性能和真人试玩仍未通过。

## 2026-09-01 先锋头船旗号实机复查

本批使用网页端 ChatGPT 的 v3 无字双旗源图，接入第5关第八十回最终前队。真实 Unit 夹具在本机 Godot 4.6.3、Vulkan、NVIDIA GeForce RTX 4060 Laptop GPU、1280×720 下运行，报告为 `qa/direction4_20260901/runtime_official_vanguard_final/report.json`：77/77、exit 0。它实际生成一艘 `official_vanguard`，并逐格检查 `default/damaged/flooding/disabled` 的 `se/sw/ne/nw` 资源、禁止镜像和先锋双旗选择。

已人工查看 [终章先锋头船](../qa/direction4_20260901/runtime_official_vanguard_final/official_vanguard_level5_default_1280.png)、[四状态图](../qa/direction4_20260901/runtime_official_vanguard_final/official_vanguard_states_1280.png) 及其 [旗文近景](../qa/direction4_20260901/runtime_official_vanguard_final/official_vanguard_level5_default_flags_close.png)。近景确认两块无字红旗上可见 `搅海翻江冲巨浪` 与 `安邦定国灭洪妖`，没有 `梁山好汉`、`梁山军`、`宋军`、`刘梦龙水军` 或高俅 `帅` 字误落在先锋船上。

自动合同另有 `campaign_flag_overlay_contract_vanguard.json` 24/24，与终章编制合同 `depth_contract.json` 58/58。它们证明文字路由和 1 艘先锋头船、4 艘普通官船与独立高俅中军的压缩结构；截图证明此夹具画面，不等于水路寻路、实际战斗、全章通关、性能或真人试玩。真人试玩仍待单独完成。本批未导出、未触碰 Steam 发布目录、未上传。

## 2026-09-02 蒋门神原著造型实机复查

快活林专用 `jiang_menshen_fists` 已使用侧边栏网页ChatGPT重做。真实Level7 Unit夹具在本机Godot 4.6.3、Vulkan、NVIDIA GeForce RTX 4060 Laptop GPU、1280×720下依次绘制 `idle/walk/attack/hurt/down` 的 `se/sw/ne/nw`，报告 `qa/jiang_menshen_direction4_production_20260902/runtime_visual/report.json` 为32/32。

五张原尺寸图已逐张查看：[站立](../qa/jiang_menshen_direction4_production_20260902/runtime_visual/idle_1280x720.png)、[行走](../qa/jiang_menshen_direction4_production_20260902/runtime_visual/walk_1280x720.png)、[出拳](../qa/jiang_menshen_direction4_production_20260902/runtime_visual/attack_1280x720.png)、[护腹受伤](../qa/jiang_menshen_direction4_production_20260902/runtime_visual/hurt_1280x720.png)、[向后倒地告饶](../qa/jiang_menshen_direction4_production_20260902/runtime_visual/down_1280x720.png)。四个方向视角不同，人物始终为白布衫、紫褐黝黑皮肤、黄髯、徒手；未见旧褐背心、黑髯、现代拳击护具、跪地图、截断、明显彩边、水平镜像或双重阴影。`hurt/down` 均为活人状态，不代替死亡。

[40节点短压力图](../qa/jiang_menshen_direction4_production_20260902/runtime_visual/performance_fixture_1280x720.png)的3秒窗口P95/P99为8.719/9.525ms。该夹具不含战斗AI，不能代替战役高峰匹配对比、30分钟稳定性、完整动画循环流畅度或真人节奏/平衡。Steam未导出或更新。

## 2026-09-04 驻守战寨墙与寨门复查

- [开局迷雾与南门](../qa/skirmish_rts_stockade_20260904/visual_gate_final/01_player_start_fog_1280.png)：南门屋脊沿左下寨墙展开，门洞没有被墙段穿过。
- [全寨与两种门向](../qa/skirmish_rts_stockade_20260904/visual_gate_final/02_water_reeds_overview_1280.png)：南门、东门分别贴合两条互相垂直的网格墙轴；墙内是连续大院，不再被高墙分成狭长走廊。
- [忠义堂、院地与墙线](../qa/skirmish_rts_stockade_20260904/visual_gate_final/03_hall_three_passes_1280.png)：忠义堂周围保留夯土核心，外围草地区可继续落建筑。
- [兵营施工](../qa/skirmish_rts_stockade_20260904/build_smoke/shot_00.png)与[兵营完成](../qa/skirmish_rts_stockade_20260904/build_smoke/shot_01.png)：真实驻守烟测在院内完成3×3兵营，未压墙、未堵门。

五个固定机位在1280×720 Forward+ Vulkan下5/5保存，报告为`qa/skirmish_rts_stockade_20260904/visual_gate_final/report.json`。这组证据证明当前门向、墙线、可视门洞和一次建筑落位；不证明玩家认可最终墙体美术，也不代替自由摆放多类建筑、30波通关、拥堵压力或长期性能测试。

## 2026-09-04 驻守战迷雾、关名与旗位复查

- [全寨关防与寨内旗位](../qa/skirmish_fog_signage_20260904/visual_final7/02_water_reeds_overview_1280.png)：南侧门额改为“山前关”，东侧改为“东山关”；杏黄“替天行道”旗位于忠义堂后方寨内高地。
- [忠义堂正面关系](../qa/skirmish_fog_signage_20260904/visual_final7/03_hall_three_passes_1280.png)：忠义堂正面朝南侧山前关，堂前两面红旗保留。
- [未探索迷雾边界](../qa/skirmish_fog_signage_20260904/visual_final7/06_unexplored_fog_boundary_1280.png)：黑雾内不再露出树冠、芦苇尖、门楼、旗尖或地图外缘色线。
- [东山关近景](../qa/skirmish_fog_signage_20260904/visual_final7/07_east_mountain_pass_1280.png)：门额、墙轴和门洞方向一致。

报告`qa/skirmish_fog_signage_20260904/visual_final7/report.json`为7/7，记录166个未探索景物、可见泄漏0个；东山关探索前隐藏、探索后显示。静态地图契约`qa/skirmish_fog_signage_20260904/map_contract.json`为31/31。固定机位为视觉与状态转换证据，不是30波真人通关、平衡或长期性能结论。

## 2026-09-04 驻守战中轴与资源林团复查

- [矩形总览与延伸水泊](../qa/skirmish_axis_resource_groves_20260904/visual5_rectangular_minimap/02_water_reeds_overview_1280.png)：地图菱形外侧由水泊背景填满，左侧不再出现斜切黑三角；小地图视野框为正向矩形。
- [开局迷雾与正向小地图框](../qa/skirmish_axis_resource_groves_20260904/visual5_rectangular_minimap/01_player_start_fog_1280.png)：忠义堂落在可玩区水平中线，小地图白框不再是歪斜菱形。
- [忠义堂和主路近景](../qa/skirmish_axis_resource_groves_20260904/visual5_rectangular_minimap/03_hall_three_passes_1280.png)：厅、广场、主路与山前关沿同一网格轴衔接。

视觉报告`qa/skirmish_axis_resource_groves_20260904/visual5_rectangular_minimap/report.json`为7/7，`minimap_frame_mode=axis_aligned_rect`，迷雾仍为167个未探索景物、可见泄漏0个；地图契约`qa/skirmish_axis_resource_groves_20260904/map_contract.json`为35/35。另有真实驻守烟测确认自动伐木和木材增长，不代表真人30波平衡完成。
