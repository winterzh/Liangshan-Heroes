# Steam Windows 跨设备测试构建上线记录（2026-09-04）

## 当前结论

- AppID `5088120` 的 Windows `default` 已切换到 BuildID `25121101`；Depot `5088121` manifest 为 `6833015574013725084`。
- 本轮只更新 Windows 64 位测试构建，没有处理 macOS，没有点击 `Release App`，没有修改价格、折扣、发行日期、商店素材、语言、评级或 AI 披露，也没有发布新公告。
- Steam 内容根目录只有 `LiangshanHeroes.exe`。成品大小为 `287,328,240` 字节，文件/产品版本均为 `1.8.0.0`，SHA-256 为 `2F0C5786B368BD9F2C4A56893F1AB5872511B72DCB84BC96D667C3075F4295F6`。
- Steamworks Builds 页与上线历史均显示 `25121101` 为 `default`。用户协助完成网页确认后，页面已重新读取核对；`macos` 仍为 BuildID `0`。
- SteamCMD 从服务器隔离回下载 `default` 后，appmanifest 显示 `StateFlags=4`、`buildid=TargetBuildID=25121101`、manifest `6833015574013725084`。服务器 EXE 与上传包大小及 SHA-256 完全一致，主菜单独立启动退出码为 `0`，日志错误数为 `0`。
- 本机 Steam 客户端随后已自动刷新：本地 appmanifest 为 `StateFlags=4`、`buildid=TargetBuildID=25121101`、manifest `6833015574013725084`，库内 EXE 的大小和 SHA-256 与上传包、服务器回下载包完全一致。通过 `steam.exe -applaunch 5088120` 启动后，实际进程路径为 Steam 库内 `LiangshanHeroes.exe`，窗口标题为“水浒英雄传：八幕战役”；启动日志只有 Godot/Vulkan 设备信息，脚本、解析、资源加载与崩溃匹配均为 `0`。验证后只关闭了本次新启动的游戏进程。

## 包与路径

- 上传内容根：`D:\SteamBuilds\Liangshan_5088120\20260904_174724\`
- 上传 EXE：`D:\SteamBuilds\Liangshan_5088120\20260904_174724\windows\LiangshanHeroes.exe`
- 导出成品 QA：`D:\水浒测试构建\steam_test_20260904_174724\`
- Steam 服务器回读：`D:\SteamBuilds\Liangshan_5088120\server_verify_25121101\`
- 构建收据：`qa/steam_test_build_20260904/BUILD_25121101_RECEIPT.json`
- SteamPipe VDF：`qa/steam_test_build_20260904/app_build_5088120_20260904_test_preview.vdf` 与 `app_build_5088120_20260904_test.vdf`

## 上线前验证

- Godot 编辑器导入/解析：退出码 `0`。
- 梁山驻守地图契约：`36/36`，`passed=true`。
- 导出包逐关烟测：`LEVEL=1..8` 共 `8/8` 退出码 `0`；每关都有 `[smoke]`，脚本、解析、资源加载错误均为 `0`。
- 导出包驻守硬伤专项：`9/9`，`ALL=true`。
- 导出包末波清理专项：`12/12`，`ALL=true`。
- 无测试环境变量的导出包主菜单启动：退出码 `0`，日志错误数 `0`。
- 真实 Vulkan 1280×720 的寨门、战争迷雾、资源林与七机位图形检查已在 `qa/skirmish_gate_tree_fix_20260904/` 留证。

这些验证证明包可启动、八关可进入、当前驻守硬伤契约通过，不等于真人 30 波手动通关、30 分钟长时稳定性、平衡、趣味或正式发行候选验收。

## SteamPipe 与分支结果

1. Preview 成功，映射仅一份 `LiangshanHeroes.exe`，基于旧 manifest `3869331897414099550` 计算差异。
2. 正式上传成功，生成 BuildID `25121101` 与 manifest `6833015574013725084`。
3. 用户在 Steamworks 网页完成确认后，`default` 指向 `25121101`；后台历史也记录该切换。
4. 随后通过 SteamCMD 从远端 `default` 隔离回下载并核对 appmanifest、文件大小、SHA-256 与启动。
5. 本机 Steam 客户端自动刷新到 `25121101` 后，从 Steam“开始游戏”同一路径启动新包并核对进程路径、窗口标题和启动日志。

并行兜底流程曾产生一个未分配的重复构建 BuildID `25121260`、manifest `24026002792202072`；应用提交结果为 `Failure`，它没有被设为 `default`，不影响玩家获取的 `25121101`。该记录保留用于审计，不再重试或切换。

## 发布边界

这是给各台电脑直接从 Steam“开始游戏”测试的 Windows 构建，不是正式发行。公开商店仍处于预发布边界；本轮没有执行 `Release App`。正式发行仍需另行实时核对 Steamworks 发布控制、发布门禁和真人验证，不能由本次 BuildID 切换自动推导。
