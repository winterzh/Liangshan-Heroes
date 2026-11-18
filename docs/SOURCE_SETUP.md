# 源码设置与换机（2026-10-30）

Windows 战役和驻守入口在加载覆盖层绘制后提交原异步美术请求。加载首帧和战场首帧单独量测，程序退出会复原加载阶段帧率限制。 [原生加载验证](../qa/battle_entry_timing_20261116/windows_loading_first_frame_ef991d10.json)

Windows Steam 预设使用的原生依赖由 `tools/build_steam_stats_reader.py` 重建，使用 Visual Studio x64、原锁定的 godot-cpp 和 Windows 的 bcrypt 系统库，构建后核对 `vendor/steam_stats_reader/provenance.json`。加速路径只产生同格式完整 SHA-256，Windows 源码环境仍支持 Godot 摘要回退。真实只读探针复用安装器创建的临时 `.godot` 目录。冷启动候选 c0a3b748 的冻结六文件、原生续玩、只读 Steam 及十分钟水战可在同一 [整合验收收据](../qa/battle_entry_timing_20261116/windows_candidate_c0a3b748.json) 回读。 [构建证据](../qa/battle_entry_timing_20261116/windows_sha256_bridge.json)

Windows 整合候选 89dfee7a 的六文件身份、十分钟水战及同一原生 EXE 的续玩回执见 [Windows 验收收据](../qa/campaign_sustained_performance_20261116/windows_pack_89dfee7a.json)。续玩驱动、资料目录和覆盖配置仅挂载在隔离副本。

