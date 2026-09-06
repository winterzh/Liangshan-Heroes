# Steam 成就与创意工坊接入

2026-09-07 后续后台执行状态见[后台接续记录](STEAM_BACKEND_SETUP_20260907.md)：4项统计、30项中英文成就/10项阈值、工坊UGC/介绍/分类及Cloud文件额度已保存回读；60图标仍待正常文件访问/手工选择，测试分支命名prompt未完成，配置与ZIP尚未发布。用户已确认后台发布、测试分支上传与联调，授权继续有效。新候选固定df7ed18、ZIP SHA256为`768d1c15dedfd0cd19f89bb3528028171f2abf0115d3ca51a244e90e8f3b44d5`，见[新QA](../qa/steam_backend_20260907/README.md)；下文保留首轮源码接入及原候选的历史记录。

2026-09-07。App ID `5088120`。本轮实现 Windows 源码及隔离候选包；线上配置、双账号联调和 Steam 上传/发布分开验收。当前线上游戏状态仍见 [最近发布记录](STEAM_UPDATE_20260907.md)，不能把本页的本地功能当作已上线。

## 玩家入口与计入规则

主菜单「更多」新增「成就 · 30 项」「创意工坊 · 订阅关卡」。两种编辑器增加「发布／更新创意工坊」和「另存本地副本」。工坊页可保存两种创作示例，存为独立副本，避免覆盖已有作品。

| 成就类别 | 数量 | 条件 |
|---|---:|---|
| 八幕通关 | 8 | 每个官方战役获胜 |
| 八幕演义印 | 8 | 同一局完成当前关全部原著目标并获胜 |
| 八幕功成、忠义全书 | 2 | 集齐全部通关、全部演义印 |
| 固定据守档位 | 2 | 完成官方 30 波、60 波 |
| 官方累计胜利 | 3 | 10 / 50 / 100 胜 |
| 官方累计歼敌 | 3 | 1,000 / 10,000 / 100,000 |
| 固定据守累计胜利 | 2 | 10 / 50 胜 |
| AI 对战累计胜利 | 2 | 1 / 10 胜 |

官方战役、固定据守 20/30/60 波和正式 AI 对战计入累计量；内置倍率和自动指挥允许。自定义、编辑器、创意工坊、竞技场、随机据守及自动化 QA 均不计入。击杀沿用真实战斗中敌方非建筑死亡事件；胜利仅结算一次，失败不增胜场。

`SteamRunPolicy` 同时检查开局模式标志与实际生产关卡脚本；Battle 冻结开局上下文。内容自报 `id=level1` 不会产生官方演义任务或污染 Campaign 存档。普通版本未加载 Steam 时，官方战役本地记录仍正常保存。

旧存档只迁移带有完整 `cleared/story_complete/contract_version/story_total/best_done/best_goal_ids`、且目标集合符合当前关卡合同的印记，同时补对应通关；不从旧通关标记推算胜场或歼敌。首次迁移绑定一个 Steam 账号，其他账号不重复领取。原玩家文件不改写；额外关联存于 `user://steam_legacy_import.cfg`。

## 实现边界

`SteamService` 用动态 singleton 调用 GodotSteam，仅在带 `steam` 导出特性的 Windows 包启用。回调在暂停期间继续处理。启动读取 Steam 缓存及后台条目，只有全部配置就绪才接受新局；击杀和结算立即写入 SDK 缓存，StoreStats 失败保留待存状态并重试，异步保存期间产生的新进度不会被旧确认清除。每次写入核对账号；账号改变后停止计入，需重启。未连接或后台未配置时，界面显示具体状态。

`SteamAchievementCatalog` 是唯一成就定义来源，导出 [后台清单](../tools/contracts/steam/steamworks_catalog.json)。60 张生产 PNG 来自 [确定性矢量生成器](../tools/steam_catalog_export.gd)，SVG 原文在 `tools/contracts/steam/icons/`，成品位于 `assets/ui/achievements/`。

