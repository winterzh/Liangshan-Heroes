# 水浒英雄传本地源码

收尾以正常合并保留本地快活林 `da1ff6a` 和远端拥挤分离 `66d27aa`；五个顶部冲突保留双方段落，18个无冲突远端文件Git字节保持。原68输入/36证据按本地提交核对，合入后再跑快活林三路线/边界及路径/拥挤专项179条PASS；见 [集成收据](../qa/kuaihuolin_short_20260906/integration/README.md)。没有把本批计时作为性能达标。

## 2026-09-06 快活林当前短篇

重新运行 `Play.cmd` 并重开“醉打蒋门神”，载入 `level7_kuaihuolin_short.gd`。可择店饮酒或直接挑战，官道上可选无伤练步；W后右键换位，避开重拳/真实冲撞后趁破绽E近身反击，施恩需由玩家保护并带回酒店。

验证入口：`tools/kuaihuolin_short_test.gd`（`KH_CASE=wine|direct|standing|all`，实际指令）；`kuaihuolin_short_boundaries.gd`（独立边界/实际重打与跨模式）；`kuaihuolin_short_ui_test.gd`（非headless两尺寸四阶段）。旧 `campaign_kuaihuolin_depth_test.gd` 转到当前边界工具。临时输出 `.godot/kuaihuolin_short/`；[规则](KUAIHUOLIN_SHORT_20260906.md)、[冻结QA](../qa/kuaihuolin_short_20260906/README.md)。本批无新PNG或导出包，角色/来源及发行缺口未关闭。

## 2026-09-06 拥挤分离

分离循环复用单位属性并减少位置写回，保留原处理顺序与碰撞规则。新入口 `tools/crowd_separation_qa.gd` 用Godot headless运行，输出 `.godot/crowd_separation_qa/`；38项/59,328次位置对照一致，函数配对耗时下降12.8%/15.2%，不等于整场战斗FPS增幅。当前拥挤压力仍未达预算。复现及现有寻路/关卡回归命令见 [说明](CROWD_SEPARATION_20260906.md)。

## 2026-09-06 路径检查

移动/软分离的线段检查复用端点格子和同格阻挡结果。专项58项、跨八关81,000条旧新对照及原寻路23项通过；本机函数配对耗时降低27.7%，拥挤实机帧率仍待继续优化。`tools/segment_navigation_qa.gd` 用Godot headless运行，输出 `.godot/segment_navigation_qa/`；真实渲染热点诊断为 `tools/rts_collision_profile.gd`。详见 [复现说明](SEGMENT_NAVIGATION_20260906.md)。

已整合另一任务 `2d22c37` 的黄泥冈短篇；在当前入口复跑路径58/81,000对照、黄泥冈54和寻路23项全部通过，合并后输入哈希及独立报告在本批QA `integration/`。

## 2026-09-06 黄泥冈当前短篇

重新运行 `Play.cmd` 并重开“智取生辰纲”，加载 `level1_huangnigang_short.gd`。押队上冈时布置商客；刘唐试酒引目，吴用和白胜可以提前到乙桶配合。三担任选同伴同时搬走，其他幸存者由你收拢。新版原生透明纲担已接入本关；新素材按正常启动入口导入，角色四向与商客服装仍未验收完成。

当前测试为 `tools/huangnigang_short_test.gd`，`HNS_CASE=all`跑两条路线及边界；`HNS_VISUAL=1`配合非headless保存实机，`HNS_SIZE=1280`选择小窗口。详细 [玩法与验证](HUANGNIGANG_SHORT_20260906.md)、[QA](../qa/huangnigang_short_20260906/README.md)。旧黄泥冈深度/搬运/酒计/美术工具验证旧流程，不能替代当前入口。木墙本轮重新出图核对，使用源码启动并重开关卡才能加载现有修正。

合并后的版本也包含暂停重开/返回/退出确认。黄泥冈边界、滚动布局及实际暂停菜单已交叉复验，详见本批QA `integration/`；章节进度仍不等于战斗中段快照。

## 2026-09-06 暂停操作

暂停菜单的重开、返回与退出现在先显示本局不保存的提示，取消后仍停留在暂停菜单；Esc 或安卓返回键先取消确认，再按一次继续。已有章节记录保留，尚无中途战斗快照。专项入口 `tools/pause_menu_qa.gd` 使用本机Godot实际渲染运行，输出 `.godot/pause_menu_qa/`，55项通过。见 [实现/复现](PAUSE_MENU_20260906.md) 和 [证据](../qa/pause_menu_20260906/README.md)。

## 2026-09-06 自然地表细缝修复

提交 `a851bb0` 已在专用干净Git检出上核对42项输入与41份证据，并从外部目录复跑三个Python入口，预期退出0/1/0；没有Godot资源导入缓存，执行后仍无未提交文件。收据见地表QA的 `checkout_verification.json`。

重开关卡会加载修复后的自然地表shader，旧atlas的透明边缘不再截断整图地面。新增 `tools/terrain_alpha_seam_probe.gd`、`tools/terrain_alpha_seam_qa.gd`，用本机Godot非headless运行；输出位于 `.godot/terrain_seam_probe/` 与 `.godot/terrain_alpha_seam_qa/`。八关86项实机/透明度、90项地形契约通过；没有改变生产图片、寻路或任务逻辑。复现命令与范围见 [说明](TERRAIN_ALPHA_SEAMS_20260906.md)、[QA](../qa/terrain_alpha_seams_20260906/README.md)。

## 2026-09-06 田地资源接入

本批 `591479d` 无缓存干净检出通过27项输入/24份证据哈希与三个入口复现；收尾合入野猪林 `fe70c4e` 后重跑专项44、路由790/794与隔离40项，结果仍通过。原检出收据与合并后证据分别保存在田地QA的 `clean_checkout.json`、`integration/`。

重开“三打祝家庄”或“智取大名府”会加载新田地整图；其他关卡不加载。新增 `tools/environment_field_render_qa.gd`：完成Godot导入后，以本机配置的 `$godotExe --path . --script res://tools/environment_field_render_qa.gd` 运行真实渲染对照，结果在 `.godot/environment_field_qa/`。当前专项44项、路由790/794项、隔离反例40项通过；环境审计现为37张匹配、32张缺图、249项缺口，仍预期退出1。新原图/提示词/接入记录与历史缺口分别保留，见 [说明](ENVIRONMENT_FIELD_20260906.md) 和 [QA](../qa/environment_field_20260906/README.md)。

## 2026-09-06 野猪林短篇入口

重新运行 `Play.cmd`，在战役菜单选择“大闹野猪林”并重开。先选鲁智深，右键林边地面跟随；跟丢仍可赶到松树补救。拦棍后四人等玩家指挥，可直接结队出林或歇脚完成演义目标；S可整队停下，任务按钮只定位。实际提前强救需要制住解差并回到林冲身旁，人物不再瞬移整队。

`YF_CASE=all`运行 `tools/yezhulin_short_test.gd`；非headless下设`YF_VISUAL=1`可截图，`YF_SIZE=1280`检查小窗口。旧`campaign_yezhulin_depth_test.gd`入口同步转到当前套件，新输出在`.godot/yezhulin_short/`。详见 [规则与限制](YEZHULIN_SHORT_20260906.md)、[QA](../qa/yezhulin_short_20260906/README.md)。

## 2026-09-06 江州有限补给救援入口

重新运行 `Play.cmd`，选择“江州劫法场”并重开，将加载 `level2_jiangzhou_rts.gd`。西街、江边接应营共用190金120木，沿用普通刀枪弓骑的费用与训练时间；两处补给棚可夺。150秒内先打倒两名刽子手，再分别救人、清退路、下令登船；护卫在岸边断后，让出旗标附近通道。二人都上船后，点击“开船通关”，也可先完成白龙庙相会与六人撤回。

四个大型RTS之外新增本关有限补给玩法，三个短篇仍待重做。规则与自动验收边界见 [江州说明](JIANGZHOU_RTS_20260906.md)、[QA](../qa/jiangzhou_rts_20260906/README.md)。`JZ_ROUTE=direct|story`运行 `tools/jiangzhou_rts_play.gd`；图形回放设置 `JZ_VISUAL=1`并使用非headless Godot。结果写入 `.godot/jiangzhou_rts/`，公共脚本继续使用本机路径解析器。原分支与PR #1继续开发，没有更新导出包或Steam。

## 2026-09-06 环境美术验证入口

环境检查已改为仓库内输入，可从任意目录使用脚本绝对路径运行。入口：`python -X utf8 -B tools/campaign_environment_art_static_contract.py`（路由）、`python -X utf8 -B tools/environment_art_audit.py`（生产与来源）、`python -X utf8 -B tools/environment_validation_selftest.py`（隔离反例）。Python3.9+；审计需要Pillow，旧接入工具另需NumPy。

