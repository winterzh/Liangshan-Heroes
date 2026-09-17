# 公司 Steam 候选与上传记录（2026-09-07）

## 构建前工具验证

两份 Steam QA/构建助手新增可选 `--profile-root`，用于 Windows 较短的私有测试用户路径。未指定时保持原有每轮 `profile` 目录。只在指定绝对根内独占新建当轮子目录，拒绝复用、文件型父目录、符号链接和 Windows reparse；仍保留源码、真实玩家文件、DLL、PCK 身份、进程退出和锁保护。

[10 项静态与路径检查](profile_option_checks.json) 全部通过，独立只读审阅通过；此阶段未启动引擎。公司首轮 shader cache 路径过长的实际失败保留在相邻公司交接 QA，未改写为通过。

## 本轮候选与 Steam 实际状态

本轮基于已提交源码 `d4728d413ee5ec2df27e132ab4297cf096da363b`，重新冻结、运行原生 QA 并导出 Windows Steam 候选。该包已上传为 **Build 25160280**，Windows Depot **5088121**、Manifest **399339942090359717**；Steamworks 回读 `steam-integration` 分支为 **25160280**，`default` 仍为 **25154403**。

[服务端收据](steam_server_receipt.json)记录协调任务在 Steamworks 构建、清单与分支页面的实际回读。服务端四个文件的名称、大小和 SHA1 均与本地唯一候选一致，总计 **291,960,918 字节**，服务端压缩后 **216,801,072 字节**。这些数值对应 Depot 文件内容；上传 ZIP 的容器大小不同。

唯一上传包相对 checkout 路径为 `.godot/steam_candidates/20260907_105018_639b47fb/LiangshanHeroes_Steam_candidate.zip`，**221,072,864 字节**，SHA256 为 `a2ad089583e332e9149f59ba91d197b756fc117ad2a8bbb36a94a8a13f73740f`。ZIP 只有 EXE、两枚 DLL 与 GodotSteam 许可证；已重新读取 ZIP 的 CRC、成员集合和逐项 SHA256。各文件完整 SHA1/SHA256 见 [candidate_delivery.json](candidate_delivery.json)。本归档不存放安装包或 DLL。

| 验证范围 | 本轮实际结果 |
| --- | --- |
| 原生隔离 QA | **182 项**，即 176 项行为合同及 6 项截图保存检查；import/catalog/contracts 全部 exit 0。冻结 2,877 项输入。 |
| 六张实际界面 | 成就、更多、工坊订阅、发布表单、场景编辑器、驻守编辑器均已逐张打开观察；记录在 [visual/](visual/)。这些是隔离工程原生截图。 |
| 导出与实际 PCK | 白名单 2,640 项；import/export 全部 exit 0，实际包内 **65 项**合同通过。PCK 清单包含 Fog、玩法 RNG、内容身份和生成的构建身份模块。 |
| 实际发行 EXE | PID **41580**，**12.55 秒**后正常 exit 0；回读到候选目录内的两枚正确 release DLL，逐项 SHA256 匹配固定依赖。 |
| source 身份 | PID **3060**，**10 项**通过，`source_mode=true`，进程退出已确认。 |
| PCK 身份 | PID **38232**，**10 项**通过，`source_mode=false`，使用实际发行 EXE 的绝对 `--main-pack` 路径，进程退出已确认。 |
| 外层保护 | QA 和构建各自的源码、工具、真实玩家目录前后一致；本轮内外层 receipt 均 `complete=true`，进程退出、共同锁释放，结束时 Git 工作区干净。 |

正式 QA 与构建本轮没有失败。构建前补齐本机 Godot 4.6.3 Windows release 模板，SHA256 为 `91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6`；实际非 console 引擎 SHA256 为 `ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00`。短路径参数解决的早先公司 shader cache 错误仍保留于相邻交接 QA，本页没有重写那些失败。

## 原件、脱敏与复验

- [native_qa/](native_qa/)保存本轮行为收据、报告、日志和生成的 Steamworks 目录数据；原件来自 `.godot/steam_integration_qa/20260907_104852_8c05fdb9/`。
- [export/](export/)保存本轮构建、PCK、实际 EXE、双身份 probe 及来源清单；原件来自 `.godot/steam_candidates/20260907_105018_639b47fb/`。
- [guards/](guards/)保存两个阶段的外层守护结果及来源前后清单。真实玩家的具体路径、文件名和内容均不入库，只保留原始证据摘要哈希、数量与前后相等结果。
- [source_mapping.json](source_mapping.json)逐项记录原始相对位置、原字节 SHA256/尺寸、归档 SHA256/尺寸以及是否进行本机路径替换。无需脱敏的引擎日志和六张 PNG 保持原字节；带路径的收据、身份日志等仅替换为占位符。收据内部的哈希仍指向原始运行对象，不能拿脱敏副本的 SHA 代替原 SHA。
- [archive_manifest.json](archive_manifest.json)覆盖本目录除清单自身外的所有交付文件。清单自身的 SHA 另在本轮交接回复提供，避免自引用。

复验须在同一源码和固定依赖下新建运行目录，使用 Godot 4.6.3、空闲引擎槽及共同 `.godot/redraw_rejection_source.lock`。两个正式入口均提供 `--profile-root <新的绝对短目录父级>`；QA 使用 `--run --native --visual`，构建使用 `--run --qa-run <本轮新成功QA目录>`。本轮 `--cache-from` 仅引用明确标记为 `company_cache_only_20260907` 的纹理缓存种子，没有复用旧通过收据。外层包装器以脱敏文本保存在 [support/run_guarded.py.txt](support/run_guarded.py.txt)，须在新的忽略目录恢复为脚本并设置本机路径后再运行，不直接执行归档文本或复用旧用户目录。

本轮全部自动检查均禁用真实 Steam 初始化。上传至测试分支不等于完成真实账号成就解锁、工坊发布/订阅/下载或双账号联调；此处没有修改 `default`。完整 RunSession、保存退出/继续本局、完整效果视觉、退出重启整局对照、正式性能与真人试玩门槛仍开放。