Windows Steam 包复用单位美术的本局查询结果。`Art.set_runtime_alias()` 沿用原清理入口。金矿每个物理步保留原时钟，采矿震动期间才需要持续刷新画面。[定向对照](../qa/campaign_sustained_performance_20261116/README.md#windows-战役资源重绘与美术查找)

Windows 正式模板的同进程新战斗借用启动预读的身份并复核当前文件与原生依赖。空身份回落到完整后台扫描。只读续玩准入和保存边界继续使用各自验证路径。 [原生重进复验](../qa/battle_entry_timing_20261116/README.md#windows-同进程重进优化)

PC 战役反馈由 HUD 根据当前章节及战报生成，显示安装内容指纹并省去账号、旧槽和路径数据。四语位于 `assets/localization/battle_entry_review_20261116.json`。 [反馈文本验证](../qa/battle_entry_timing_20261116/README.md#windows-战役反馈文本)

高俅关跨章回顾从 `Campaign` 的江州正式胜利进度读取。同局两项达成由原战果投影记录在原有 CFG，旧最好单局可直接识别。[跨章验证](../qa/campaign_fire_readiness_20261116/README.md#pc-高俅关回忆江州)

连环马 Windows Alt 加右键拖动布阵沿用原单位移动和守备指令，拖线两端列为临时显示字段。保存时只保留已下达的移动和守备结果。 [布阵验证](../qa/campaign_cavalry_escort_20261116/README.md#pc-钩镰手画线布阵)

祝家庄新局右键撞车护卫复用现有的部队命令和守备行为。`ram_escorts` 存在关卡组件中，保存两个原实体引用。精确旧正式版 `26735223` 的战役组件保留原字段。 [护卫验证](../qa/campaign_siege_20261116/README.md#pc-撞车指定护卫)

祝家庄正门牵制沿用原关卡计时、守军槽与任务事件。仅 Windows 新局登记牵制规则，旧战斗继续原守军行为。新增 `feint` 和 `returning` 属于已审计的关卡状态。四语词条在 `assets/localization/zhujiazhuang_route_status.json`。[定向与存读档](../qa/campaign_siege_20261116/README.md#pc-正门牵制和重玩建议)

PC 旧战役槽的兼容身份定义在 `scripts/run_campaign_save_version.gd`。保存和结算继续使用原局身份，原生载荷校验按当前安装执行。八章早期迁移夹具及原正式待应用结算已在独立 Windows 资料目录验证。源码宿主需导入快活林六张原画摊位，避免重建时采用缺图回退。 [旧档验证](../qa/battle_entry_timing_20261116/README.md#build-26735223-战役续玩兼容)

江州北哨报信使用 Windows 新局的既有任务事件和原守军槽。原战斗的路径、任务事件和追兵倒计时经现有连续存档读写。词库来自 `assets/localization/campaign_pursuit.json`。 [定向验证](../qa/campaign_pursuit_20261116/README.md#pc-北哨报信)

Windows 存档发布检查使用发行 EXE 的独立桌面和资料目录，按保存及重启两进程执行。编辑器宿主与原生模板提供的回调名称存在差异，原生结果须单独落档。 [原生保存验证](../qa/battle_entry_timing_20261116/README.md#windows-原生保存复验)

Windows 源码版可从「开始战役」进入八幕选章。正式版续玩入口复用原存档验证，读回成功时显示章节。野猪林首局移动提示只在新战斗启用。进场脚本现覆盖野猪林、祝家庄、驻守和 1v1，记录模式面板、场景绘制、可下令与首个右键回显。[验证入口与状态](../qa/battle_entry_timing_20261116/README.md#pc-战役入口首批)

Steam Windows 正式 Build 26735223 使用冻结源码 492e6437 的原六文件候选，Manifest 9099660322002044845。手机确认后 default 回读和四语公告通过。服务器隔离下载六文件和无窗口启动已通过。后续只读校验确认本机 Steam 已安装同一 Build、Manifest 及六文件。客户端启动与带账号战役终局另验，完整范围见[本批记录](STEAM_UPDATE_20261118.md)。

Steam 上传来源为冻结提交 492e6437 的原六文件候选，Build 26735223、Manifest 9099660322002044845。Preview 和服务器清单核对一致。正式分支、公告和客户端验收的续接状态见[本批记录](STEAM_UPDATE_20261118.md)。

Steam 正式版发版单绑定 Windows 冻结源码、发行载荷和回退 Build。复核六文件 SHA-1 和交付 ZIP SHA-256 后保留当前候选，实际上传之前重新确认正式分支回退目标。 [正式版发版单](STEAM_CANDIDATE_20261117.md#正式版发版单)

Android 触控离线验收从 Windows 候选的冻结源码导出。仅在私有导出中变更包名、更新器及平台依赖，重建 Android 内容身份，安装资料与正式包分开。 [Android 本地验收包收据](../qa/android_controls_performance_20260925/android_touch_candidate_492e6437.json)

Windows 候选的本地首次试玩用 start_windows_playtest_492e6437.cmd，选择 P01、P02 或 P03，进程独立设置 APPDATA、LOCALAPPDATA 和临时目录。直接启动现有原生候选且禁用 Steam。 [本地试玩短检](../qa/battle_entry_timing_20261116/windows_playtest_launcher_492e6437.json)

当前 Windows 候选使用六文件的精确 EXE 交付副本。菜单短检由 Godot 宿主加载同一编译包，原生 EXE 另以分开的离线资料验证八章、驻守、清敌及主菜单。 [新版进场验证](../qa/battle_entry_timing_20261116/README.md#windows-修复候选的发版短检)

快活林的摊牌固定标识跟随原画摊位进入场景快照，仅在该关摊位接受。恢复按关卡工厂重建后比较保存字段，禁用其它节点的摊牌元数据。 [Windows 续玩记录](../qa/campaign_short_player_continue_20261117/README.md#windows-短篇续玩和快活林修复)

连环马在已验 SHA-256 的 Windows 编译包中核对两路波次、原骑兵和护军及其指令、教场和断援状态。外部探针替换平台入口条件，战斗、存读档和奖励仍用候选包原代码。 [连环马续玩收据](../qa/campaign_cavalry_escort_20261116/player_continue/windows_candidate_fa4084ff.json)

江州在已验 SHA-256 的 Windows 编译包中检查二人分次登船。外部驱动把保存点放在首人登船后，恢复及结算使用候选包的原代码。 [江州续玩收据](../qa/campaign_pursuit_20261116/player_continue/windows_candidate_fa4084ff.json)

高俅关用已验 SHA-256 的 Windows 编译包完成火攻押俘存读档与实际结算。外部探针替换平台入口条件，原船身份、押俘任务及奖励事务来自候选包。 [高俅关续玩收据](../qa/campaign_fire_readiness_20261116/player_continue/windows_candidate_fa4084ff.json)

大名府在已验 SHA-256 的 Windows 候选中验证实际保存、恢复、战斗和结算。外部离线探针只替换平台入口条件，原存读档和数据路径来自候选编译包。 [大名府续玩收据](../qa/campaign_wounded_selection_20261116/player_continue/windows_candidate_fa4084ff.json)

高俅帧时复用既有测试路线，固定窗口、镜头、随机种子和特效。编辑器宿主挂载校验过 SHA-256 的候选 EXE；三份外置探针只调整两处继承路径。逐帧原件及宿主依赖校验见收据。 [十分钟帧时收据](../qa/campaign_sustained_performance_20261116/windows_pack_fa4084ff.json)

Windows Steam 候选 fa4084ff 按追踪文件白名单重新导入并导出。在独立原生启动与精确编译包中核验，目录含原四个二进制和两个许可文件。 [本地候选验证](../qa/battle_entry_localization_20261116/windows_campaign_candidate_fa4084ff.json)

三章短篇结算沿用战斗结束时冻结的原始任务状态。黄泥冈到场人数与原收队条件共用出口半径，快活林的交还结果读取任务事件。文案源分属 campaign_escort_arrival.json、campaign_transport_groups.json 与 campaign_counter_window.json。 [短篇战果检查](../qa/battle_entry_localization_20261116/README.md#三章短篇的结算战果)

江州与高俅关的路线结算读原队伍、任务事件和旗标，按已有冻结报告机制换语重绘。词库源为 campaign_pursuit.json 与 campaign_flagship_escort.json。 [江州与高俅战果](../qa/battle_entry_localization_20261116/README.md#江州与高俅的路线结算)

大名府结算沿用既有南门、牢院、追兵与两条撤离事件，冻结单局战果供四语重新显示。没有新增存档字段，词库使用 campaign_coordination.json。 [大名府路线战果](../qa/campaign_wounded_selection_20261116/README.md#大名府结算的路线战果)

连环马的结算读取既有两路出击、剩余骑兵、断援事件、协同破阵数和擒将事件。列出的延迟为本局排定的出击时间减去初始时刻。四语取自 campaign_cavalry_escort.json。 [两路战果](../qa/campaign_cavalry_escort_20261116/README.md#连环马的两路结算战果)

Windows 候选沿用 Windows Steam 预设。候选 `04c8876b` 的实际祝家庄通关、四语结算和独立野猪林读档均使用同一编译包，Steam 接口采用隔离离线配置。 [整合候选收据](../qa/campaign_siege_20261116/windows_campaign_candidate_04c8876b.json)

祝家庄结算从已保存的战役状态生成三条路线战果，先冻结原句和参数，再按当前语言渲染。未增加存档字段。四语来自 campaign_siege.json，严格重建后保持既有 4,986 条译文。 [战果核对](../qa/campaign_siege_20261116/README.md#祝家庄结算的路线战果)

战役续玩任务栏的拉伸控件在原生挂载前后沿用锚点及偏移，固定锚点控件仍恢复尺寸。继续捕获并校验现有布局字段。组件夹具补齐当前 HUD 所用的触屏标志和底栏边界。 [读档布局收据](../qa/campaign_short_player_continue_20261117/native_entry_geometry.json)

Windows Steam 本地候选 `5acd8be2` 由 Godot 4.6.3 导出，原生启动与六件指纹已核对。精确编译包的续玩行为用离线平台替身走野猪林，三次独立进程沿用玩家入口和实际结算。 [候选收据](../qa/battle_entry_timing_20261116/windows_candidate_5acd8be2.json)

Windows 黄泥冈正常出征时，角色站姿之外也后台读取七名商贩及对白查找的吴用常服头像。结果进入原贴图预读缓存，英雄栏与剧情继续按原人物身份选图。 [黄泥冈首屏头像](../qa/battle_entry_timing_20261116/README.md#黄泥冈首屏头像后台读取)

Windows 4cc25919 采用 Godot 4.6.3 导入与 Windows Steam 预设导出。安装身份、原生离线启动、三条编译包入口和六文件指纹已核对。 [候选收据](../qa/battle_entry_timing_20261116/windows_candidate_4cc25919.json)

祝家庄的祠堂和地饰沿用关卡原路线与 PNG／AtlasTexture 解析。Windows 正常出征期间把其纹理加入已有地表读取队列，保存到场景就绪。 [祝家庄布景](../qa/battle_entry_timing_20261116/README.md#祝家庄开场布景贴图后台读取)

Windows 正常出征时，黄泥冈的七名商贩和祝家庄的林冲、六名俘虏在加载期间读取东南待机帧，通过现有动画解析缓存交给开场绘制。使用 Godot 4.6.3 与隔离档案复核缓存、原 SpriteFrames 和两关返回。 [祝家庄首帧](../qa/battle_entry_timing_20261116/README.md#祝家庄开场角色帧后台读取)

地表遮罩生成对墙基、台阶和码头的检查用一次局部网格，保留相邻保护。八章布局及自然和回退材质的对照由 Godot 4.6.3 运行。[复现与记录](../qa/battle_entry_timing_20261116/README.md#地表遮罩硬边复用)

`413b95bb` 的精确编译包支持六次连续开打和返回。固定本机 1280×720，按真实菜单与 HUD 测量。该次额外记录进入后最长绘制间隔，供定位战场挂载和首轮绘制停顿。[记录](../qa/battle_entry_timing_20261116/windows_mode_switch_413b95bb.json)

当前 Windows 本地候选 `413b95bb` 以 Godot 4.6.3 导出。精确编译包目录的四语词库与冻结输入逐字节一致，并含所需字体和许可。独立核对实际 Windows 原生离线启动。[收据](../qa/battle_entry_timing_20261116/windows_candidate_413b95bb.json)

大名府完整战报文案增加十二条，来自 `campaign_coordination.json`。严格重建与全库静态校验通过，既有 4,974 条译文逐项一致。运行检查覆盖隔离源码 HUD 和结算。[验证](../qa/battle_entry_localization_20261116/README.md#大名府战报四语)

江州旗标、救援记录及高俅举火和结局的十二条源句由战役分片生成。静态词库校验完成，已有 4,962 条译文逐项一致。实际 Windows 发行包与 Steam 仍待验证。[记录](../qa/battle_entry_localization_20261116/README.md#江州与高俅界面四语)

连环马两路战报由 `campaign_cavalry_escort.json` 提供六条完整源句。严格重建与全库静态核对通过，既有 4,956 条译文逐项一致。本次运行检查覆盖连环马战报和结算的四语切换。[验证](../qa/campaign_cavalry_escort_20261116/README.md#两路战报四语)

Windows 随机驻守会在加载首帧后保存偏好。旧配置恢复、原有事务及其他调用方默认调度沿用原入口。本地 Windows `e5bf9414` 六文件候选已有导出和原生启动收据。[验收](../qa/battle_entry_timing_20261116/windows_candidate_e5bf9414.json)

Windows 本地候选 `72952e43` 使用 Godot 4.6.3 的 Windows Steam 预设，原生 EXE 离线启动通过。另以编辑器宿主加载同一编译包，核对全部八章准入、野猪林续玩以及两条进场路线。实际 Steam 安装包前台与线上统计待验。[收据](../qa/battle_entry_timing_20261116/windows_candidate_72952e43.json)

Windows Steam 玩家战役准入现包含全部八章。野猪林、黄泥冈和快活林的隔离源码探针只替换平台启用判断，沿用玩家准入。Windows 发行包和 Steam 客户端待验。[三章验证](../qa/campaign_short_player_continue_20261117/README.md)

江州已加入 Windows Steam 玩家战役续玩范围。隔离探针仅替换平台启用判断，经过同一玩家关卡准入，已验证会合后保存、重启恢复、登船及结算后的旧档拒绝。实际 Windows 发行包与 Steam 客户端待验。[验证](../qa/campaign_pursuit_20261116/README.md#江州玩家续玩)

高俅已加入 Windows Steam 玩家战役续玩范围。Godot 4.6.3 在隔离环境仅替换 Steam 平台启用判断，沿用玩家关卡准入。验证原船载俘、主菜单续战及胜利后旧档拦截。实际 Windows 发行包和 Steam 客户端待验。[验证](../qa/campaign_fire_readiness_20261116/README.md#高俅玩家续玩)

大名府已加入 Windows Steam 玩家续玩范围。Godot 4.6.3 隔离源码只替换平台启用判断，经过同一玩家关卡准入。保存、独立恢复、结算和终局拒绝通过。实际 Windows 发行包和 Steam 客户端待验。[验证](../qa/campaign_wounded_selection_20261116/README.md#大名府玩家续玩)

连环马与祝家庄均已加入玩家战役续玩范围。本轮在隔离用户目录以 Godot 4.6.3 验证连环马暂停保存、主菜单恢复及胜利后旧档拦截。运行源码只替换 Steam 启用判定供离线验证，仍经过玩家关卡准入。Windows 新发行包和真实 Steam 客户端待验。[验收](../qa/campaign_cavalry_escort_20261116/README.md#连环马玩家续玩)

Windows Steam 版保存偏好复用启动校验的身份。每次复核可执行文件标记、挂载与原生绑定，源码环境走现有校验。[随机波次开战对照](../qa/battle_entry_timing_20261116/README.md#随机波次偏好保存与进场)

战役结算 Windows 本地候选按 `a51c3453` 封装，Windows Depot 六文件已核对。[Windows 结算候选回执](../qa/campaign_siege_20261116/settlement_integration/windows_candidate_a51c3453.json)

战役结算采用独立候选验证过的模块。发行事务范围由 `SteamRunPolicy.uses_campaign_transactions()` 声明。Windows Steam 的首次战斗入口可消费一次后台启动校验结果，复用时复核安装状态和文件标记。[战役结算源码整合](../qa/campaign_siege_20261116/README.md#战役结算源码整合)

离线结算候选调整 `continue_flow.gd`、`steam_service.gd` 和 `run_campaign_progress_coordinator.gd`。联机统计发布前回读原账号的本地结算凭证。[历史 Steam 结算的离线启动](../qa/campaign_siege_20261116/README.md#历史-steam-结算的离线启动)

独立结算候选基于 `4ac1218a` 和旧 `20261117_081141_c3c2eb2f`，记录 24 个覆盖文件的摘要。启动安装校验在后台执行。[结算中断候选复验](../qa/campaign_siege_20261116/README.md#现行版本的结算中断候选)

Windows 续玩样板使用 `2115c08f` 构建，Windows Depot 由四个构建文件与两份已核对许可证组成。[Windows 续玩候选回执](../qa/campaign_siege_20261116/player_continue/windows_candidate_2115c08f.json)

玩家续玩章节范围由 `scripts/run_official_restore_profile.gd` 声明，菜单与恢复事务共用该范围。首章样板为祝家庄。[祝家庄玩家续玩入口](../qa/campaign_siege_20261116/README.md#祝家庄玩家续玩入口)

战役中途档的驻守英雄上限偏好由 `scripts/run_slot_store.gd` 按存档类型校验，战役接受菜单可产生的四人或六人值。[从史诗驻守返回后的战役续玩](../qa/campaign_siege_20261116/README.md#从史诗驻守返回后的战役续玩)

祝家庄触屏提示来自 `scripts/levels/level3_zhujiazhuang_rts.gd`，四语源分片为 `assets/localization/zhu_touch_controls.json`。[祝家庄触屏操作](../qa/campaign_siege_20261116/README.md#前营采金接应与撤离的触屏提示)

连环马教场和下钩提示来自 `scripts/levels/level4_lianhuanma_rts.gd`，四语源分片为 `assets/localization/lianhuanma_drill_controls.json`。[教场阶段与触屏下钩](../qa/campaign_cavalry_escort_20261116/README.md#教场阶段与触屏下钩)

大名府查看栏与办理共用南门和牢院守军距离；仅查看栏限制玩家视野。词库分片 `daming_gate_controls.json`。[大名府夺门与开枷提示](../qa/campaign_coordination_20261116/README.md#火号后的夺门与开枷提示)

任务旗标绘制和组队轻点共用 `MissionMarker.RING_RADIUS`，实际到达与资格沿用任务引擎。高俅新增 11 条四语，来源 `gao_fire_controls.json`。[高俅举火与双船撤离](../qa/campaign_fire_readiness_20261116/README.md#触屏举火与双船撤离)

江州登船检查与查看栏共享 150 距离。仅查看栏按玩家视野筛选敌人，实际办理沿用原判定。五条四语来自 `jiangzhou_boarding_controls.json`。[江州登船提示](../qa/campaign_pursuit_20261116/README.md#登船点危险提示与触屏指令)

三个短篇补齐 18 条四语，分片 `campaign_short_controls.json`。黄泥冈「下一步」复用任务定位，快活林用实际技能名提示动作，野猪林按 HUD 模式显示拦棍和撤离指令。[三个短篇的任务提示](../qa/battle_entry_timing_20261116/README.md#三个短篇的任务提示)

任务栏根据 HUD 输入模式选用触屏或键鼠文案。六条四语文案来自 `campaign_touch_instructions.json`。触屏重叠旗标沿用现有任务令牌和右键指令入口。[触屏任务旗标](../qa/battle_entry_timing_20261116/README.md#触屏任务旗标与提示)

使用 `455f2c62` 构建 Windows Steam 本地候选。包含四语词库和黄泥冈接车、快活林冷却、大名府分批撤离恢复修正。[Windows 战役小修候选](../qa/battle_entry_timing_20261116/README.md#windows-战役小修候选)

黄泥冈掉车续玩复用自然战斗驱动，在未接手重车时走隔离菜单保存。恢复比较原车、原人及旗标，车轮转角按 Unit 约定重建。[黄泥冈重车落地后续玩](../qa/campaign_transport_groups_20261116/README.md#实战重车落地后续玩)

黄泥冈重车接手旗标与原车重合时，普通右键由战场输入继续走既有任务移动路径。关卡以活跃接手动作和原车身份限制此交互。[黄泥冈载货伤亡实战](../qa/campaign_transport_groups_20261116/README.md#载货途中被击倒与原车接力)

黄泥冈的待接重车由已装货、未交付、当前取车标记派生。两条四语文案来自 `huangnigang_loaded_relay.json`；catalog 严格构建与当前差异仅为这两条。[黄泥冈掉车定位](../qa/campaign_transport_groups_20261116/README.md#重车掉落后的定位)

野猪林强救探针复用暂停保存与主菜单读取，覆盖解差由制服状态转入非战斗护送。[野猪林强救解缚续玩](../qa/campaign_escort_arrival_20261116/README.md#提前强救解缚途中续玩)

野猪林续玩探针通过隔离暂停菜单保存真实北路歇脚令，独立主菜单继续同一未完成行程。[野猪林歇脚途中续玩](../qa/campaign_escort_arrival_20261116/README.md#歇脚途中保存与续玩)

快活林反击提示读取技能槽运行中的 `cd_t`。续玩探针在实际酒路换步后保存，独立进程继续同一破绽并检查施放前后的提示。[快活林反击续玩](../qa/campaign_counter_window_20261116/README.md#酒路反击窗口续玩)

黄泥冈续玩探针沿用强夺实战路线，在首辆接力车实际装货后用隔离暂停菜单保存，第二进程走主菜单继续。[黄泥冈强夺续玩](../qa/campaign_transport_groups_20261116/README.md#强夺装货接力后续玩)

高俅续玩探针可用 `GAO_MENU_CHECKPOINT=capture` 在张顺真实接俘后保存。第二进程沿用存档并使用原任务和移动指令完成靠岸交接和押堂。[押俘续玩](../qa/campaign_fire_readiness_20261116/README.md#张顺接俘后续玩)

高俅内港举火续玩使用 Windows Godot 4.6.3 Compatibility、独立档案和隔离菜单。探针在真实点火后保存，再从主菜单读档，继续实际撤离、返港和收兵。[高俅续玩](../qa/campaign_fire_readiness_20261116/README.md#内港举火后续玩)

大名府单位契约保存已撤离的原伤员。整局存档在捕获及恢复两侧检查对应事件，使用现有单位、关卡和任务字段。复跑强攻设 `DAMING_MENU_ROUTE=assault`，沿用隔离的双进程战役菜单探针。[大名府强攻续玩](../qa/campaign_wounded_selection_20261116/README.md#强攻后分批撤离续玩)

大名府续玩复用举火路线自动驾驶与正式存档按钮。Windows Godot 4.6.3 使用独立档案，第一进程保存退出，第二进程由主菜单继续。探针只读取守军和伤员状态，撤离走既有玩家指令。[大名府举火夺门后续玩](../qa/campaign_wounded_selection_20261116/README.md#举火夺门后续玩)

Steam Windows Build `26719792` 从 `65ac43ac` 的独立检出导出。发行 ZIP 和 Windows Depot 各六个成员，服务端 Manifest `3426323641209633325` 的文件大小与 SHA-1 已逐项核对。[发行来源和收据](STEAM_UPDATE_20261117.md)

江州存档的单位图只为开船按钮登记关卡引用。定位按钮沿用任务面板序列化以及章节白名单。复跑使用 Windows Godot 4.6.3 渲染器和独立档案，不接入 Steam 帐号。[江州会合后续玩](../qa/campaign_pursuit_20261116/README.md#白龙庙会合后续玩)

江州白龙庙定位用任务固定按钮，提示和会合判定读同一四人队伍与到场距离。译文来自 `jiangzhou_bailong_meeting.json`。[江州会合进度](../qa/campaign_pursuit_20261116/README.md#白龙庙会合进度)

继续入口从主菜单接管后台校验，由 ContinueFlow 释放线程。发现预读时的 EXE 已变化会重做校验，档案仍由原 Session 校验与安装。[继续读取验证](../qa/battle_entry_timing_20261116/README.md#继续上次战斗后台校验)

使用 `d645e44f` 封装。Windows 原生 EXE 离线启动通过。编译包实际运行六种入口、四语和六次正常返回，祝家庄可定位可采矿点，黄泥冈原存档文字可按当前语言显示接力报告。[本地 Windows 候选](../qa/battle_entry_timing_20261116/README.md#windows-含矿点与接力补译的候选)

同源独立候选 `3954f0ba` 的 7,187 个文件在冷导入前后相同。结算中断夹具通过原启动恢复入口补写，第三进程比对进度文件和结算回执摘要。[终局恢复候选和回执](../qa/campaign_siege_20261116/README.md#终局恢复候选)

新战役结算候选以 `188dad91` 为现行基线，复用原私有候选的结算模块和已核对 UID。复建来源及四文件合并差异留在 QA 目录。[终局恢复候选](../qa/campaign_siege_20261116/README.md#终局恢复候选)

继续菜单在读到实际档案后识别模式。隔离 QA 条件下，官方战役由对应已安装工厂准备定义，并等待恢复布局。公开菜单沿用经典 30 波驻守限制。[祝家庄菜单续玩](../qa/campaign_siege_20261116/README.md#菜单续玩与本地进度回读)

战场保存接受弹道脚本在创建时设置的线性 MipMap 过滤，复用既有弹道状态格式。祝家庄续玩探针传入私有目录并使用当前安装内容身份，完整路径由四个独立渲染进程验证。[祝家庄实战撤离续玩](../qa/campaign_siege_20261116/README.md#实战撤离续玩)

祝家庄前营金矿定位沿用白名单任务按钮，读取原采集目标、资源余量和当前视野。译文见 `zhujiazhuang_camp_gold.json`。[祝家庄前营金矿](../qa/campaign_siege_20261116/README.md#前营金矿定位)

黄泥冈在正常进关和冷准备的共用入口登记原有伤亡接力模板。覆盖七星、白胜和七车实际担数，沿用四语词库和原报告存储格式。[黄泥冈接力文案](../qa/campaign_transport_groups_20261116/README.md#伤亡接力报告四语)

使用 `d8085327` 封装。原生 EXE 离线启动通过，同一编译包验证了三关战役与三种自由模式，四语加载、六次返回和运行身份一致性均通过。实测高俅首批预警和两个定位、祝家庄外营查看与迷雾约束，完整词库摘要与构建输入一致。[最新 Windows 候选](../qa/battle_entry_timing_20261116/README.md#windows-战役提示整合候选)

祝家庄打法提示沿用 HUD 的 unit_tactical_hint，受当前视野与原角色状态约束。词条存于 zhujiazhuang_scouting_hints.json。[祝家庄侦察查看](../qa/campaign_siege_20261116/README.md#侦察后查看打法)

高俅预警复用 waves.warned 和原有战场状态。两个定位按钮沿用通用 Mission 表现层描述符。四语载入 gao_wave_warnings.json。[高俅三批预警与定位](../qa/campaign_flagship_escort_20261116/README.md#开战前预警与两线定位)

高俅撤离后失船复用既有实战驾驶。从隔离档案运行新增证据目录中的 probe.gd，可通过常规船队指令复现撤离、失船和付费重新集结。[高俅撤离后失船实跑](../qa/campaign_naval_recovery_20261116/README.md#两船安全撤离后失船)

使用 `d05b01d0` 封装。离线原生启动通过，四语、四类模式和黄泥冈重进由同一编译包验证。黄泥冈首次启动前七套站姿进入缓存，重进复用，六次均可回菜单。游戏内光标使用 CPU 图像。[最新 Windows 候选](../qa/battle_entry_timing_20261116/README.md#windows-黄泥冈首帧优化发行候选)

黄泥冈部署和菜单预读共用七星名单，按既有路由查找站姿并写入原生动画缓存。[黄泥冈首帧分段](../qa/battle_entry_timing_20261116/README.md#黄泥冈首帧站姿后台读取)

战场光标由同一套 RGBA8 图像交给 Input，回菜单恢复系统光标。Windows 真渲染验证覆盖七种图像和两类入口。[进场分段与光标回读](../qa/battle_entry_timing_20261116/README.md#windows-进场分段与光标)

使用 `7341bd27` 封装，实际运行输入与长测的 `88e03a75` 相同。离线原生启动通过，四语、四入口及高俅重进由同一编译包验证。默认加载上限 72 FPS，既有 45 FPS 上限保留。五次正常返回。[最新 Windows 候选](../qa/battle_entry_timing_20261116/README.md#windows-含-72-fps-加载上限的候选)

Windows 主菜单加载默认 72 FPS 批次完成六路 30 分钟源码验收，沿用 Vulkan 1280×720 和独立档案。实跑旧工具报私有内存趋势未通过。现行分析从预热快照起算，继续采集冷启动峰值。[72 FPS 长测结果](../qa/battle_entry_timing_20261116/README.md#windows-72-fps-模式切换三十分钟)

Windows 菜单加载阶段按 72 FPS 限流并应用原先更低的全局设置。场景切换通过现有退出路径恢复原值，测试收据另保留 60 与 72 的分段对照。[Windows 加载帧时分段](../qa/battle_entry_timing_20261116/README.md#windows-加载动画与场景切换帧时)

候选 7bd1f0e5 的四语入口验证直接挂载 SteamDepot 中交付 EXE 的编译包，使用独立 Godot 宿主及隔离档案。[当前 Windows 四入口验证](../qa/battle_entry_timing_20261116/README.md#windows-候选四入口与重复进场)

候选 7bd1f0e5 的 SteamDepot 子目录含精确六文件；机器清单和 Git 回执在载荷目录外。[Windows Steam 候选交接](STEAM_CANDIDATE_20261117.md)

可用 tools/verify_platform_exports.py 的 pck_inventory、check_inventory 和 inspect_windows 阅读交付 EXE。核对成品翻译原始字节时，结合目录大小与摘要定位包内载荷并比对冻结源码。[Windows 候选的成品包核对](../qa/battle_entry_timing_20261116/README.md#windows-候选成品内容核对)

Windows 候选 7bd1f0e5 已用跟踪运行输入构建，在独立档案离线启动。原生文件校验及导出摘要见候选收据。[Windows 本地候选 7bd1f0e5](../qa/battle_entry_timing_20261116/README.md#windows-本地候选-7bd1f0e5)

源码身份清单仍两遍完整枚举，第一遍计算逐文件哈希，第二遍读取首遍记录复核路径、大小、修改时间及规范指纹，两遍分别建表。[源码清单组装优化](../qa/battle_entry_timing_20261116/README.md#源码清单组装优化)

Windows 源码进场校验的 DirAccess 只在源码快照期间复用。两遍枚举和逐文件哈希保留，Windows 发行包与其他宿主沿用原入口。[Windows 源码目录校验复用](../qa/battle_entry_timing_20261116/README.md#windows-源码目录校验复用)

模式切换长测保留六条既有路线，取当前主菜单异步入口及战斗 HUD 返回信号。在独立用户路径断开 Steam 和内容自动更新。[30 分钟模式切换验收](CAMPAIGN_MODE_SOAK_QA.md)

Windows 本地候选 `7ef55d27` 来自白名单快照。构建提交与高俅十分钟性能验收提交只相差 QA 和项目文档，核对四个发行文件后归档。[Windows 本地候选 7ef55d27](../qa/battle_entry_timing_20261116/README.md#windows-本地候选-7ef55d27)

高俅稳定源码复测沿用现有的正常速度 600 秒探针，汇总逐分钟帧耗时、实际出兵和付费生产。[高俅稳定分支十分钟结果](../qa/campaign_sustained_performance_20261116/README.md#单位绘制优化后的十分钟复测)


单位绘制对照在隔离渲染进程内切换父提交与候选绘制函数，记录相同回调数量、画面 SHA-256 和候选源码摘要。对照结束复查生产脚本已移除探针。[单位绘制复用验证](../qa/campaign_sustained_performance_20261116/README.md#单位绘制复用建筑贴图和标记判断)

高俅后半场使用稳定源码的独立诊断进程，在第 397–412 和 480–540 秒启用回调采样。完成后核对所有临时插桩脚本的恢复指纹。[高俅后半场分段采样](../qa/campaign_sustained_performance_20261116/README.md#高俅后半场分段采样)

高俅稳定源码复测沿用现有的正常速度 600 秒探针，汇总逐分钟帧耗时、实际出兵和付费生产。[高俅稳定分支十分钟结果](../qa/campaign_sustained_performance_20261116/README.md#官军战船预读后的十分钟复测)


核对 bd057018 候选发行文件后，以独立离线目录和内置 LEVEL=5 入口捕获原生英文视口。收据包含发行 EXE、原生日志与视口图的 SHA-256。[Windows 原生英文高俅关](../qa/battle_entry_timing_20261116/README.md#windows-原生英文高俅关)

Windows 候选由当前独立工作树的 6,550 项跟踪运行文件生成。四个发行文件已拷贝至本地候选目录，逐项核对文件长度和 SHA-256。[当前 Windows 本地候选](../qa/battle_entry_timing_20261116/README.md#windows-本地候选-bd057018)

Windows 高俅战斗使用已有启动预读队列准备官军战船两张转向贴图。方向路径由 CampaignArt 给出，战场从同一 Art 贴图路由取出预读结果。[首批攻防分段与战船预读](../qa/campaign_sustained_performance_20261116/README.md#首批攻防分段与战船预读)


高俅稳定源码复测沿用现有的正常速度 600 秒探针，汇总逐分钟帧耗时、实际出兵和付费生产。[高俅稳定分支十分钟结果](../qa/campaign_sustained_performance_20261116/README.md#迷雾与地形优化后的十分钟复测)


平坦格标记由高度样本生成，在恢复高度数据或修改样本时重算。坡面继续原插值，存档和地表纹理继续使用原格式。[地形高度定向复测](../qa/campaign_sustained_performance_20261116/README.md#平坦地形直接读取高度)


布景迷雾格索引按节点实例、逻辑位置、净空高度和地图尺寸重新计算，显隐读取当次视野数据。存档继续使用已有的布景与迷雾字段。[布景迷雾复测](../qa/campaign_sustained_performance_20261116/README.md#布景迷雾检查格复用)


迷雾刷新将当前友方视野的行范围合并后写入原视野数组。即时出生视野、技能照亮和存档数据沿用原接口。[重叠视野复测](../qa/campaign_sustained_performance_20261116/README.md#迷雾重叠视野区间合并)


高俅稳定源码复测沿用现有的正常速度 600 秒探针，汇总逐分钟帧耗时、实际出兵和付费生产。[高俅稳定分支十分钟结果](../qa/campaign_sustained_performance_20261116/README.md#普通单位美术复用后的十分钟复测)


普通单位已解析的贴图、帧序列和方向在换局、替换美术别名或安装预取的帧时失效。源码诊断若直接改下层贴图表，要调用 Art.clear_resolved_unit_art()。[普通单位美术复用](../qa/campaign_sustained_performance_20261116/README.md#普通单位美术跨帧复用)


战船绘制同时取得贴图和是否使用显式方向。旧版预览、普通图和高俅座船的旧贴图回退仍走 Art 路由。[战船绘制定向复测](../qa/campaign_sustained_performance_20261116/README.md#战船贴图与朝向合并查询)


高俅稳定源码复测沿用现有的正常速度 600 秒探针，汇总逐分钟帧耗时、实际出兵和付费生产。[高俅稳定分支十分钟结果](../qa/campaign_sustained_performance_20261116/README.md#阴影与树冠优化后的十分钟复测)


进场提示复用同一翻译模板，关卡标题和模式名从原始游戏数据取词。1v1 难度与兵种指南使用实时文本绑定。改动后重建词库并运行四语菜单验证。[本地化复查](../qa/battle_entry_timing_20261116/README.md#四语进场文案复查)

梁山树冠遮挡按屏幕矩形筛选附近单位。透明度回归包含实景、负坐标及格线样本。[树冠遮挡复测](../qa/campaign_sustained_performance_20261116/README.md#梁山树冠遮挡范围筛选)


阴影几何按槽位的单位位置及高度场实例判断是否重算。高度场建立和存档恢复使用各自的实例，阴影缓冲装入时由现有流程清空提交记录。[静止单位阴影坡面复测](../qa/campaign_sustained_performance_20261116/README.md#静止单位复用阴影坡面)


WorldShadow 的提交记录按 MultiMesh 槽位持有。扩容与恢复提交使旧记录失效，继续使用原存档缓冲格式。[单位阴影复测](../qa/campaign_sustained_performance_20261116/README.md#单位阴影变换与颜色提交)


Art 的短期结果按引擎进程帧更新，运行时美术别名更换后下一次查找立即重建。缺失资源仍按原路径处理。[单位资源查询复测](../qa/campaign_sustained_performance_20261116/README.md#同帧复用单位资源查询)


高俅稳定源码复测沿用现有的正常速度 600 秒探针，汇总逐分钟帧耗时、实际出兵和付费生产。[高俅稳定分支十分钟结果](../qa/campaign_sustained_performance_20261116/README.md#稳定分支十分钟复测)


紧凑标签缓存仅用于项目的语言字体，按文本、宽度、字号复用排版。调用语言字体切换时清空。隐藏单位依赖 CanvasItem 显示时的原生重绘。[标签缓存与隐藏单位](../qa/campaign_sustained_performance_20261116/README.md#标签缓存与隐藏单位重绘)


UITheme 的紧凑标签可为同一行同时画偏移阴影，让战场单位共用现有字号及截断逻辑。动画查帧按本次绘制已解析的单位造型选图。[单位绘制对照](../qa/campaign_sustained_performance_20261116/README.md#单位绘制去除重复查询)


高俅长局探针沿用正常速度防守输入和固定镜头，在实际帧边界累加单位及场景回调，不用引擎监视器重复值归因单帧。[高俅长局帧分段](../qa/campaign_sustained_performance_20261116/README.md#首批水陆接战的帧分段)


本地候选的原生关卡画面复核使用内置关卡与视口探针。独立用户目录及 SHA-256 见[Windows 原生高俅画面](../qa/battle_entry_timing_20261116/README.md#windows-原生高俅关直达)。


本地 Windows 候选 `e3a752f9` 从核对的稳定分支运行输入封装，生成安装身份后再次校验输入和 DLL。原生启动与编译包四入口分开采样。[Windows 本地候选复测](../qa/battle_entry_timing_20261116/README.md#windows-本地候选四入口)


Windows 主菜单根据战役章节或梁山驻守布景选择既有地表贴图路径，与运行内容校验同时发起后台读取。战场挂载时临时保留纹理引用，直至初始材质接管后释放。[进场地表贴图复测](../qa/battle_entry_timing_20261116/README.md#进场地表贴图后台读取)


梁山旧正门位图仅在传统布局调用读取和校验。RTS 门架使用当前关卡布局的双轴路线。[梁山门楼与地表材质](../qa/battle_entry_timing_20261116/README.md#梁山门楼与地表材质)


梁山布景在单次初始化内为三种树复用校准结果。每次进入新战斗重新查询美术来源与校准数据。[梁山布景校验对照](../qa/battle_entry_timing_20261116/README.md#梁山布景树木校验)


高俅出征在 Windows 先后台准备初始英雄栏四张头像，包括首段对白的吴用和公孙胜本章立绘。队列随后读取吴用的初始东南向行走、刘唐技能图标和其余开场动画。[高俅英雄栏首次绘制](../qa/battle_entry_timing_20261116/README.md#高俅英雄栏首次绘制)。[高俅首段对白复测](../qa/battle_entry_timing_20261116/README.md#高俅首段对白与吴用资源)


高俅的 Windows 菜单和关卡部署共用后台队列。HUD 与队列共用 Art 图标表，过早调用时使用正常读取路径。[刘唐首次选择复测](../qa/battle_entry_timing_20261116/README.md#刘唐技能图标后台读取)


首条指令诊断分别采集同帧连点与留出绘制帧，按各按钮、选择、移动和实际图标加载对齐。[高俅首条命令和选择分段](../qa/battle_entry_timing_20261116/README.md#高俅首条命令与选择分段)

高俅普通出征在 Windows 菜单启动共享动画预读队列，直接挂载战斗时仍由关卡部署触发。[高俅出征动画预读](../qa/battle_entry_timing_20261116/README.md#高俅出征时提前读取行走和攻击动画)

高俅预读队列按方向资源路径去重，优先读刘唐四向行走，再读两位英雄攻击；查帧已先接手时后台跳过。[刘唐行走动画后台读取](../qa/campaign_sustained_performance_20261116/README.md#高俅开场后台读取行走动画)

高俅部署后通过 Art 与 Godot 线程加载两位出场英雄的攻击资源，按路径交给原动画缓存。开战入口不等待后台队列。[高俅后台读取对照](../qa/campaign_sustained_performance_20261116/README.md#高俅开场后台读取攻击动画)

四向 `.tres` 动画通过路径验证后，将已解码帧交给原动画缓存。验收对照实际读取次数、帧源及元数据。[慢帧与动画读取记录](../qa/campaign_sustained_performance_20261116/README.md#慢帧归因与动画重复读取)

高俅关两轮 600 秒对照复用原探针、标准特效和固定镜头，复测绑定源码 dde14ad3。[高俅关十分钟复测](../qa/campaign_sustained_performance_20261116/README.md#局部优化后的同负载复测)

固定梁山与通用战役景物在创建和渲染树挂载时同步高度，动态单位与特效沿用原逐帧投影。[固定景物高度短测](../qa/campaign_sustained_performance_20261116/README.md#固定景物高度短测)

跨模式切换后验使用已导入的 Windows 源码检出，按实际菜单按钮和暂停确认信号进入及返回，采集渲染首帧、旧战场弱引用和隔离档案哈希。[进场与返回菜单记录](../qa/battle_entry_timing_20261116/README.md#源码版跨模式返回主菜单)


水陆和静态寻路已共用最近开放格查找。按圈保留行列顺序，实时读取当前导航网格。[水陆落点短测](../qa/campaign_sustained_performance_20261116/README.md#水陆编队落点短测)

迷雾改从当前 RGBA8 图像批量更新 alpha，并复用主画面与小地图共享的纹理。临时侦察期间图、值可短暂不同，下一次正常迷雾刷新按现有规则同步。[迷雾短测](../qa/campaign_sustained_performance_20261116/README.md#迷雾短测对照)


高俅正常速度负载使用 `POLISH_CASE=gao_defense`，复用原关卡付费生产、支援指令和脚本出兵时序。现有性能工具及冻结宿主的来源清单同步纳入高俅驾驶依赖。[高俅关持续帧耗时](../qa/campaign_sustained_performance_20261116/README.md)


快活林起手预警复用原招式状态，冲撞警戒区使用实际冲撞宽度与人物半径。四语分片为 `kuaihuolin_windup.json`。[快活林起手预警](../qa/campaign_counter_window_20261116/README.md#起手倒计时与冲撞警戒区)

黄泥冈重车落点沿既有地面位移限制，接力使用既有货车单元及动作 ID。四语分片为 `huangnigang_loaded_relay.json`。[黄泥冈载重货车接力](../qa/campaign_transport_groups_20261116/README.md#载重货车掉落与接力)

大名府夺门与追兵提示从当前队伍和既有波次字段派生。五条四语分片为 `daming_pursuit_status.json`。[大名府夺门与撤离追兵](../qa/campaign_wounded_selection_20261116/README.md#夺门与撤离追兵)

连环马余骑提示使用原甲马和波次，定位登记到固定任务按钮白名单。四语分片为 `lianhuanma_remaining_riders.json`。[连环马余骑定位](../qa/campaign_cavalry_escort_20261116/README.md#提前歼骑与余骑定位)

祝家庄偏门状态读取既有 `zhu_side_breached` 事件，断援与大营停产按既有状态显示。八条四语源位于 `zhujiazhuang_route_status.json`。[祝家庄断援与开门验收](../qa/campaign_siege_20261116/README.md#断援与开门后的战场提示)

江州码头的名单由六名原好汉状态派生，定位复用关卡固定按钮协议。四语分片为 `jiangzhou_dock_roster.json`。[江州码头撤离反馈](../qa/campaign_pursuit_20261116/README.md#码头收队与岸上好汉)

Windows 导出包在主菜单首帧后开始后台读取并计算程序哈希。出征时接管同一个任务，再核对文件长度、修改时间、实际装载来源、原生库和可选内容。程序文件状态有变时重新扫描。继续上次战斗时释放预读，由既有恢复流程校验。[Windows 主菜单预读](../qa/battle_entry_timing_20261116/README.md#windows-主菜单预读)

举火后载船沉没复用既有撤离与失散事件。三条失船/重新集结四语词条存于 `gao_fire_approach.json`。[举火后接应船损失](../qa/campaign_naval_recovery_20261116/README.md#举火后接应船损失)

高俅内港火攻的三条四语提示存于 gao_fire_approach.json。检测和火区共用 FIRE_ZONE_RADIUS，容差由已有 Mission 动作字段保存。[内港举火实跑](../qa/campaign_fire_readiness_20261116/README.md#内港火点与举火读条)

高俅载船沉没实跑复用现有经济和战斗驾驶。[载船沉没后重新集结实跑](../qa/campaign_naval_recovery_20261116/README.md#载船沉没后重新集结并收兵)

高俅主动止损路线上，驾驶复用现有战斗和经济指令。[受损后返港实跑](../qa/campaign_naval_recovery_20261116/README.md#火攻受阻后返港收兵)

大名府牢院交接七条文案源为 `daming_jail_handoff.json`。任务刷新复用既有关卡和动作状态。[牢院交接验收](../qa/campaign_coordination_20261116/README.md#牢院放行与开枷交接)

高俅收兵与押俘共用结算判定，五条词条由 `gao_capture_closeout.json` 合入词库。[押俘收兵验收](../qa/campaign_flagship_escort_20261116/README.md#押俘进度与收兵结算)

出征计时使用已导入的独立源码检出、Windows Godot 控制台程序和独立离线存档目录。记录提供分段采样补丁、后台校验探针、Windows 候选编译包四模式证据、同发布模板的原生诊断 EXE 样本和可执行文件哈希脚本。 [出征量测记录](../qa/battle_entry_timing_20261116/README.md)

连环马两路余骑由既有骑兵状态派生，四语模板放在 `campaign_cavalry_escort.json`。验证复用 `lianhuanma_escort_qa.gd` 窄窗口夹具。[余骑提示验证](../qa/campaign_cavalry_escort_20261116/README.md#两路余骑与窄窗口军情)

当前来源续玩验证的实际运行版本可能同时包含后来同步的开发记录，运行身份以收据中的 `ad20ef6c` 为准。[最新候选续玩证据](../qa/campaign_resume_current_20261116/evidence/current_stable_07df0d96/README.md#2026-11-16-最新候选的连环马续玩链通过)

当前八幕战役的阶段证据与待验项从 [路线图当前进度](CAMPAIGN_ROADMAP_20261116.md#当前落地进度) 查找，逐批过程记录保留在其后。

若已通过的首次导入在收尾时留下其自有引擎锁，在原续玩宿主命令追加 `--recover-cold-lock`。工具复核原收据、导入日志、生成身份及锁的归属，引擎空闲时启动实际验证。[参数与夹具](../qa/campaign_resume_current_20261116/evidence/current_stable_07df0d96/README.md#首次导入锁恢复)

续玩候选 `ad20ef6c` 基于 `07df0d96`，临时补入 25 个经核对的 `.gd.uid`，复建条目见[候选与校验记录](../qa/campaign_resume_current_20261116/evidence/current_stable_07df0d96/README.md)。

连环马 `--retry-south-tail` 固定原南路攻营报告与同一再保存档。验证策略通过原攻营命令护送撞车执行，归档与冻结身份见[同档胜利与旧档拒绝原件](../qa/campaign_resume_current_20261116/evidence/protected_drill_candidate/ram_escort_terminal/)。

四语词库重新生成后包含战役进场文案和既有 115 条运行词条的源分片，按 [本地化维护步骤](LOCALIZATION_20260908.md#维护与复现) 严格重建并执行覆盖检查。

Steam Windows Build `26699320` 由稳定分支提交 `9b9ca6a96f7004bd4ce8e36b5f972e4fc6ed2587` 的独立检出生成。Windows Depot `5088121` 和 Manifest `3231099744923356430` 已核对。[构建与客户端验收](../qa/steam_release_20261116/README.md)

连环马反攻任务由原十二骑战果、韩滔生擒事件与大营状态派生。同批合入现行目录的新增三个四语键。[反攻提示原件](../qa/campaign_cavalry_escort_20261116/README.md#擒获韩滔后的反攻提示)。

连环马 `--retry-support-tail` 固定前一轮关档并在同一原再保存槽续跑。策略只调整普通集结、南路推进与攻城指令。[南路续玩原件](../qa/campaign_resume_current_20261116/evidence/protected_drill_candidate/south_approach/)。

野猪林与快活林定向入口分别为现有 runner 的 `--force` 和 `--wine`。两次实际运行分别使用当时目录，合入六条四语后可从相应原件重建两次受测目录。[野猪林原件](../qa/campaign_escort_arrival_20261116/README.md#提前强救与照伤提示) · [快活林原件](../qa/campaign_counter_window_20261116/README.md#饮酒与调息)。

黄泥冈运输 runner 新增 `--relay`，复用正式关卡，初始化后启用4倍时间，使用隔离用户目录与宿主锁。[强夺路线及原件](../qa/campaign_transport_groups_20261116/README.md#强夺伤亡接力实跑)。

连环马 `--retry-reserve-tail` 链入此前保车尾段并复用原首存/再保存；本批驾驶用原招募、技能和单位指令增加林冲、花荣与弓手集火。[同档实跑原件](../qa/campaign_resume_current_20261116/evidence/protected_drill_candidate/counter_support_heroes/)。

祝家庄真人样板按[试玩清单](PLAYTEST_CHECKLIST_20260906.md#2026-11-16-祝家庄样板验收)记录受测源码完整 SHA 或构建号，使用隔离用户数据和正常速度；首轮观察与不同计划重玩分别归档。

江州任务目标依据现有获救、登船、接应状态刷新，新增五条 `campaign_pursuit.json` 四语文字。`live/runner.py --route story` 验证分路起事和白龙庙路线，独立输出 `.godot/jiang-story/`。[两种营救及本批原件](../qa/campaign_pursuit_20261116/README.md#解缚与撤离目标交接)。

连环马 `--retry-budget-tail` 可复用同一候选的两次真实保存，核对已关闭的补矿与器械预算尾段，再执行原终局断言。[同档实跑原件](../qa/campaign_resume_current_20261116/evidence/protected_drill_candidate/rams_held_in_reserve/)。

高俅第二批连船使用既有 `water_groups[1]` 顺序分配前港水面，借用水面体积检查及普通攻击移动。角色按原批次派生，新增查看文案在 `campaign_fire_readiness.json`，目录与祝家庄的新条目逐项合入。[定向检查原件](../qa/campaign_flagship_escort_20261116/second_wave_front/)。

祝家庄强攻提示使用现有任务标题与目标刷新，采用 `campaign_siege.json` 同步四语运行目录，未新增档案字段。源码身份发生变化，旧冻结档案验证仍归其原来源。[任务提示检查](../qa/campaign_siege_20261116/frontal_briefing/)。

祝家庄 `--route rush` 记录本营透支前后的矿量、采集分配、交易与其他收入。集市改用实际建筑热键，条件满足才成交，本局未触发。原关卡来源沿用前一批。[实跑原件](../qa/campaign_siege_20261116/rush_economy_observation/)。

连环马此轮在前两次尾段基础上由 `--retry-flank-tail` 核对侧翼未触发的历史报告与同一再保存槽，再启终局。外部驾驶检查在生产工坊实际扣费，并在反攻阶段为可见金矿尝试安排工人。命令账证明原优先采木策略会覆盖补矿指令。[复跑原件](../qa/campaign_resume_current_20261116/evidence/protected_drill_candidate/counter_budget_stall/)。

祝家庄 `--route rush` 驾驶把前营留守与投石车推进分组，仍用原生产、采集、攻击和修理命令，应从独立隔离目录复跑。[分兵实跑原件](../qa/campaign_siege_20261116/rush_split_force/)。

祝家庄快速强攻验证复用 `direct_runner.py --route rush`，独立写入 `.godot/zhu-rush/`。首跑和中路复跑保留原报告、日志、回执及驱动哈希。生产关卡、档案字段与玩家资源成本无变更。[复跑原件及范围](../qa/campaign_siege_20261116/README.md#跳过外围的快速强攻)。

原槽侧翼复跑在韩滔未擒、官军大营仍完整时结束，侧翼策略未进入。后段中军附近金矿余量固定在2890。保留原候选、再保存档链和现有终局断言，先据实战日志排查采集与攻城预算。[本轮原始回执](../qa/campaign_resume_current_20261116/evidence/protected_drill_candidate/east_flank_not_reached/)。

连环马侧翼攻营续接需同时提供原诱骑失败尾段和其后原槽攻营失败尾段（--retry-lure-tail 与 --retry-assault-tail）。两次失败的来源、报告、日志及保留的再保存链先核对，再启动两个终局验收进程。[侧翼攻营复跑](../qa/campaign_resume_current_20261116/README.md#侧翼攻营复跑)。


连环马指定诱骑失败复跑可通过 --retry-lure-tail 接续原首存及再保存，旧输入由历史Git字节复核，新策略按现行清单核验。[已核对的续玩来源与执行记录](../qa/campaign_resume_current_20261116/README.md#同一原档续跑自然终局)。


连环马当前 worker 策略新增枪兵并行预走位，逆补丁对原司机字节验证通过。诊断工具可读取已验证的尾段再保存报告并复制私有档，完整终局仍由正式验收流程判定。[诱骑诊断与短程复验](../qa/campaign_resume_current_20261116/README.md#诱骑走位短程复验)。


连环马续接工具接受原流程至少一个已通过的保存阶段，下一进程须因引擎占用而未打开日志或报告。后续启动遇相同抢占时等待，已启动的战斗失败继续保留原结果。[来源和首段回执](../qa/campaign_resume_current_20261116/evidence/protected_drill_candidate/)。


2026-11-16 连环马演练骑复用Unit已有的 campaign_no_auto_target 标记。Unit通用元数据保存和恢复按原方式保留该布尔值，无新增结构字段。本次生产内容身份变化，后续续玩验证须绑定当前来源。[教场诊断与定向验证](../qa/campaign_resume_current_20261116/README.md)。


2026-11-16 新增当前玩法续玩整合候选工具。qa/campaign_resume_current_20261116/prepare.py以Git固定blob、当前规范输入、三方合并Battle、11原UID和13明确导入元数据合成无缓存工程；native helper由--native-root指定本机来源并核对源码/构建收据/EXE，不入库二进制。当前合成身份b32972f3已通过自身首次冷导入，生产26模块尚未采用。run_lianhuanma.py绑定新来源使用原四进程完整演义断言，不能沿用旧批资格。[本批来源与记录](../qa/campaign_resume_current_20261116/README.md)。


2026-11-16 高俅第三批原末两船护航座船，角色由原groups/waves/flagship派生；只用普通Unit指令，未新增Level字段/计时器，旧冻结恢复资格不沿用。campaign_flagship_escort.json新增两条四语；QA记录器只监听原船死亡，不修改战斗。[本批来源与限定证据](../qa/campaign_flagship_escort_20261116/README.md)。


2026-11-16 高俅火攻/接应/撤离条件抽出供任务与HUD共用，原边界保持；提示实时派生，无新增Level/Visual字段，生产身份变化不沿用冻结恢复资格。新增campaign_fire_readiness.json七条四语。gao_rts_play故事驾驶增加实际返港阶段，其间专船不混入普通攻击编组；只在QA中生效。[来源与限定验证](../qa/campaign_fire_readiness_20261116/README.md)。


2026-11-16 大名府daming_select_wounded进入Mission官方按钮白名单，沿用Presentation固定回调；成员由原伤员/既有状态实时派生，无新增Level字段。新增campaign_wounded_selection.json四条四语并同步catalog。生产来源变化不沿用冻结恢复候选资格。[本批实现与双路线证据](../qa/campaign_wounded_selection_20261116/README.md)。


2026-11-16 连环马新增raid实跑入口参数；本批未改游戏代码或素材，关卡与e58f3fa3及前批防守来源同SHA。验证记录器改在Unit.died收集原十二骑ID，避免节点释放后的访问；该连接只在QA中安装。[来源与验证边界](../qa/campaign_cavalry_raid_20261116/README.md)。


2026-11-16 连环马护军角色由既有waves/riders/source_lane派生，普通指令仍由Unit保存；Level字段结构保持，生产身份改变，旧候选资格不沿用。新增campaign_cavalry_escort.json三条四语。[本批来源与验证边界](../qa/campaign_cavalry_escort_20261116/README.md)。


2026-11-16 黄泥冈运输分组实时派生，无新增Level/Visual字段；hg_empty_carts、hg_loaded_carts纳入官方按钮白名单。campaign_transport_groups.json新增八条四语并同步catalog；源码身份改变，冻结续玩资格不沿用。[来源与验证边界](../qa/campaign_transport_groups_20261116/README.md)。


2026-11-16 快活林反击标记由原exposed_left等状态在Battle Overlay重绘，不新增Level/Visual字段或节点；profile结构保持，源码身份改变，旧冻结候选资格不沿用。新增campaign_counter_window.json同步catalog。[本批来源与限定验证](../qa/campaign_counter_window_20261116/README.md)。


2026-11-16 野猪林到达反馈由现有位置/指令实时派生，不新增存档字段；pine_waiting登记到Mission官方按钮白名单，沿用固定Presentation回调。四语来源campaign_escort_arrival.json同步catalog。源码身份变化，旧冻结候选不沿用；[来源、定向检查与恢复边界](../qa/campaign_escort_arrival_20261116/README.md)。


2026-11-16 公共HUD与任务布局适配实际底栏，增加生产队列滚动容器；未增加保存字段，但生产身份已变化，旧冻结续玩候选资格不沿用。[定向布局证据与剩余范围](../qa/campaign_overlays_20261116/README.md)。


2026-11-16 高俅保存profile为`campaign_level5_v2`，新增`fire_abandoned`及载客引用一致性约束；生产身份改变，旧候选不沿用。翻译来源`campaign_naval_recovery.json`同步catalog。[本批来源与限定验证](../qa/campaign_naval_recovery_20261116/README.md)。


2026-11-16 大名府接应/撤离反馈新增`assets/localization/campaign_coordination.json`并同步catalog；关卡沿用level8 v1字段结构，状态均实时派生，不新增档案字段。本批源码改变生产身份，旧续玩候选资格不沿用。[定向验证及恢复边界](../qa/campaign_coordination_20261116/README.md)。


2026-11-16 江州新增两路追兵的搜索游标、目击状态、目的地和决策计时，六名追兵固定引用槽，恢复profile为`campaign_level2_v2`。新翻译来源`campaign_pursuit.json`同步catalog。组件往返不授完整恢复资格，冻结候选不原地覆盖；[源码/夹具/单路实战边界](../qa/campaign_pursuit_20261116/README.md)。

2026-11-16 M3首批将连环马原有破阵判定抽为`hook_conditions`，单位查看通过关卡可选接口`unit_tactical_hint`读取，不新增存档字段或改profile结构。`campaign_hooks.json`新增9条四语并同步catalog；公共HUD生产输入有变化，不沿用先前冻结候选资格。[来源与限定渲染结果](../qa/campaign_hooks_20261116/README.md)。

2026-11-16 战役深化按[路线图](CAMPAIGN_ROADMAP_20261116.md)推进。祝家庄小队与入口增援状态已登记到Level组件，当前恢复profile为`campaign_level3_v3`；旧战斗候选不猜测迁移，正式战役续玩仍按独立整合验收开放。运行翻译新增`campaign_tactics.json`、`campaign_siege.json`来源并同步catalog。首次开发使用独立工作树；冻结候选不原地覆盖。

本批[小队与侦察专项](../qa/campaign_squad_20261116/README.md)11项定向夹具通过，范围为决策和Level组件；不继承为整关或完整续玩证明。复跑命令及本机引擎锁约定见该记录。

后继[入口增援与营救交接](../qa/campaign_siege_20261116/README.md)在同一场景增加本批风险检查，共16项通过；范围仍为夹具与Level组件，未替代实际行军验收。

连环马阶段任务文案由关卡脚本提供。翻译维护在 `assets/localization/campaign.json`，运行时加载 `assets/localization/catalog.json`。任务提示改动会改变生产来源，须用新的冻结候选验收。

## 本机生成副本自动淘汰（2026-11-02）

旧生成版本已由用户退役，各类只留最新有效载荷及当前必需依赖。Windows换机后运行`powershell.exe -NoProfile -File tools/install_artifact_retention_startup.ps1`，为当前用户安装隐藏的成功记录观察程序；它每60秒检测新完成批次，按验证结果自动清理，不修改冻结生成器或真实存档。清单预览与手动命令见[规则](GENERATED_ARTIFACT_RETENTION.md)，本机状态在`.godot/artifact_retention/`。历史文档的旧完整副本路径可能已退役，不代表目前仍可复验；暂停的开发状态保持。

本机开发目录为 `D:/AI项目/水浒/开发工程`，打开其中 `project.godot`；桌面旧目录仅为历史兼容入口。当前进度见[项目总览](PROJECT_STATUS.md)，开发顺序及完整要求见[开发计划](DEVELOPMENT_PLAN.md)，逐批证据见[开发日志](WORKLOG.md)和[目录索引](DIRECTORY_INDEX.md)。

## 启动与导入

使用 Godot **4.6.3**。在仓库根目录运行 `Play.cmd`；编辑器用 `Play.cmd -Mode editor`，仅导入用 `Play.cmd -Mode import`，强制重新导入加 `-Reimport`。启动器先检查导入缓存。

本机引擎路径依次来自 `-GodotPath`、`GODOT_PATH`、被忽略的 `godot.local.txt` 和 PATH。机器路径、SDK凭据及签名配置不写进生产脚本。81份资源导入配置和26份候选工具/预览源码已补交，详见[入库记录](../qa/pending_source_sync_20261020/README.md)；`.import`设置随资源入库，`.godot`缓存不上传。

## 换机与 Git 同步

在自己的 checkout 开发，不嵌套克隆。开工先运行：

```powershell
git status --short --branch
git remote -v
git fetch origin
```

目标仓库为 `https://github.com/winterzh/Liangshan-Heroes.git`，开发分支为 `codex/sync-20260905-stable`。工作区干净且未分叉时才 `git pull --ff-only origin codex/sync-20260905-stable`；有本地修改或分叉先核对来源，不自动stash、reset或覆盖。

每轮按实际修改做验证，更新WORKLOG及涉及的文档；检查远端、白名单差异、大小及敏感内容后逐文件提交推送，回读远端SHA。玩家存档、Steam登录/缓存、Godot缓存、安装包及无关历史备份不上传。main合并和平台发布按AGENTS.md及当次授权执行。

## 验证与共享引擎

10月30日运输开发按改动做必要专项，[分批来源与实现](TRIBUTE_CART_WHEEL_UNIT_20261018.md)统一导航；每批同一私有场景取得一次实际来源身份，再交给生产新游戏API，减少重复启动和扫描。最新[原车跟随与轮角接力](../qa/cart_follow_relay_20261030/README.md)只改2个运输脚本，95项/12图及来源/进程后验闭合；原地形/临时阻挡、真实接力/旧缓存夹具与首驱动失败分开记录。公孙胜生产配准仍用其本批`build_registration.py`复验，旧构建器对应原快照。完整美术过渡、续玩和整体验收继续，局部代码验证不等于整关或平台发布。

最新[人物标签联用专项](../qa/person_captions_20261030/README.md)只改共享提示层及Unit原标签资格两个脚本。一个原关卡保留20图与两项过严断言失败，窄英文容量/原白胜选择/消息隐藏只补三图，不重复原场景矩阵；同一来源后验重新闭合。拥挤时无空位收起属于当前设计，不将原失败改写为全通过。复验命令及原始驱动见该QA。

最新[提示布局开销对比](../qa/caption_layout_cost_20261030/README.md)只改一个脚本；同场景原Git模块与新代码45组逐字段一致，173项/6图后验闭合。21候选窄窗配对中位17.840→14.090ms、暂停降23.2%，交付车小增94微秒如实记录，不授正常整帧性能。局部几何memo不跨帧，不需恢复字段。

上批[剧情状态标签专项](../qa/story_captions_20261030/README.md)735项/11图闭合：原入场helper与姿态回退夹具分开记录，首次入口失败保留。21候选拥挤布局单组件20.756ms，显示功能通过但布局开销待优化；只按本次变更复验，不授正常性能。

[枣车四向网页请求](../qa/jujube_cart_fourview_20261030/README.md)目前仅固定参考与接图要求，等当次网页人工验证后生成；无新图或生产接入，不运行引擎。新图定稿且人工目检车架/把手/轴点后再冻结，避免边接图边复制来源。

用户已取消全量52／61测试，后续按修改做必要的针对性检查；不自动恢复全量矩阵。现有27个进程39383项通过、取消及未运行范围见[原始收据](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_user_stop_20261027_183950/README.md)。10月28日用户另行授权发行包验收并更新Steam，已完成必要EXE与键鼠入口检查、Build26260970正式上线、四语公告、下载哈希及Steam库启动／退出验收；人工整关仍未计通过。[发布收据与原件](../qa/steam_release_20261028/README.md)。

调用Godot前检查已有进程和共享锁，等通道自然空闲并串行执行，不控制其他聊天的进程。使用与候选精确绑定的冻结、清单及自己的成功导入；默认命名来源检查只授静态结果。原失败存档和证据保留，复验使用逐字新副本，不把旧冻结的通过转授新源码。当前b22及大名府、持久化与各章节边界统一见[当前验证](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/VALIDATION.md)，具体执行命令留在相应QA目录。

## 旧快照和缓存恢复

本轮12个旧战役快照只去掉与最新b22缓存逐字相同的导入文件；复验前按[本轮映射与恢复器](../qa/storage_cleanup_20261027/README.md)补齐。最新b22缓存是恢复保留副本，后续清理不能直接删除。主缓存、各快照源码、独有缓存和原始QA/存档保留。

10月26日第二轮的三个旧快照按[既有映射](../qa/storage_cleanup_20261026_round2/README.md)恢复；上一轮54快照ZIP及9月7日7z已被用户删除，旧收据不代表当前仍有归档载荷。其他旧缓存按各批恢复说明补齐或用绑定Godot版本重新导入，不覆盖不同文件。

## 发布与历史

当前Steam Windows为Build26260970，冻结生产来源47168f00；见[更新记录](STEAM_UPDATE_20261028.md)及[发布指南](STEAM_RELEASE_GUIDE.md)。公开战役续玩未开放，经典固定30波保存/继续保留。源码同步、发行程序验证、平台上线与人工验收各自记录。

整理前的完整设置和历史工具状态保留于[Git提交5837d1bd](https://github.com/winterzh/Liangshan-Heroes/blob/5837d1bdc769f2847888a074f41b5c3d629c5529/docs/SOURCE_SETUP.md)，原10月20日文档归档说明见[历史全文与恢复](../qa/storage_cleanup_20261020/README.md)。专题入口见[文档导航](README.md)、[QA导航](../qa/README.md)及[GitHub约定](GITHUB_REPOSITORY.md)。

### 2026-11-16 高俅三批任务提示

高俅三次出击的任务正文按战局更新，并显示下一批倒计时。火攻失败后转回常规舰队提示，座船停航后提醒击退余部。22 项定向检查通过，50.75 秒，退出 0，错误 0。[高俅阶段提示验证](../qa/campaign_flagship_escort_20261116/README.md#三批阶段提示)