默认结果写入被忽略的 `.godot/environment_validation/`。最初修复批为36张匹配、33张缺图；田地增量后为37张匹配、32张缺图。历史原提示词/原图/接入证据尚未恢复，因此整体审计退出1，不能当成功。旧接入自测缺冻结输入时退出2并标明0项执行。

已在 `f930cdb` 的全新Git检出中复验：没有缓存或本机路径文件，28/28输入哈希一致、30项隔离自测通过，六个入口从外部cwd运行符合预期，检出前后均无未提交修改。收据见本批QA的 `clean_checkout.json`。

冻结输入位置为 `tools/contracts/environment/`，旧原件恢复位置为其中的 `legacy/`；`.gitattributes` 保持精确字节，不能只改哈希掩盖缺口。历史文件中的办公室路径可通过明确的仓库内相对路径映射迁移，来源哈希要求保留。详见 [当前说明](ENVIRONMENT_VALIDATION_PORTABILITY_20260906.md)、[QA](../qa/environment_validation_20260906/README.md)。下方历史785项及来源清单记录不表示本机完整历史验收通过。

## 2026-09-06 高俅持续水陆经营入口

重新运行 `Play.cmd`，选择“三败高太尉”并重开，会加载 `level5_gao_rts.gd`。同一营寨采金伐木、训练岸军，在南岸定位处造船坞，付费补船抗三批水陆主力；拆两处补给源可断援。可打停座船后直接“收兵通关”，或提前准备火船与接应船，之后凿船、水上接俘并由岸军实际押回堂前。长任务列表可滚动，定位按钮仍需配合玩家选人和右键现场办理。详见 [高俅实现](GAO_RTS_20260906.md) 与 [本轮QA](../qa/gao_rts_20260906/README.md)。

新关保留上一批竖直木墙和门墙脚点修正。船坞只由本关启用，驻守/AI对战清单不受影响。当前四个大型RTS样板，江州已在上方最新批次接入，三个短篇仍待重做；本轮仅源码同步，没有更新导出包或Steam。

记录日期：2026-09-05（Asia/Shanghai）。

2026-09-06 更新：再次修正祝家庄、梁山故事场景和驻守战的木墙本体，墙脚、竖柱与转角统一校准。重新运行 `Play.cmd` 并重开对应关卡载入；[对照与验证](../qa/wall_naval_20260906/README.md)。同时完成了岸边建造、付费造船和堵口保留队列的底层验证，**后续高俅已接入经营战役**，见 [高俅当前说明](GAO_RTS_20260906.md)；此处底层批次是历史范围，详见 [实现边界](WALL_AND_NAVAL_FOUNDATION_20260906.md)。

## 当前玩法更新：四个 RTS 战役样板

大名府已接入城外经营与城内配合：重新运行 `Play.cmd`，在菜单选择“智取大名府”并重开载入新入口 `level8_daming_rts.gd`。先经营与补兵，柴进/乐和入牢、时迁择机举火，再带军夺门救人；也可直接用器械强攻。救出的卢俊义与石秀都要由玩家带到城外接应地，定位按钮只移动镜头。说明与边界见 [大名府样板](DAMING_RTS_20260905.md) 和 [本轮QA](../qa/daming_rts_20260905/README.md)。

连环马已接入持续经营与反骑：双击 `Play.cmd`，选择“大破连环马”。兵营付费训练钩镰，守草林或先拆两处辎重营，回防两队甲马后反攻；营地和已训练军队保留。教场可选，需徐宁现场摆骑、普通兵诱入撤退、徐宁与钩镰共同攻击；教头阵亡可正常复活重试。重开关卡加载新入口 `level4_lianhuanma_rts.gd`，章节ID不变。两条真实自动路线与182项验证见 [连环马说明](LIANHUANMA_RTS_20260905.md) 和 [连环马QA](../qa/lianhuanma_rts_20260905/README.md)。加上祝家庄、大名府及后续高俅共四关已重做，江州随后已接入有限补给玩法，三个短篇仍按方案推进；真人趣味、四向补齐和发行质量缺口见 [可售版本待办](RELEASE_READINESS_20260905.md)。

再次试玩修复：门体按两端墙脚定位，箭楼与门楼错开。接应新增“选中·孙立”；选中后右键3号旗标并停留5秒，群选也能正常办理，其他英雄到场会提示所需人物。重新启动源码并重开该关载入；见 [门墙与接应QA](../qa/zhujiazhuang_gate_contact_20260905/README.md)。全库角色四向已建逐项清单，但首批新图透明通道未过关，**尚未替换生产角色素材**，见 [四向状态](CHARACTER_DIRECTION4_20260905.md)。

最新试玩修复：正门/偏门已沿木墙轴向绘制，守军会主动迎敌并回防；两入口各有箭楼，建议侦察后带兵保护器械、先拆塔再攻营。共享追击及敌将施法结算问题同步修正，英雄数值未削弱。重新启动源码游戏并重开“三打祝家庄”加载本轮修改；详见 [反馈 QA](../qa/zhujiazhuang_rts_feedback_20260905/README.md)。

用户同意 [八关趣味重做方案](CAMPAIGN_FUN_REWORK_20260905.md) 后，先接入 [祝家庄 RTS 可玩样板](ZHUJIAZHUANG_RTS_20260905.md)。运行 `Play.cmd` 后选择“三打祝家庄”：经营前营、争北矿、拆南营断援，再正面攻城或由孙立开偏门，救时迁回营并由宋江收军。关卡 ID/存档索引不变，菜单改用 `level3_zhujiazhuang_rts.gd`；旧三日流程只作参考。共享实体树木的采集距离已修正，恢复相邻格工人伐木入账。验证范围见 `qa/zhujiazhuang_rts_20260905/README.md`；真人趣味、难度与中途重试仍待完善。本次源码更新没有重新导出或更新 Steam 安装包。

## Git checkout 启动与家里接续（2026-09-05）

本节是 GitHub 克隆版的当前启动说明。家里目录为 `E:\ChatGPT\水浒`，`project.godot` 直接位于该目录；交接文件是 `docs/WORKLOG.md`、`docs/SOURCE_SETUP.md`、`docs/DIRECTORY_INDEX.md`。下文办公室历史记录中的 `Liangshan-Heroes/` 前缀在 Git checkout 中应去掉，外层交接文档应改查 `docs/`。仓库外的 `implementation_*`、旧 QA、导出包和未推送修改不会自动来到家里，不能把缺失文件视为已同步。

本机已验证 Godot `4.6.3.stable.official.7d41c59c4`。首次配置：在工程根目录创建 UTF-8 文本 `godot.local.txt`，只写 Godot EXE 的完整路径，不加引号。该文件被 Git 忽略，办公室和家里各自维护。也可通过 `GODOT_PATH` 或脚本的 `-GodotPath` 参数指定。优先级为显式参数、环境变量、本机文本、PATH；选定路径无效或版本不是 4.6.3 时明确报错。

```powershell
# 在 checkout 根目录运行；配置好 godot.local.txt 后也可双击 Play.cmd。
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_local.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_local.ps1 -Mode editor
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_local.ps1 -Mode import
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_local.ps1 -Reimport
```

入口按脚本位置定位工程，支持中文和空格路径；首次启动自动导入资源，缓存完整时直接启动。原 `ensure_import_cache.ps1` 继续负责增量导入。模式切换与音频退出回归脚本也共用 `tools/resolve_godot.ps1`，已有显式路径参数仍可使用。家里本轮日志与主菜单截图见 [接续 QA](../qa/home_setup_20260905/README.md)，只证明本机启动和所列回归，未作长时性能或完整通关验收。

两机交替先检查 `git status --short --branch`。确认工作区干净、分支正确且无本地分叉后执行 `git pull --ff-only origin codex/sync-20260905-stable`；有本地修改时先核对，不自动覆盖或藏起修改。收尾按文件白名单提交并 `git push origin HEAD:codex/sync-20260905-stable`，再回读远端 SHA。继续使用 PR #1，不合并 main，不执行 Steam 发布。

接续基线为远端 `513ee3369726acb92dd9d464eabb6ec235f527b2`。八关主线、自由通关及自主指挥已接入，四种高频官军四向动作和死亡表现修复已在库。待办：剩余四向与环境美术、旧阴影夹具的地图前提、真人逐关/30 波试玩、30 分钟稳定性及平衡验收。历史报告中的严格状态覆盖 `109/347` 未在本轮重新审计，不作为本机新测数字。

