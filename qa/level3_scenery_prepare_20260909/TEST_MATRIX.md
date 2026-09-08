# 景物候选原生测试矩阵

全部状态为 **NOT_RUN**。使用根任务统一冻结的 D 盘私有工程与私有 profile，`STEAM_DISABLED=1`；持有共享引擎锁。先原生导入解析候选，再运行组件回归。禁止使用真实玩家档、重新写真实账号统计或修改生产地图来使测试通过。

| 编号 | 实际输入/故障点 | 必须观察的结果 |
| --- | --- | --- |
| S01 | 原样经典 30 波 MapState/Scenery 既有组件夹具 | 原 `scenery_state_v2` 捕获、验证、恢复通过，旧字段不丢、旧拒绝行为保持；单独记录新冻结来源 |
| S02 | 普通菜单进入真实祝家庄，正常初始化地图和场景后在 HELD 边界捕获 | 实际 Level3 context、64×56、CampaignScenery、三牌示以及存在的地表装饰通过；记录全节点 kind/父索引与实际路由 |
| S03 | 由同一记录准备 detached Battle/Level/Unit/Fog/Map；调用候选 `finish_display` | 不部署或开局；地图/导航/高度/资源/RNG 前后相等；`complete=false`，持有唯一待激活 adapter |
| S04 | 私有树挂载后暂停等待 3 个 process frame，再 `activate_campaign` | 芦苇、可见性 tick、墙透明度、牌示位置不推进；挂载 ready/语言连接正确，激活前后完整景物记录一致 |
| S05 | 四种语言分别进入牌示可见区域，再捕获/恢复 | 保存原始简中 label；实际绘制跟随当前语言；不得把截图生成算目检，图片另行逐张检查 |
| S06 | 实际墙可见性衰减至 0.45、树冠遮挡变化时保存 | 对应 runtime alpha/tick 恢复；工厂重建固定端点/面板数，不能恢复成初始透明度 |
| S07 | 五套导航已有合法建筑占地和权重差异，且有同一墙门洞 | 每一格 solid/weight 与 block_count/nav_revision 精确相等；不重注册建筑或再 bake |
| S08 | 默认高度与显式平坦 QA profile 分别捕获 | 各自只在相同受信安装配置中恢复；有高度时 samples/texture 不变，平坦时不发明高度 |
| S09 | 捕获后重启至新的私有进程，重新加载同来源与贴图 | 外层提供相同身份；地图/景物记录一致；这仍是地图组件结果，不能计任务或整关通关 |
| N01 | 未传 context，却提供 campaign envelope | `SCENERY_SCHEMA`；不能静默挑选 CampaignScenery |
| N02 | 非空 context 的 level1/level8/custom 或 waves 类型不符 | `TRUSTED_CAMPAIGN_CONTEXT_UNSUPPORTED`；不回退经典 |
| N03 | context 正确但实际旧 level3 脚本、伪 id 或错误 Battle 脚本 | `LEVEL3_BATTLE_IDENTITY`，目标未改变 |
| N04 | 把三段墙替换成 setup 的四段 fallback，或改一个端点/尺寸 | `LEVEL3_MAP_IDENTITY`；不修改导航/墙使其迎合候选 |
| N05 | 记录新增/删除/重排节点、嵌套未知 child | schema/topology/固定工厂比较拒绝；不能跳过未知对象 |
| N06 | StorySign 原文替换成英译、任意 label 或过大字符串 | 固定字段拒绝；保留原记录与私有未安装状态 |
| N07 | 换成 StoryStall、StoryCrowd、CityWall、Passage、灯光节点 | `CAMPAIGN_NODE_KIND` 或 `SCENERY_NODE_UNSUPPORTED`；不扩大到其他关 |
| N08 | 篡改 stockade texture descriptor、路由/静态 metadata 或 shader uniform shape | 在固定工厂比较或材质验证中拒绝；记录不得选择 loader/resource |
| N09 | 外来 incoming callback、额外语言连接、信号参数/flags变化 | 精确 signal gate 拒绝；不忽略未知连接 |
| N10 | 自定义 material、input/process thread group、组或未知 child | 明确拒绝，不在恢复期执行 |
| N11 | `_sprites`、`_trees`、`_walls` 漏项/重复/顺序变化 | ownership arrays gate 拒绝 |
| N12 | 隔离候选工厂故障注入：改变 gold、defs、RNG、grid、height 或任一 nav cell | 工厂前后守卫失败，私有树丢弃；原源战斗、原槽、玩家档不变；注入不得进入生产源码 |
| N13 | 只合法重建 map.material 与自然地表图像缓存 | 不误报玩法变化，仍逐值核对材质与已有自然地表 contract |
| N14 | 挂载等待期间改一项 alpha/tick/processing/metadata | `CAMPAIGN_PREPARED_STATE_CHANGED` 或相应边界拒绝；不得用 activation_plan 覆盖实测值掩盖修改 |
| N15 | 挂载等待期间添加未知节点、删除原节点或开 signal gate | topology/gate拒绝；旧菜单仍持有 |
| N16 | 在未挂载、未暂停、物理帧或重复调用情况下激活 | `CAMPAIGN_ACTIVATION_PHASE`；不重放动作 |
| N17 | factory失败、挂载后失败、成功激活后另一组件失败三个回滚点 | 自身 StorySign 全局连接消失、无悬空 target；整个私有树由外层销毁；不得复用局部树 |
| N18 | 丢弃 MapState 返回的 adapter 或未调用激活便尝试交付世界 | 外层集成检查拒绝；`complete=false` 不能当成功世界 |
| N19 | 损坏既有经典 scenery_schema、未知节点/贴图/二进制 | 保留既有负例门槛；不因新增 Campaign 代码放宽 |

每批至少记录：实际源码/引擎/内容身份；受测候选 SHA；预期与实际退出码；Godot ERROR/Parse Error；测试断言与 failure code；source 与 target 地图/nav/资源/RNG 摘要；原始 capture 和 recapture 的差异；三个 owner 数组；回滚后 surviving nodes 与语言监听。截图保存和人工目检分开。

不要把 S02 的普通地图初始化与 S03 的恢复混为同一操作：前者可走真实新关初始化，后者必须只使用已捕获的地图状态与固定纯显示工厂，不能再调用 paint/decorate/bake/deploy/on_start。
