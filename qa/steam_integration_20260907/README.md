# Steam 成就与工坊接入 QA

本轮检查对应 App5088120、Godot4.6.3、GodotSteam4.22.1/Steamworks1.65。所有自动执行使用隔离工程和全新用户目录，`STEAM_DISABLED=1`，不初始化真实 Steam 账号。

## 已完成的检查

| 目录 | 结果与范围 |
|---|---|
| `native_170/` | 170 项通过：目录/阈值/重复结算/旧档严格补领/工坊数据校验/模拟 SDK/真实自定义 Battle 排除官方记录/原生方法与信号 |
| `portable_visual_157/` | 无原生依赖的普通版 157 项通过，含六张实际窗口截图 |
| `final_native_176/` | 最终生产逻辑 176 项全部通过；增加编辑器保存再读取、颜色类型和旧字符串兼容 |
| `visual/`、`visual_review.json` | 六张 1280×720 实际 Godot 画面：更多、成就、工坊、场景编辑器、据守编辑器、发布表单。目检布局与文字/图标，不是完整真人试玩 |
| `artifact_review.json` | 30 定义、4 stats、60 张 PNG；全部 256×256，逐字节匹配最终 Godot 矢量生成结果 |
| `final_package/` | 65/65 PCK 断言通过；实际 release EXE PID9976 正常退出，回读两个发行 DLL 的实际路径和 SHA，程序前后哈希相同 |
| `delivery_manifest.json` | ZIP 逐项解压哈希核对；只含 EXE、两份发行 DLL 与 GodotSteam 许可证 |
| `staged_source_review.json` | 21 份受测/待提交脚本一致；16 份 raw 字节相同，5 份仅原有 Git CRLF/LF 规范化，分别保留两套 SHA |

这些计数包含辅助断言，不相加当作独立游戏功能数。模拟 SDK 检查不会产生 Steam 服务端解锁、订阅或上传收据。

## 保留的失败轮

- `first_import_failure/`：最初的 Variant 推断解析错误；修正类型声明后重跑。
- `first_behavior_failure/`：151 条中默认据守校验失败，日志另记录测试脚本在 Autoload 之前编译及空剧情越界。改为延迟加载测试、明确 Color 编码并保护空 intro；失败原文保留。
- `color_fixture_failure/`：182 条中一条夹具错误，误把技能专属 color 放到单位字段。改用真实 `song_rally.color` 后最终 176 项通过；这一轮六张画面来自相同最终生产界面。
- `export_host_failure/`：Windows 导入/导出退出0；直接用外部编辑器挂载发行 PCK 时，宿主找不到其所选原生库。64/65 包断言通过，原生 singleton 不通过。保留完整日志、报告和原构建助手。
- `release_script_failure/`：发行模板不支持 extended 的 `--script`，尝试会进入游戏菜单而不执行探针；本任务精确 PID 在120.88秒结束。不是游戏启动崩溃。依据 [Godot4.6命令行文档](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html)，改用带原生依赖的隔离编辑器执行包探针，另在实际发行 EXE 中回读 DLL 模块。原失败未改成通过。

## 复现方式

根目录 `tools/run_steam_integration_qa.py` 默认只预检，`--run --native --visual` 创建新的私有运行；源文件前后 SHA、真实日志与退出码写入收据。`--cache-from` 仅复用此前私有导入纹理，不复制玩家数据。

`tools/build_steam_candidate.py --run --qa-run <成功目录>` 从已通过 QA 的同一批工作区字节冻结运行白名单，安装哈希匹配的 native 文件并导出 `Windows Steam`。`tools/steam_candidate_verification.py` 在独立 editor 宿主旁放验证依赖，挂载实际 EXE 的 PCK；实际 release EXE 用 `--max-fps 60 --quit-after 600` 短启动，并从精确 PID 的 Modules 回读两个 DLL 的路径/哈希。该宿主和附加调试库不进入交付目录。

本轮既有 EXE 用 `reverify_export.py --candidate <本次候选目录>` 复验，无需重新导出。该助手核对先前导入/导出成功、生产源码和依赖、EXE 前后哈希；所有新收据创建新目录，旧失败不覆盖。

本轮最终成品位于 `.godot/steam_candidates/20260907_021833_17f08803/`。EXE 为287,461,120字节，SHA-256 `c8ffc5b718388a68f9887081d98ad4c18339df4566bd1ec9241979b3c4d6c99c`。原导出收据仍保留宿主验证失败；最终通过应联合读取 `export_host_failure/receipt.json` 的成功导入/导出与 `final_package/receipt.json` 的成功验证，不能只看旧顶层 `complete=false`，也不能改写它。候选 ZIP 为内部测试分支准备，尚未上传。

本 QA 根只归档脚本、收据、日志、清单及相关界面 PNG，不归档私有 project/profile、真实存档、Godot 缓存、程序或候选安装包。生产依赖及艺术来源分别在 `vendor/godotsteam/`、`tools/contracts/steam/`，不要从归档目录启动 Godot 工程。

## 线上边界

未执行 Steamworks 配置发布、Steam 包上传、30 个成就真实服务端回读、断网重连、跨机读取或两账号工坊往返。进入这些步骤前，按 [接入说明](../../docs/STEAM_INTEGRATION_20260907.md)准备账号和测试分支。本轮不激活 default，不改变当前正式 Steam Build，不替代真人全战役、长时性能或商业美术门槛。