## 最新收尾：四向/阵亡修复测试包已生效

Steam 新 BuildID `25136463` 上传成功，Windows Depot `5088121` manifest `7280684617482783161`；成品 `278,050,128` 字节、SHA-256 `B333E117755C0A33FBBC5731FD3768514A68FCE21C5E45DC730F38DD138BBFC1`。八关 8/8、驻守硬伤 9/9、末波清理 12/12、成品 PCK 四向/死亡 90/90 与 1280×720 图形两张均完成。没有真人 30 波或长时性能结论。

用户确认后，SteamCMD 执行 `+app_info_update 1 +app_info_print 5088120` 已回读 public/default 为 `25136463`，`timeupdated=1788581012`，分支切换已生效。服务器隔离回下载已验证 `StateFlags=4`、`UpdateResult=0`、`buildid=TargetBuildID=25136463`，manifest、EXE 大小与 SHA-256 均和上传包一致；独立主菜单启动退出码 0、错误 0。本机 Steam 客户端当前仍为旧 `25121101`，需要客户端下载更新，这不是服务端阻塞；本机新包启动未计为通过。不要重新上传或重复切换。中英文更新说明已写好，未新发社区公告。

GitHub 接入已跨任务核实：用户授权目标为 `winterzh/Liangshan-Heroes` 的 `codex/sync-20260905-stable` 分支及 PR #1。代码/生产素材/来源链/测试工具本轮提交 `863fcf0a1546c6ee7b5026db4bd4c5486a4ef61a` 已推送并回读；main 未改、未合并。本文后部“尚未确认目标仓库”是接入信息尚未汇合时的历史记录，不再作为当前阻塞。共享源目录仍非 Git，使用独立 checkout 精确同步。

以下为 9 月 4 日历史 default 快照，已由上方 `25136463` 替代；保留当时的包体与验证记录：

> 当前 Steam Windows `default` 快照：BuildID `25121101`、Depot `5088121`、manifest `6833015574013725084`。上传包、SteamCMD 服务器回下载 EXE 和本机 Steam 库 EXE 均为 `287,328,240` 字节，SHA-256 `2F0C5786B368BD9F2C4A56893F1AB5872511B72DCB84BC96D667C3075F4295F6`；本机已从 Steam 入口启动验证。这是跨设备测试构建，不是正式发行；完整证据见 `Liangshan-Heroes/docs/STEAM_TEST_BUILD_20260904.md`。

> 目录已于 2026-09-03 规范化。当前结构、历史目录迁移映射与新增规则见 `DIRECTORY_INDEX.md`；历史 QA 快照中的旧绝对路径保持原文。

> 启动入口已增加资源导入前置步骤。清理 `.godot/` 后仍可直接运行 `Play-Campaign-Rework.cmd`，脚本会先用 Godot 4.6.3 重建导入缓存，再进入游戏。

> 启动缓存已改为增量检查：缓存完整时不再每次执行 4.449 秒的全量导入，完整启动器检查约 0.414 秒；素材变更或缓存清理时仍会自动重建。需主动重导入时运行 `Play-Campaign-Rework.cmd reimport`。

> Godot 默认启动标志已替换为项目现有梁山水寨横图 `Liangshan-Heroes/assets/ui/boot_splash.png`；来源、哈希和回滚入口见 `implementation_20260903/boot_splash_20260903/README.md`。

> 运行窗口图标已改用 256×256 `Liangshan-Heroes/assets/ui/app_icon_256.png`，导入体积约为旧图的 1/14；原 2048 图仍保留。源码由 Godot 通用 EXE 启动时，引擎初始化阶段仍可能短暂显示 Godot 图标，这与已嵌入自定义 ICO 的导出 EXE 不同。

> 全项目 UI 已在本地源码接入“克制宋韵”统一主题，覆盖主菜单、八幕选关、战斗 HUD、设置、图鉴和两个编辑器。规范与实渲染证据见 `Liangshan-Heroes/docs/UI_STYLE_SYSTEM_20260903.md`；改前脚本在 `implementation_20260903/ui_unification_20260903_before/`。该 UI 批次完成时未导出、未上传；其后当前源码已随 `2026-09-04` Windows 测试构建进入 Steam default BuildID `25121101`。

> 历史状态（连环甲马 P0 收口时）：来源、备份、生产、Godot运行与五张实拍闭环完成；当时严格四方向来源覆盖为 `72/347`，旧四向待复核 `28`，缺失/不完整 `247`。详细入口见文末“连环甲马 P0”；后续覆盖与 Steam 状态以当前专项报告及上方 `2026-09-04` 快照为准。

## 历史批次：2026-09-03 江州法场李逵专用造型

- `li_kui_jiangzhou` 已完成 `idle/walk/attack/hurt/down × 四方向` 20 帧及独立头像，外形按第三十八、四十、四十一回锁定为裸露上身的黑壮大汉和两把朴素板斧。棋子布腰巾与短下裳是平台分级遮体适配，不反向声称第四十回逐字写有这些衣物。
- 第 2 关只在真实部署键为 `li_kui` 时设置专用 variant；其他关卡、自由模式与图鉴通用 `li_kui` 不变。生产 manifest 为 `Liangshan-Heroes/assets/campaign/li_kui_jiangzhou_direction4_manifest.json`；改前空目标记录与通用 20 帧哈希锁在仓库外 `implementation_20260902/li_kui_jiangzhou_direction4_production_backup_20260903_011700/`。
- 五张采用源图是网页版 ChatGPT 直接下载的原生 RGBA。本地只做固定四格内的连续矩形裁切、全批统一等比缩放、透明补边、PNG 编码与逐字节生产复制；没有本地 Alpha 清理、连通块遮罩、镜像、补画或格内清像素。生成取舍、提示词、会话和源图哈希见 `implementation_20260902/li_kui_jiangzhou_source/README.md`。
- 定向生产合同 152 项、真实关卡 2 Vulkan 视觉 15 项/4 张、早期自由路线 49 项、公共四向 164 个定义、战役动作 74 项和战役美术 160 项均通过。该批结束时严格来源覆盖为 43/347（12.392%），53 项旧四向待来源复核，251 项缺失；这是历史快照，当前数字见页首与文末最新状态。
- `hurt/down` 是自由玩法接口，不是第四十、四十一回原著结果。自动测试与固定镜头不替代真人完整通关、节奏、平衡、战斗高峰和长时间性能验收。
- 本批没有导出、修改 Steam 发布目录、上传或发布。该批当时的下一步是复核53项旧四向；后续林冲、李逵、高俅和黄泥冈批次已继续执行。

## 历史批次：2026-09-03 林冲野猪林 P0 四阶段

- 林冲囚徒 `idle/walk`、树下被缚 `idle`、获救后押送跛行 `walk`、鲁智深搀扶 `assisted` 已完成真四向生产接入。披枷新图全部遵守用户确认的视觉标准：双手套入枷板左右孔；这是项目表现约定，不反向声称原文逐项描述了孔位。
- 原图、提示词、网页会话、精确 Alpha/组件处理和候选预览集中在 `implementation_20260902/lin_chong_p0_source/`，生产溯源清单为 `Liangshan-Heroes/assets/campaign/lin_chong_p0_direction4_manifest.json`。四次改前备份均在源码仓库外的 `implementation_20260902/`，未覆盖、删除旧证据。
- 本地处理仅为连续矩形裁切、批次统一等比缩放、透明补边和格式接入；没有本地镜像、补画、遮罩或清除源像素。网页精确处理的低 Alpha 与连通组件所有权已经由候选流水线逐字节复核。
- 囚徒目标验证 60 项、搀扶目标验证 26 项、真实第六关搀扶事件 12 项、动作合同 74 项和公共四向 164 个可移动定义均通过；固定截图不替代真人完整通关、玩法节奏或长时间性能验收。
- 只采用了上述 5 个剧情状态。旧 `lin_chong_prisoner/lin_chong_bound/lin_chong_escort` 的 `attack/hurt/down` 文件仍在生产目录，本轮未重画或删除；无意义状态的路由隔离与历史文件清退仍是 LC-03 债务。押送 `idle` 也未计入本轮采用。
- 鲁智深持续搀扶出林是玩法压缩，不是逐段原著还原：原著持续扶行者是董超、薛霸。下一安全起点先做江州法场专用 `li_kui_jiangzhou`；若随后提高野猪林贴合度，再制作董超、薛霸的持续搀扶状态或调整现有关卡表达。
- 本批没有导出、修改 Steam 发布目录、上传或发布；项目整体真四向和环境美术仍未完成。

## 历史批次：2026-09-02 侧边栏原著人物批次