GodotSteam 固定 `4.22.1 GDExtension`、Steamworks `1.65`，使用 Godot `4.6.3`；原始依赖包 SHA-256 为 `2b12b3499434c50da16104a0d22b725aee15cc5cd41223c1cea825bae59bfa8f`。DLL、许可证和逐文件来源在 `vendor/godotsteam/`。该目录用 `.gdignore` 隔离；普通源工程不装载原生 Steam 扩展，Steam 构建助手只在隔离工程安装 Windows x86_64 文件。macOS/Android 的原有启动代码无静态 Steam 类型依赖；本轮没有导出这两个平台。

## 工坊格式与发布流程

支持现有场景地图和自定义据守数值/波次。仅允许游戏内单位、技能和美术，禁止脚本、PCK、DLL、任意资源路径及未知数据字段。验证同时发生在上传前和订阅游玩前；不执行下载包中的代码。

作品内容目录固定为 `manifest.json`、`content.json`、`preview.jpg`，不接受其他文件/子目录。manifest 为 `{"format_version":1,"kind":"scenario"}` 或 `custom_defense`。JSON 限 2 MiB、地图 24–96 格，并限制深度、对象数量、生成兵力、坐标、属性类型、数值和引用。封面上传时缩为 512×288 JPEG，小于 1 MB。完整校验规则见 `scripts/workshop_content.gd`。

编辑器本地 JSON 使用明确的颜色编码；读取时恢复已知 Color 字段，同时兼容旧 `(r, g, b, a)` 四数值字符串。未知/无效字符串不会被解释为代码。普通自定义存档依然使用原目录和名称。

初次上传先保存稳定来源 ID，再调用 CreateItem；收到作品 ID 后，先保存账号/来源/作品关联，最后上传内容。失败后更新同一 ID，重复点击不会创建第二份。另存副本生成新的来源身份。上传默认私有，表单可选择好友或公开可见，提供创意工坊协议链接和首次接受提示。

订阅列表通过 Steam 的下载/安装状态读取；更新期间禁用游玩。开始游玩时再次校验，并将内容复制为当前局的自定义数据。取消订阅只交给 Steam 处理，保留编辑器本地作品。

本地辅助目录为 `user://workshop_uploads/`，作品关联为 `user://workshop_publications.cfg`；两者属于玩家数据，不能提交 Git 或作为游戏包内容。

## 复现与候选导出

使用 Python 3、Git、Godot 4.6.3 官方 Windows x86_64 release 模板。Godot 路径从 `--godot`、`GODOT_PATH` 或被忽略的 `godot.local.txt` 读取，不在公共脚本写死。运行前取得共用引擎锁，其他任务和实际游戏须已退出。

```powershell
python -X utf8 -B tools/run_steam_integration_qa.py
python -X utf8 -B tools/run_steam_integration_qa.py --run --native --visual
python -X utf8 -B tools/build_steam_candidate.py --qa-run .godot/steam_integration_qa/本次成功目录
python -X utf8 -B tools/build_steam_candidate.py --run --qa-run .godot/steam_integration_qa/本次成功目录
```

每次创建全新私有 project/profile、APPDATA/LOCALAPPDATA/TEMP/TMP，强制 `STEAM_DISABLED=1`；自动测试不连接真实账号。`--cache-from` 仅接受此前隔离 QA 目录，复用导入纹理以减少等待。收据核对受测源码前后 SHA；源码改变后不能用旧 QA 收据导出。

新增的 `Windows Steam` 导出预设必须由构建助手在隔离工程使用，不能直接在普通源目录点击导出后宣称已含 Steam DLL。候选只复制明确运行目录，排除 tools/qa/docs/marketing/vendor 原始目录及来源草稿，再安装核对哈希的原生依赖。导出后挂载实际 EXE 内嵌 PCK，核验 `steam` 特性、singleton、60 张图标、官方脚本身份和无开发文件，并执行 EXE 短启动。成品和缓存留在 `.godot/steam_candidates/`，不进入 Git。

