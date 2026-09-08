# 祝家庄景物状态候选（2026-09-09，工程外）

状态：**仅代码候选和静态检查；未运行 Godot、未原生解析、未接入工程、不是世界恢复验收。**

生产来源为 `D:/AI项目/水浒/开发工程`。本目录只写候选、补丁、18 份相关来源快照及静态收据，不含玩家档案、账号数据或构建包。18 份是本组件的审查来源，不是整个项目的运行输入闭包。来源和产物 SHA 见 `source_manifest.json`；`static_review.json` 的通过仅指 Python/文本检查。

## 文件和具体范围

- `candidate/scripts/run_scenery_state.gd`：直接扩展现有固定景物工厂，复用原树冠可见性、材质、贴图描述、芦苇网格二进制和墙体字段。单独的 `level3_scenery_state_v1` 只接受调用方提供的 `{mode: campaign, level_id: level3, waves: 0}`，同时要求实际 `Battle`、`level3_zhujiazhuang_rts.gd`、64×56 地图和三段原墙数据一致。
- `candidate/scripts/run_map_state.gd`：精确接线候选。新增可选 `trusted_context` 参数，四处 `SceneryState` 实例传入同一调用方上下文；`finish_display` 返回须保留的 `display_adapter`、`display_requires_activation`。需要激活时 `complete=false`，不伪称最终安装完成。
- 两个 `.patch` 对应上述文件与来源快照的精确差异。没有修改 Root、HUD、WorldDisplay、Session、生命周期、关卡或游戏规则。
- `build_candidate.py` 可在此工程外目录重建候选、生成补丁并静态检查。它不运行 Git、Godot，不导入工程 Python 模块，不写工程。已存在且字节变化的来源快照会拒绝覆盖。

经典分支仍默认无 context，保持 `scenery_state_v2`、原材质/芦苇/通用验证函数和原拒绝行为。传入非空但不支持的 context 时明确拒绝，不能根据存档选择工厂；本候选没有扩大到其他七关。

## 已处理的实际 Level3 对象

固定工厂仍是 `CampaignScenery.new().setup(game_map)`。实际祝家庄还含 `CampaignGroundOverlay`；只添加 CampaignScenery、StorySign、地表装饰三个明确脚本种类，其余沿用普通 ScenerySprite、Stockade、Flag、静态 ArtEvent 的已有规则。StoryStall、StoryCrowd、CityWall、Passage、CanvasModulate、PointLight2D 等其他关对象继续拒绝。

三块牌示保存原文 `李家庄`、`扈家庄`、`祝家庄`；不把翻译后的绘制文字写入记录。`StorySign._ready` 的语言监听只允许自身固定 `_on_language_changed`，精确计数；其他外来输入、信号和未登记对象拒绝。恢复时使用原固定工厂，再核对全量父子顺序、固定字段、贴图描述和 Level3 静态 metadata，不执行故事状态事件。

墙体以现行 `paint_map` 的三段为准：`(20,0)→(20,16)`、`(20,20)→(20,26)`、`(20,30)→(20,55)`。不使用 `CampaignScenery.setup` 的旧四段 fallback，不改墙格、门洞或地图导航。面板数与绘制端点由原 `Stockade.panel_count` 生成后逐节点匹配。

工厂前后两次回读地形、基础阻塞、建筑占地、导航版本、五套导航的全部 solid/weight、高度 samples/texture 字节、装饰与非显示 metadata、资源/单位身份、规则字典和本局 RNG。合法的地图材质和图像缓存可由原 `_setup_coast_material` 重建；`natural_surface_contract` 按既有契约比较。调用方 MapState 的原有地图与导航二次审计原样保留。异常发生后丢弃私有树，不能在原战斗上调用恢复工厂。

## 下一步串行接线

1. 由安装内官方关卡白名单确定 context；Core 构造 `MapState.new(version, trusted_context)`，不要使用存档的 context 作为受信来源。当前 Level/Unit/Fog 依赖必须先准备完成。
2. detached 地图的 `finish_display` 返回 `display_adapter` 时，Core 必须持有同一个实例。候选的所有景物节点已禁用并阻塞信号；不能忽略返回值或在装载后自行默认恢复 process flags。
3. 私有世界挂载并完成 Root/HUD/任务布局后，在最终同步安装事务仍暂停时调用该实例 `activate_campaign()`。它重新检查真实节点顺序、ready 状态、禁用状态、语言信号和完整景物记录；只恢复先前保存的运行 flags。它不声明整世界就绪，也不打开玩家入口。
4. 失败时先调用 `dispose_campaign()`，再由外层释放整个私有世界；这会移除自己的 StorySign 语言监听和景物子树。激活后若另一个组件失败，整个 Battle 仍由外层回滚销毁，不能复用局部激活的树。
5. 扩展的 `SOURCE_PATHS` 纳入正式来源/导出身份合同，重新冻结本批源码和资产。原有已验证的 classic v3 session_settings、ward 序号顺序、Root 同帧激活协议都由根任务保留，本候选未触碰。

## 必须由引擎验证的具体假设

- 实际 Level3 的 `_sprites`、`_trees`、`_walls` 顺序与本候选对原 setup 的推导是否完全一致；路由资产有无缺失会影响节点数，必须使用实际安装内容，不允许补占位物规避比较。
- 真实挂载后 StorySign/Node2D 是否还有引擎必需的原生连接；若出现，按真实 owner、method、flags 和参数精确核对，不能放开任意信号。
- 恢复的非零树冠 tick、墙透明度和芦苇状态在跨帧禁用期是否保持；三种牌示的派生高度与实际保存点一致。
- 原经典 MapState/Scenery 回归、实际 Level3 单地图往返及恢复失败清理都尚待执行。静态检查不替代 GDScript 解析或任何实际往返。

可执行的下一层验证矩阵见 `TEST_MATRIX.md`。本目录没有当前引擎验证结果，没有通过/预期结果混记。