- 用户登录的侧边栏网页ChatGPT已完成鲁智深、孟州武松和蒋门神三组原著造型。每组均为 `idle/walk/attack/hurt/down × se/sw/ne/nw` 的20张独立256×256 RGBA单帧；本地只做连续矩形裁切、全批统一等比缩放、透明补边和逐字节接入，没有镜像、补画、遮罩、清像素或局部改方向。运行目录现为campaign anim 316张/416帧、objects 72张、portraits 36张。
- 蒋忠新图已关闭旧合同的三项P0冲突：白布衫、紫褐黝黑皮肤、青筋、黄髯、徒手；中腹后护腹弯身，中额后向后倒地仍活着告饶。网页输入ZIP、下载ZIP、候选manifest和精确清理复核SHA-256分别为`e121f2445427c74c9e1ceba6ee6655019a297a30066048e02e6d796a3e33eaa7`、`20164510657fa813f5173251ddee0671ab88e3f6acff3b9ef361f82976273f75`、`2e148c33ed2029c800fd88ec7a91c8a988f5026ee4dd36c6fd1ed12147257f63`、`6bd8eeacf28ada1c8b05c8436a1b45e65e4c9261c6cb4d43ff708b1730b3c251`。
- 蒋门神批次静态溯源57/57、真实Unit与非死亡结果126/126、战役美术159/159、快活林深度19/19、六模式及回战役隔离35/35、前四关主链和失败分支通过；1280×720 Vulkan视觉32/32，40节点3秒夹具P95/P99为8.719/9.525ms。严格八关来源覆盖现为37/347；58项已有四向文件但来源仍不合规，252项缺图或方向不全。完整证据在`Liangshan-Heroes/qa/jiang_menshen_direction4_production_20260902/`。
- 图鉴复核确认可复用基础此前被低估：95/347项实际已有四向文件，58项旧文件先做视觉、原著和来源复核，不立即重画；252项缺方向中124项已有同人物同动作的图鉴帧带可作网页参考，128项才需从零制作。缺方向项的四行网页图集理论最低量由78张降为63张，旧图复核淘汰项另计。结构报告与四张总览在`Liangshan-Heroes/qa/campaign_direction4_reuse_audit_20260902/`；此分类没有把单视角横条冒充真四向完成。
- 林冲被缚/脚伤阶段与江州李逵专用造型仍未完成，下一安全起点以`Liangshan-Heroes/docs/ORIGINAL_ART_CONTRACT_NEXT_BATCH_20260902.md`为准。短夹具不替代战役高峰对比、30分钟稳定性、真人节奏、平衡和点选试玩，当前仍不能称八关四向美术完成。
- Steam发布目录仍为597个文件，规范聚合SHA-256为`b7b4ec1aee0e36903821a723b8982d0f16ec6442e7f16cab3106e5f7f139c506`。本批没有导出、修改Steam目录、上传或发布。

## 历史基线：2026-09-02 候选验收边界（已被上节更新）