这些检查证明接入代码及包结构，不代替 Steam 服务器收据、真人通关或现有商业美术/性能验收；没有放宽 `tools/build_release_candidate_staging.py` 的完整发布门槛。

## Steamworks 后台待执行清单

后台操作须在 App `5088120` 逐项核对，先准备测试分支，暂不激活 default。

1. 创建四项 INT stats：`TOTAL_WINS`、`TOTAL_KILLS`、`DEFENSE_WINS`、`AI_WINS`；默认 0，最小 0，最大 2147483647，客户端可设置、仅递增、不聚合为 global stat。创建 30 项 achievements，API Name 必须逐字匹配 JSON，使用中英文名称/说明和对应两套图标。累计类可关联同名 stat 及目标；游戏本身按同一阈值 SetAchievement。后台更改需发布后客户端才能读取，见 [Valve 成就文档](https://partner.steamgames.com/doc/features/achievements)。
2. 工坊启用 ISteamUGC file transfer，并配置预览图所需 Steam Cloud 配额（本项目建议 100 MiB、1000 文件/用户）。不配置玩家存档 Auto-Cloud 规则。工坊初期设 Developers & Testers，标签 `Map`、`Defense`；按 Valve 流程保存并发布配置。预览配额和工坊启用关系见 [Valve 工坊实施文档](https://partner.steamgames.com/doc/features/workshop/implementation#Enabling_ISteamUGC_for_a_Game_or_Application)。
3. 上传已核验候选到独立测试分支；必须包含 EXE 和两个原生 DLL。保持 EXE 名 `LiangshanHeroes.exe`。不附带 `steam_appid.txt`、开发 profile、上传缓存或本地作品关联。
4. 两个真实测试账号依次验收下表。工坊向 Everyone 开放前补齐品牌图、标题、说明和至少一个公开作品；当前示例由游戏内按钮生成，尚未上传。

| 实机验收 | 通过证据 |
|---|---|
| Steam 初始化与 Overlay | 从 Steam 测试分支启动，App/账号正确，Overlay 可开 |
| 30 项后台对应 | 逐项真实条件/受控测试账号验证、Steam UI 及服务端回读；不得污染玩家账号 |
| 持久化 | 退出重开、离线再联网、StoreStats 失败重试、另一台机器读取同账号 |
| 旧档补领 | 合法印记只补对应章；旧通关无印记不补；第二账号不重复迁移 |
| 工坊场景与据守 | 账号 A 发布各一份，账号 B 订阅、下载、进入实际战斗 |
| 更新与隔离 | A 修改后更新同 ID，B 重载取得新版；局内数据不被下载更新替换 |
| 异常与协议 | 首次协议、断网上传重试、缺包/坏 JSON/未知版本、取消订阅保留本地作品 |
| 公共开放 | 配置发布收据、测试分支 BuildID、两个作品 ID 与双方实机收据齐全后再决定正式发布 |

## 本轮验证收据

最终生产逻辑 176 项通过，普通版本及六张实际界面已检查；实际成品 65 项 PCK 合同全部通过，release EXE 正常退出并回读到两个正确发行 DLL。详见 [本轮 QA](../qa/steam_integration_20260907/README.md)。失败轮、原生检查、普通界面、最终复验及候选导出分开存放，不合并成“线上已通过”。

已核验候选 ZIP 位于 `.godot/steam_candidates/20260907_021833_17f08803/LiangshanHeroes_Steam_candidate.zip`，219,686,365字节，SHA-256 `7c7050736d2303e22b9a6c485193e81d46ebdd6470265cdbadde2851c640da56`。ZIP 只包含 EXE、两个发行 DLL 和 GodotSteam 许可证；逐项解压哈希见 [交付清单](../qa/steam_integration_20260907/delivery_manifest.json)。`build_steam_candidate.py` 在验证完成后生成同样范围的新 ZIP。尚未上传或发布。