- 共享阴影已把移动单位的接触影和右下投影合并为单个 MultiMesh 批次，并为无高度场的平地模式增加 fast path；建筑继续使用纹理轮廓影。六模式1280×720实渲染105/105。三组成对 OFF→ON 短采样中，ON 最大 P95 12.423ms、最大 P99 16.839ms、最大相对同对 OFF P95 为1.0731倍。
- 环境提示词静态自检已由旧51/51更新为502/502。环境生产路由69/69 consumer-ready，静态合同785/785、运行合同758/758、八关固定机位32/32、六模式100/100；这只证明消费者接线，生产PNG仍为0/69。当前环境报告SHA-256为`16dda6894bfc1bb54584ac90180de2227d6df6a34174192a6638fd8068405f43`，映射模板SHA-256为`af1204a50a865096be47917440a36c67d9290f295fd5ee1ac2f8e000b1d441f1`。
- 该历史轮次真四向严格覆盖为13/347，至少还需84张网页版图集，即首批10张和后续74张。首批接入门禁自检63/63，其中18/18为拒绝类负例；`wu_song_mengzhou`须按快活林时期单独制作，通用武松素材不能计入。该轮覆盖报告、首批清单和冻结注册表SHA-256依次为`beb882b32b85af6d2e6157700659f8242c297375943036dd5d9feee8c0f81f50`、`22a6f8ae5d57ea67020fc2dacca5c6331f49613cd96acfb893f2a1cc416e6b20`、`e2b37a4062d275b5a7b7b4084cf61491d4b179a611372bc5f3cdcd0ab4761bb2`。原著文案与旗号复核为72/72。
- 终章水战自由路线已修复：诱船前五艘官船被玩家全灭时转入`gao_first_direct`基础路线，死船不再触发`fleet_in_ambush`。`qa/fleet_edge_fix_20260902`边界11/11通过，关联复测共165项；该结果不替代真人终章试玩。
- 90秒模式切换短测完成28次切换，但不具备正式验收资格；30分钟soak尚未运行。音频退出重复验证9/9及完整矩阵8/8均为零泄漏。两份音频改前备份与四向重切片备份已移到源码仓库外的`<workspace>\implementation_20260902\`，仓库内`implementation_20260902`现无子目录；清理后编辑器重跑无嵌套工程扫描警告。没有真人节奏、平衡和点选试玩，也没有Android真机生命周期验证。
- 综合门禁`qa/final_local_gate_20260902`为本地代码94/94 PASS、发布门禁FAIL，报告SHA-256为`f23d0068a3c9d846086f538a9d2fa14f6b76e8d7365cb48c583cfaa49a6bb3f7`。物理白名单工具自测9/9通过；dry-run统计1,954个文件、181,242,837字节，但环境0/69、四向13/347，`commit_ready=false`。未建立候选、导出EXE、修改Steam发布目录、上传或发布公告。
- 该历史轮次网页端发送仍等待动作时确认，69张环境PNG及84张人物/兵种四向网页图集尚未生成；后续实际进度以上节为准。战役美术至今仍未完整覆盖，也不能进入发布阶段。

## 当前开发状态：2026-09-02 原著文案与网页环境提示词

八关任务、对白、战报、小传和旗面白名单已重新核对。玩家文案现明确“河阳风月”为酒望，祝家庄由顾大嫂在堂前发信号、邹渊邹润守监门开陷车，并补全徐宁宝甲及大名府时迁、蔡福分工；任务目标、阶段和动作 ID 未改。`Liangshan-Heroes/tools/campaign_copy_audit.py` 最新静态结果为72/72，原著与游戏压缩边界见`docs/CAMPAIGN_COPY_AUDIT_20260902.md`。

`implementation_20260902/environment_prompt_drafts_v2/`已准备9份只供用户登录网页版ChatGPT发送的环境美术提示词。第二轮独立复核后静态自检为502/502；64个图集格均锁定关卡专用`CampaignEnvironmentArt`路由，旧`town_house/zhu_hall/zhu_gate`全局接入口已从生产目标清除。冻结manifest SHA-256为`162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf`。当前尚未发送、没有源PNG、没有接入生产素材；本地后处理仍只允许整格矩形裁切、统一缩放、透明补边和Godot导入，禁止镜像、补画和清除像素。Steam目录、EXE与平台均未操作。

## 当前开发状态：2026-09-02 真四向来源门禁

严格覆盖合同 `Liangshan-Heroes/tools/campaign_direction4_coverage_audit.py` 已按八关实际部署列出 347 个唯一“人物/战役变体/状态”。当前 `qa/campaign_direction4_coverage_20260902/report.json` 只认可 13 项（3.746%）：原有 9 项加上从具备完整透明分隔带的旧网页原图无损重切出的喽啰、梁山朴刀、长枪、弓手 idle。该重切片只做整格矩形裁切、按行等比缩放和透明补边，未镜像、补画或清除格内像素；改前文件在源码仓库外的 `<workspace>\implementation_20260902\pre_grid_reslice_core_liangshan_20260902\`。

仍有 71 项现存文件因旧处理来源不合规、263 项缺失或方向不全，理论最少需 84 张四行网页图。首批八类样板固定为林冲、鲁智深、武松、李逵及梁山朴刀手、官军刀盾兵、钩镰枪手、连环甲马，共 10 张 `idle/walk/attack/hurt/down`。网页端尚未发送本批提示词，Godot 尚未重新导入这些重切片；Steam 发布目录和 default 构建未改。

## 当前开发状态：2026-09-02 八关五类地表

八关战役已经接入黄土、林地、湿岸、石土、田地五类连续绘制，普通自然边缘为 12—24 像素过渡，码头、桥面、台阶和登记墙基仍保持硬边。建筑占地的视觉地面继承周边材质，城市关卡不制造院内土丘；逻辑格、碰撞、寻路、三类移动权重和高度场开关前后不变。合同 82/82，八关 100%/150% 固定镜头 32/32；静态部署 P95 为 4.596—13.857ms。

这些结果没有消除旧建筑贴图自带的浅色方底，也未解决祝家庄田地、野猪林树木和芦苇的规律重复。缺口及网页替换顺序见 `Liangshan-Heroes/docs/CAMPAIGN_ENVIRONMENT_VISUAL_REVIEW_20260902.md`。共享阴影与固定短采样性能已完成本轮门槛，边界见本文最前方；网页环境位图、30分钟soak和真人试玩仍未完成，Steam 未更新。

## 当前开发状态：2026-09-02 战役美术需求合同与混合态快照

下一批战役美术以`Liangshan-Heroes/docs/CAMPAIGN_ART_REQUIREMENTS_20260902.md`为实际任务单：它从八关脚本列出被引用人物、variant、船只、物件、`captured/subdued/unconscious/retreated/embarked`等非致死结算，以及每项需要的通用或剧情动作。只读合同工具`Liangshan-Heroes/tools/campaign_art_requirements_audit.py`已连续两次生成相同的静态报告SHA-256 `E1B6BF993E7B97BEE2B09202BE93B0BF39D07F8A706BCF03C5C0CE63FEEF3772`；它不运行Godot、不生成图片，不替代编辑器导入、1280×720视觉QA或真人试玩。

`<workspace>\_archive/baselines/art_requirements_baseline_20260902_024451\source_material_mixed_sha256.json`记录02:55:40的2,116项源码/素材SHA-256，内容索引为`8bdef790c99dcdb69138741fa432c4e319d1a0142ae53355631d8112079b5a72`。该清单在地表/阴影和`art_db.gd`的并发改动期间建立，故为“并发后稳定混合态”而非开工前备份；不得据此声称保留了改前`art_db.gd`。当前素材计数须按范围读：普通四向manifest为6源/96输出，四向物件manifest为4源/48输出，网页批次为16源/129 artifact，运行目录为campaign anim 300、objects 72、portraits 36 PNG。早期的80输出与188/312/22/20是历史批次数字，未被重写为当前总数。

本轮不修改Steam发布目录、EXE、导出物或平台资料，未上传。网页图只在下一批实际生成后按原图、提示词、对话地址、SHA、裁切与各类验收证据另行记录。

## 当前开发状态：2026-09-01 普通单位公共四向

本地源码曾在 Steam BuildID `25051529` 之后接通普通资源四向入口：支持`assets/anim/<key>_<state>_<se|sw|ne|nw>.png`和按方向缓存，`unit_texture`可选接收方向且旧调用兼容；非终态缺动作时保持同方向idle，`death/down`保留旧终态或程序化倒地。所有非建筑且可移动定义维护四象限，攻击、技能施法、物品施法和冲锋起手锁向；真实定向帧不再被水平镜像，梁山坡面阴影使用相同判断，战役非法方向直接拒绝。该源码后续已进入当前 default BuildID `25121101`。

五张网页版ChatGPT透明原图及完整来源追溯在`Liangshan-Heroes/assets/direction4/manifest.json`；第五张`web_direction4_story_convoy_lianhuan_v1.png`的SHA-256为`440a44c45fce2572d56ed3b45ab5379902cdb8f486f5f098f737be1d57f550ac`，新增`jun_han`、`gou_lian`、`lian_huan_ma`、`jiang_thug`四类×四方向。当前manifest共80个输出，即20个普通key的四方向单帧idle，Godot导入成功。最新版`Liangshan-Heroes/qa/direction4_20260901/headless_convoy_lianhuan_final.log`为39/39、exit 0，无ObjectDB、Leaked instance、orphan StringName或其他退出告警；其中164是被遍历的可移动定义数，不是素材覆盖数。最新版真实Unit夹具`Liangshan-Heroes/qa/direction4_20260901/runtime_visual_convoy_lianhuan_final/report.json`和`Liangshan-Heroes/qa/direction4_20260901/visual_convoy_lianhuan_final.log`在真实1280×720 Vulkan下覆盖20个key，165/165、exit 0，没有Texture RID泄漏、RenderingServer析构警告或其他日志问题，并输出五张分组图。当前战役实际使用的15个普通可移动key覆盖13个，余下`yu_hou`、`lao_duguan`；水战船仍需独立方向接口。108英雄、完整四向walk/attack/hurt/death、真人试玩和长时间性能仍未完成。

这轮完成时没有重新导出或上传，Steam default 仍是 BuildID `25051529`，不含普通四向公共层、80张idle和此前尚未发布的死亡残留。其后这些源码与资源已随 `2026-09-04` Windows 测试构建进入 default BuildID `25121101`。

本地源码曾在 Steam BuildID `25051529` 之后新增战役死亡残留：普通陆地人物真实死亡后保留45秒的血迹、断兵器、破布和散落装备，剧情非致死终态、建筑、召唤与水上单位不生成。素材由网页版ChatGPT实际生成；来源、接入、68项核心测试与1280×720实机图见`Liangshan-Heroes/docs/CAMPAIGN_DEATH_REMAINS_20260901.md`。该批完成时尚未重新导出或上传；其后已随 `2026-09-04` Windows 测试构建进入 Steam default BuildID `25121101`。

当前源码在八幕事件战役、网页ChatGPT美术和2026-09-01游戏性加深批次之后，已完成“自由通关 + 原著演义印”改造：八关各有一个核心胜利，玩家不按原著章法也可继续完成核心；同一局完成全部原著目标才收录该关演义印。最终证据为公共交互22/22、前四关47/47（19次移动、4次攻击）、后四关69/69（8次移动、10次攻击，任务按钮调用0次）及串行回归21/21；运行期文件哈希前后不变，无脚本或解析错误，15/21作业保留既有ObjectDB退出警告。终章六结局6/6、depth 52/52，UI 5/5通过。该源码曾导出为 Steam Windows BuildID `25051529` 并切到 default，服务器回下载哈希一致、启动退出码0；完整历史证据见 `Liangshan-Heroes/docs/STEAM_RELEASE_20260901.md`。后续 default 已更新为 `25121101`，详见 `Liangshan-Heroes/docs/STEAM_TEST_BUILD_20260904.md`。当前规则见 `Liangshan-Heroes/docs/CAMPAIGN_FREEPLAY_REWARDS_20260901.md`，真实指令证据见`CAMPAIGN_MANUAL_ORDERS_20260901.md`，历史游戏性证据见 `CAMPAIGN_GAMEPLAY_DEPTH_20260901.md`，美术冻结批次见 `WEB_CHATGPT_ART_DELIVERY.md`，汇总见 `CAMPAIGN_IMPLEMENTATION.md` 与 `WORKLOG.md`。真人15—25分钟、拥挤点选、玩法趣味、完整动画和长时间内存/性能仍未验收。

v8历史证据在 `_archive/campaign_history/campaign_environment_v8_20260831/` 及 `Liangshan-Heroes/campaign_environment_v8_20260831/literary_final_all8_v2/`，不再代表当前战役。当前试玩入口为 `Play-Campaign-Rework.cmd`，运行源码版1280×720；本批证据独立保存在 `Liangshan-Heroes/qa/web_chatgpt_art_20260831/`。`Preview-Campaign.cmd` 保留作环境预览，不用来验证完整剧情。

## 来源和位置

- 上游仓库：https://github.com/winterzh/Liangshan-Heroes
- 下载时 main 提交：`0109b6f32349765746b080ba06298c249ba6db7d`。
- 提交时间：2026-08-10 09:56:00 UTC；提交说明：移除第三方游戏引用并发布 v1.8。
- 本地源码：`<workspace>\Liangshan-Heroes`。
- Godot 入口：`Liangshan-Heroes\project.godot`。
- 主场景：`Liangshan-Heroes\scenes\menu.tscn`。
- 主要代码：`Liangshan-Heroes\scripts`，原始副本含39个`.gd`文件；后续样板新增源码见各轮对比报告。
- 保留归档：`_archive/source_packages/Liangshan-Heroes-0109b6f-complete.zip`，205,585,800 字节。
- 归档 SHA-256：`E3DADE09859A9125B81D1E9ED9008552FDD94D916C7681CFCD46F15A65D4BBC8`。
- 本地副本由 ZIP 解压得到，没有 `.git` 历史；Git 下载未成功。

## 下载时已验证（原始副本）

- ZIP 共 1,014 个条目（含目录），CRC 检查通过。
- 解压出 1,005 个原始文件；Godot 导入后逐文件 SHA-256 对比，无缺失、无变化。
- Godot：`<godot_install>\Godot_v4.6.3-stable_win64_console.exe`。
- 已执行 `--headless --path <本地源码> --import`，退出码 0。
- `_logs/godot-import.log` 中未发现 error / warning / failed / parse / 错误 / 警告匹配。
- `.godot` 是本地导入生成的缓存，原始源码未修改。
- 两份中断的 ZIP 下载已清理，仅保留通过检查的完整归档。

## 使用和边界

用 Godot 4.6.3 编辑器选择导入上述 `project.godot`，按 F5 可启动项目。下载阶段仅完成无界面导入验证；后续视觉样板的实际运行记录见下节。

Steam 发布目录为 `<steamworks_workspace>`。`2026-09-01` 的 BuildID `25051529` 是历史发布基线；当前 Windows `default` 已于 `2026-09-04` 更新为 BuildID `25121101`、manifest `6833015574013725084`，服务器回下载 EXE 的 SHA-256 为 `2F0C5786B368BD9F2C4A56893F1AB5872511B72DCB84BC96D667C3075F4295F6`。本轮没有处理 macOS，没有修改价格、折扣、发行日期、AI 披露、评级、商店素材或语言，也没有点击 `Release App`。完整边界以 Steam 工作区的 `PROJECT_STATUS.md`、`PROJECT_HANDOFF.md` 和本源码的 `docs/STEAM_TEST_BUILD_20260904.md` 为准。

继续开发前阅读源码 README 和 docs 中的相关设计、完成记录；`docs/TODO_HANDOVER.md` 是历史归档。工作区新增源码与 Steam 发行工作区应保持区分。

## 当前开发状态：2026-09-01 八关自由通关与演义印

- 战役胜负拆成核心目标与演义目标。基础通关不要求照任务按钮的唯一顺序；提前现身、强攻、跳过训练、公开攻城或直接迎战等分支已经进入关卡脚本。只有人物全灭、必须营救者死亡、目标物被毁、忠义堂失守或再无可用兵力等核心不可能情况才判负。
- 任务按钮只代为派遣。玩家手动办理必须保留显式点击目标、同组一次性 token，并让人物实际进入办理范围；点击半径与物理办理半径分开，多个有效标记按全局最近者认领。江州中点反例验证人物同时处于两处办理范围时，点击两标记中点也不会串救。有效的移动、攻击、技能、物品、驻扎、维修、续建、新建和陷阱等玩家改令会取消任务按钮路线，但不会伪造任务完成；无效操作不取消。菜单与战报分别显示基础通关、单局最佳演义复现和演义印；不同重玩不会把互相冲突的零散目标合并成一次满完成。演义印不增加属性、资源、兵力或永久能力。
- 八关核心、3—4项演义目标、自由分支、原著章节链接和改编压缩见 `Liangshan-Heroes/docs/CAMPAIGN_FREEPLAY_REWARDS_20260901.md`。第七十九回口径是“刘唐受计掌管水路、公孙胜祭风、众水军小船入连舰举火”；当前玩法让公孙胜和刘唐实际到场，并以刘唐的一条可操作代表火船、两条接应船压缩原文规模。
- `Liangshan-Heroes/qa/campaign_freeplay_rewards_20260901/final_regression/report.json` 记录21/21串行作业通过，运行期文件哈希前后不变，无脚本或解析错误；15组作业保留既有ObjectDB退出警告。终章 `specialist_loss` 已修复为专用船损失后自动转入正面水战，必须实际达到 `core_cleared` 才能基础通关，六结局6/6、depth 52/52通过。真实指令和 UI 5/5 证据在`Liangshan-Heroes/qa/campaign_manual_play_20260901/`；最拥挤面板与命令栏相隔117像素。随后已另行完成 Windows 成品导出、八关逐关启动、SteamPipe 上传、default 切换和服务器回下载启动验证。自动化、解析、截图和代理辅助桌面观察仍不等于真人试玩；旧计时仍属于自由改造前历史证据，真人节奏、点选手感、玩法趣味与长时间内存/性能继续分开验收。

## 历史开发状态：2026-08-31 梁山视觉样板 v1

- 用户已确认制作局部样板。当前本地代码已不同于原始 ZIP；原始归档和 3 个修改文件的基线备份仍保留。
- 第 5 关新增独立树木、树冠遮挡避让、坡岸明暗和统一贴地投影；未扩展到其他关卡，未改四向动画或死亡残留。
- 双击 `Preview-Liangshan.cmd` 可进入只读视觉浏览，方向键移动、滚轮缩放；没有开战入口，不推进波次、不写游戏存档。它不是完整试玩入口；完整运行仍用 Godot/F5。
- 对比文件：`_archive/visual_samples/visual_sample_20260831/compare.html`；运行与验证详情：`_archive/visual_samples/visual_sample_20260831/README.md`；开发过程：`WORKLOG.md`。
- 默认 Forward+ 实际渲染截图已检查，林下点选/穿林/树冠避让恢复检查通过，前后玩法快照一致。未完成全战役或大规模战斗性能验收。
- 原始版与样板均可见退出时 Texture/RID 清理告警，未在本轮改动其机制。内置浏览器禁止访问本地 HTML，对比页仅做静态资源检查，未完成浏览器交互验收。

## 历史开发状态：2026-08-31 梁山入口与台地样板 v2

- 用户提出寨门对准码头和高低地形，本地第5关现在连接了主码头、上坡石阶、敞开寨门和聚义厅前院；另留东侧坡口接原道路。只读预览的默认镜头已对准这条入口路线。
- 本轮有意修改113个地形格，其中新增36格陡边阻挡、19格水面码头/引道通行；不再沿用 v1 的“全部玩法快照一致”结论。没有真正的高度坐标或高地战斗加成。
- 初始19个单位与两条原进攻路径仍相同；码头到厅前的双方寻路及实际士兵往返、门架与树冠避让/点选检查通过。原版开关重新运行的6类状态与原始基线相同。
- 入口截图及证据：`_archive/visual_samples/visual_sample_v2_20260831/README.md`；原版和v1截图未覆盖，v1源码备份位于 `_archive/visual_samples/visual_sample_v2_20260831/v1_source/`。
- 门架材质、规整台地及格状岸线仍有美术细化空间；未做完整战役平衡、兵海压测或真人试玩。原有退出清理告警保留。Steam目录、发行EXE和平台未操作。

## 历史开发状态：2026-08-31 梁山场景细化 v3

- 用户要求继续，当前第5关细化了岩台边缘、碎石、自然岸线渐变及程序门架的瓦片/木纹；地块、通行、权重、初始单位、进攻路线及装饰列表与v2保持一致。
- 内置图片工具生成的两张新门楼图没有真实透明通道，仅保留在 `_archive/visual_samples/visual_sample_v3_20260831/art_reference/`，没有接入游戏。实际效果以 `_archive/visual_samples/visual_sample_v3_20260831/after/` 截图为准。
- 码头往返、绕岩壁、门内点选和树冠避让已实际验证；详细证据、生成提示词和保留问题见 `_archive/visual_samples/visual_sample_v3_20260831/README.md`。只读预览继续使用 `Preview-Liangshan.cmd`。
- 不等同完整山体、战役平衡或发布验收；Steam目录、EXE和平台未操作。原有退出清理告警保留。v2源码和旧截图均有备份。

## 历史开发状态：2026-08-31 梁山局部高度场 v4（高台造型已撤回）

- 第5关聚义厅台地抬升48渲染像素，寨门中心15.75、码头0，形成连续坡面。地面、人物、阴影、树木及门架随高度同步；鼠标点选和跨位置特效采用统一投影。没有新增高地射程/伤害规则。
- 地形、通行、权重、19个初始单位、原进攻路线、装饰6类状态与v3一致；原版及单独关闭高度开关均已重新运行验证。实际上/下坡、坡上点选、跨坡箭线、码头往返和绕岩壁通过。
- 只读浏览仍用 `Preview-Liangshan.cmd`，新增 `flat` 参数关闭高度，`baseline` 恢复原版。实机截图、详细证据和保留限制见 `_archive/visual_samples/visual_sample_v4_20260831/README.md`，v3源码备份在其 `v3_source/`。
- 完整项目第1/5关加载与原生只读预览启动均退出0，无SCRIPT ERROR；原有退出清理告警仍在。当前累计改4个原始文件，未改原图集；三份用户CFG哈希未变。
- 本轮不是完整战役/全部技能/兵海或发布验收。门架仍为程序绘制；CPU与GPU格内插值及局部平面阴影的近似限制已记录。Steam目录、发行EXE、平台始终未操作。

## 历史开发状态：2026-08-31 梁山寨院关系修正 v5

- 用户明确指出v4高低坡不和谐、不符合建筑关系。本轮撤掉厅前土丘，厅堂与寨门处于同一片18渲染像素院地；建筑使用贴图自带的台基/台阶，高差在寨外缓坡消化。不得把v4的48/15.75/0高差继续作为当前设计。
- 寨门补齐瓦顶、梁柱、匾额和向内敞开的门扇；66段木寨墙在原不可走边界上与门连接，墙下用低石脚，保留南门及东侧通路。门墙遮人时透明避让，不新增可破坏墙、关门或高地战斗机制。
- 原生实机通行、绕墙、屋顶及墙后点选/恢复、院内平整和外路缓升、8976点坐标往返检查通过；6类玩法状态与v4一致，原版/关闭高度对照通过。导入、第1/5关加载及只读预览退出0，无新增脚本/瓦面绘制错误。
- 当前预览：`Preview-Liangshan.cmd`。效果、参考依据、历史失败日志及未验收范围见 `_archive/visual_samples/visual_sample_v5_20260831/README.md`。v4被修改的源码备份在其 `v4_source/`；原始ZIP和旧图不覆盖。
- 原图集未变，原1005文件无缺失，累计仍只改4个原始文件；三份用户CFG哈希未变。Steam发布目录、EXE和平台未操作。后续先取得用户对建筑关系的反馈，再做材质细化或完整战役回归；不将本轮称为梁山历史原貌复原。

## 历史开发状态：2026-08-31 梁山门墙与院落重排 v6

- 用户认为v5仍不行，本轮主门外移三格到(16,40)，院落南边同步延长；直线木寨墙替代曲线细栅栏，东门补齐门口形态。木墙复用原图集，主门降低/收窄，中央石路接厅前，院内整理为土院地，墙格增加两座视觉哨楼。
- 保留平整院地18与建筑自带台基，不恢复土丘。主/东门各留三格通道，寨外缓坡改为41—46格。门墙/哨楼没有耐久、攻破或驻军机制。
- 有意改114地形格、24阻挡状态（新增16/开放8）、61格权重；所有变化在x10—22、y27—42内，范围外状态未变。19个初始单位相同，两条敌军路径仍各38点，但完整路径已有变化；本轮不再宣称玩法完全没变。
- 主/东门真实通行、绕墙、门墙/林下点选恢复、坐标与高度检查通过。原版/无高度对照、导入、第1/5关加载和只读预览启动通过；原退出清理告警保留，三份CFG哈希不变。
- 预览仍用Preview-Liangshan.cmd，当前证据和保留问题见_archive/visual_samples/visual_sample_v6_20260831/README.md。累计仍只改4个原始文件，原图集未动。墙脚/门顶拼接感、完整战役与最终美术仍未验收；Steam目录、发行EXE及平台未操作。

## 当前开发状态：2026-08-31 梁山泊周边环境 v7

- 用户指出周围像孤岛，本轮依据《水浒传》第十一回的芦苇水港、金沙滩、林路与群山中的平地，重做第5关外围：北/西接林麓，南侧为码头湾水、低滩和苇荡，东港保留双堤；原椭圆环岛地形已撤换。来源链接和改编范围见_archive/visual_samples/visual_sample_v7_20260831/README.md，不声称历史测绘或完整重建三关。
- 寨院与门口继续平整18、码头0；后山为宽缓山脊，水格四角归零，未恢复院内土丘。最终182棵树，苇丛以静态网格批量绘制；新增2艘装饰船、3组裸岩，11岩格阻挡与视觉位置对应。
- 对比v6有1983地形格、1582阻挡状态、1964权重格调整；寨院/布阵区/原道路均不变，19初始单位与两条各38点敌军路径完整相同，波次与战斗代码不变。新林麓/苇滩可走，不能称玩法全不变；封双堤后没有新增第三陆路。
- 主/东门、码头、林下与后山实际行走、点选、遮挡恢复和全图57,600点投影测试通过；水面0高度、船在水/帐篷在岸通过。原版/无高度对照、导入、第1/5关加载和只读预览均通过；旧退出清理告警保留。稳态部署镜头约58—60FPS，不是兵海验收。
- Preview-Liangshan.cmd指向v7，默认先看寨院与周边。v6相关源码在v7的v6_source，旧图和失败证据保留；原1005文件无缺失、原图集未动，累计4个原文件修改及18个新增源码/UID文件，三份CFG不变。完整战役、三关/断金亭、最终美术与真人试玩仍未验收；Steam目录、EXE与平台未操作。


## 历史记录：2026-08-31执行状态

源码现已进行战役事件/导航/水路/美术接口实改，不再是只读复核。完整实施基线与日志在 `_archive/campaign_history/campaign_rework_20260831_173850/`；阶段记录见 `Liangshan-Heroes/docs/CAMPAIGN_IMPLEMENTATION.md`。尚未全案验收，尤其15–25分钟节奏与真人试玩没有通过。Steam发布目录未改，未导出上传。

## 历史入口：2026-08-31战役重做 content2

双击`Play-Campaign-Rework.cmd`或Godot导入`Liangshan-Heroes/project.godot`运行源码。菜单按原著顺序显示八关，仍全部可选；`LEVEL=N`保持旧levelN含义。默认1280×720，任务按钮指挥人物实际到场，故事胜负已有真实主链回归。

以下内容只描述 `2026-08-31` 当时的本地候选，不代表当前 Steam 状态。当时的具体实施、原文/改编、素材、画面、性能和剩余15—25分钟内容问题分别记录在`Liangshan-Heroes/docs/CAMPAIGN_*.md`，统一入口为`CAMPAIGN_IMPLEMENTATION.md`。截至该历史批次末，Steam发布目录尚未改动；后续 `2026-09-01` 的正式 Windows 构建记录以本文开头及`Liangshan-Heroes/docs/STEAM_RELEASE_20260901.md`为准。

## 2026-09-01 先锋头船旗号批次（源码候选，未发布）

本条是在既有 Steam BuildID `25051529` 之后的本地源码记录，不改变该 BuildID 的已发布事实。本批没有触碰 Steam 发布目录、EXE、SteamPipe 或商店页面，也没有导出或上传。

第5关终章把第八十回丘岳、徐京、梅展所领的三十只大海鳅前队压缩为 1 艘 `official_vanguard` 与 4 艘无字普通官船，高俅中军另置。`搅海翻江冲巨浪，安邦定国灭洪妖` 是两面红旗合书的一组编制旗文；各七字分排是游戏版面，并非个人旗或原著指定的左右分配。第七十八、七十九回没有可安全采用的官军旗面文字，故普通官船无字；高俅 `帅` 是中军识别的游戏压缩。梁山山顶及忠义堂文字、白名单和原著链接见 `Liangshan-Heroes/docs/CAMPAIGN_FLAG_SOURCES_20260901.md`。

先锋 4 状态 × 4 真方向无字源图仅由网页端 ChatGPT v3 生成：<https://chatgpt.com/c/6a96b875-8320-83ea-80ad-57f1790022b9>；源图/提示词 SHA-256 分别为 `ADE7510DB70BE9FC2FB0DC8F4442855CF3B3D921D9BEB09D65F810A18BF50FD0` 与 `1270E91A308CA1282A63CC33F1E004B1D0D54CE925C3BDAF3FC75A93AC0DD180`。只做安全透明缝裁切、统一缩放和透明补边；v1 旗布过小、v2 只有 6 像素横缝，均淘汰。

本批自动旗号合同 24/24、终章编制合同 58/58；真实第5关 Unit 1280×720 画面夹具 77/77，且旗文近景已人工检查。自动与画面证据不能代替水路战斗、全战役通关、长时间性能或真人试玩；后四项仍待单独验收。

## 当前开发状态：2026-09-02 网页地表整图映射候选

- 九张网页地表在256px重复图块门槛下均不合格，合法单矩形裁框也没有通过项；不得把这些图当作无缝小图重复使用。完整候选、3×3预览、raw/prompt/correction SHA和失败报告见`Liangshan-Heroes/qa/environment_surface_normalization_20260902/summary.json`。
- 当前本地候选改用整图映射：干土、林地、湿岸A和硬地四张完整1254 RGB原图只做全255 alpha与整张等比缩放到2048 RGBA；每张图在关卡地图只映射一次，关闭repeat并夹到半texel。field仍回退旧atlas。没有裁切、拼接、修缝、镜像、补画或局部像素处理。
- 八关运行合同90/90、来源和shader合同48/48、路由785/785；八关固定机位已检查。性能组合32/32，选定样本最大P95 16.17ms、P99 22.293ms、Web/atlas比1.0021。失败负载轮保留，静态门槛不能替代战斗高峰、30分钟稳定性或真人试玩。
- 详细实现、备份和证据见`Liangshan-Heroes/docs/ENVIRONMENT_MAP_CLAMPED_20260902.md`。本批没有导出、没有改Steam发布目录、没有上传发布；Steam现有状态仍以前文正式发布记录为准。

## 当前开发状态：2026-09-03 高俅四向 P0（源码候选，未发布）

- 第5关已接入同一艘中军海鳅船 `default/damaged/flooding/disabled × SE/SW/NE/NW` 和换鲜绢衣前的湿衣被擒高俅 `idle/down × 四向`，均使用网页原生透明源图。
- 网页旗布无字；运行时只在 `level5 + gao_flagship + chapter80_gao_flagship` 严格上下文写一个“帅”字，不再绘制本地旗布底色。普通官船保持无字，通用高俅资源保持独立。
- 生产合同149项、战役美术160项、动作74项、旗号30项、旗号视觉144项、终章深度59项、最小四向196项、后四关自由路线26项均通过；第5关24张1280×720实际对象截图人工图检通过。该结论不包含真人完整通关、战斗高峰或长时间性能。
- 严格来源覆盖现为 `49/347`，原58项旧四向已有11项完成合规替换、47项仍待处理；251项仍缺图或方向不全。下一批为黄泥冈七星与白胜。
- 来源、提示词、失败稿和哈希在 `implementation_20260902/gao_qiu_p0_source/README.md`；运行证据在 `Liangshan-Heroes/qa/gao_qiu_p0_runtime_20260903/`。本批没有导出、没有改 Steam 发布目录、没有上传或发布。

## 当前开发状态：2026-09-03 黄泥冈七星与白胜 P0（源码候选，未发布）

- 第1关已接入晁盖、吴用、公孙胜、刘唐、阮小二、阮小五、阮小七、白胜的 `idle/walk × SE/SW/NE/NW`，以及白胜肩挑酒桶的 `carry_idle/carry_walk × 四方向`；共72张动作文件和8张实际头像，限定黄泥冈战役变体，不替换自由模式通用造型。
- 原著边界取百二十回本第十四至十六回：七星在黄泥冈酷热脱衣乘凉，保留人物面貌、体态、朱砂记、胸毛、青豹子胸纹等辨识；白胜是独立挑酒汉。为分级仅给七星保留朴素腰布/短裤，不把它写成原文逐字服饰。
- 九组源图中6组复核采用，刘唐、阮小五、阮小七因旧稿邻格碎片或串帧整张重画后采用。网页端只执行 `alpha<=15 -> RGBA全0` 精确清理，本地只做连续矩形固定网格裁切、统一比例缩放、透明补边、编码和导入，没有镜像、遮罩、清像素或补画。
- 80个生产目标晋级前均有逐字节备份。生产 manifest 为 `Liangshan-Heroes/assets/campaign/huangnigang_p0_direction4_manifest.json`；来源、会话、完整哈希和判退稿见 `implementation_20260902/huangnigang_p0_source/README.md`。
- Godot重新导入80项后，黄泥冈美术238项、战术全分支、搬运4案、深度5案、自由路线18项、全局美术160项和动作74项均通过。16张1280×720图形窗口实拍已人工检查；结论不含真人完整通关、战斗高峰或长期性能。
- 当前严格四方向来源覆盖为 `67/347`；旧四向待复核 `29`，缺失/不完整 `251`，最低剩余网页四行图集 `63`。下一批为第4关连环马，先对4张已生成源图做网页精确Alpha清理，再生产和实机验证。
- 本批没有导出，没有修改 Steam 发布目录，没有上传或发布；已发布 Steam BuildID 仍以前文记录为准。

## 当前开发状态：2026-09-03 连环甲马 P0（源码候选，未发布）

- 第4关 `lian_huan_ma` 已接入 `idle/walk/attack/hurt/death × SE/SW/NE/NW` 共20个真方向文件，行走每方向两帧；只替换本地源码资源，不涉及Steam成品。
- 原著边界取百二十回本第五十五、五十七回：骑手深盔护项只露眼缝，战马重甲覆腿只露四蹄，侧环短链表达每三十匹连锁的编制压缩；受击/死亡对应钩镰破阵，不画血腥断链。
- 原攻击源图因相邻方向重叠导致固定裁切串格而判退；两张带烘焙棋盘的RGB重出也判退。最终攻击 V2 为真RGBA并从自然透明缝固定分格。四张采用源图均经网页端精确 `alpha<=15` 清理和本地逐像素复验；本地没有清像素、抠图、遮罩、镜像或补画。
- 生产 manifest 为 `Liangshan-Heroes/assets/direction4/lianhuanma_p0_direction4_manifest.json`；来源、提示词、网页会话、判退稿和哈希见 `implementation_20260902/lianhuanma_p0_source/README.md`；运行证据入口为 `Liangshan-Heroes/qa/lianhuanma_p0_direction4_production_20260903/README.md`。
- Godot 4.6.3 导入20项；专属运行合约90项、连环马深度26项、全局美术160项、动作74项、通用方向回归、后四关自由路线26项和后关正常主线均通过。五张1280×720实机图覆盖五状态四方向并已人工检查。
- 当前严格四方向来源覆盖为 `72/347`；原58项已有30项完成合规替换、28项仍待处理；247项缺图或方向不全，最低剩余网页四行图集62。下一批处理普通官军、庄客和官吏，逐组核对原著后再决定重切或重画。
- 本批没有导出，没有修改 Steam 发布目录，没有上传或发布；已发布 Steam BuildID 仍以前文记录为准。真人完整试玩、战斗高峰和长期性能仍是独立门槛。

## 当前本地增量：2026-09-04 驻守战四向与死亡血迹

- 当前源码已晚于 Steam Windows default BuildID `25121101`：修复普通四向动作回退，并新增 `guan_musket` 四向待机；该30波敌军四向待机实例覆盖为709/778（91.131%）。其余动作与多数兵种仍不完整，不能称全四向完成。
- 火枪手原图经 Codex 内置浏览器生成和网页端精确Alpha清理；本地只做固定裁切、统一缩放、透明补边、导入与验证。来源和生产哈希见 `Liangshan-Heroes/assets/direction4/skirmish_p0_direction4_manifest.json`。
- 死亡残留已加入延迟显现、四向偏移、近距合并、兵种语义选择，并排除投石车和撞车的人形血迹。专项无头16/16、图形17/17、核心68/68；四向真实Vulkan夹具191项通过。
- 证据入口：`Liangshan-Heroes/qa/skirmish_direction4_20260904/README.md` 与 `Liangshan-Heroes/qa/skirmish_death_remains_20260904/README.md`。尚未真人完整30波、转向手感或兵海性能验收；尚未导出、写入Steamworks或上传。

## 当前本地增量：2026-09-05 四向首批复查修复

- 四种高频官军已有四向 walk/attack/death 首批；本轮再修 SW 弓手待机/迈步朝向、逐帧绘制对齐、骑兵枪术表现、致死闪红和死亡阴影，并缩小血迹与五类残骸。没有修改单位物理位置、战斗数值、存档结构或玩家命令。
- 新 SW 弓手通过内置浏览器生成，本地仅完整RGBA裁切、统一缩放和补透明边；4张条带变更，其余564张动画PNG未变。新来源记录为 `Liangshan-Heroes/assets/direction4/skirmish_archer_sw_revision_20260905.json`，不覆盖原来源链。
- 运行时绘制对齐表在 `scripts/skirmish_frame_alignment.gd`，由 Art 预加载，不需要把 QA/source manifest JSON 纳入导出。
- 证据与当前限制见 `Liangshan-Heroes/qa/skirmish_direction4_fix_20260905/README.md`。专属回归通过；旧宽阴影夹具仍有4项旧地图前提失败。当前严格状态覆盖109/347；不是全阵容、完整hurt或高帧率动画完成。
- 本轮只改本地源码，未导出、未写Steamworks目录、未上传。Steam玩家不会自动获得此增量。

## GitHub 同步约定：2026-09-05

- 用户要求以后每次开发完成，相关项目文件/文档与 GitHub 一起同步。长期收尾规则已写入根目录 `AGENTS.md`。
- 本日实查，水浒根目录与 `Liangshan-Heroes/` 都没有 Git 历史或远端关联。本文“来源和位置”中的 `winterzh/Liangshan-Heroes` 是下载上游，不能当作已确认的推送目标。
- 当前状态：相关本地项目文档已更新；GitHub 接入等待用户确认目标仓库地址。尚未初始化仓库、创建提交或推送，不能称远端已同步。
