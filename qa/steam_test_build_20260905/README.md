# 2026-09-05 Steam Windows 测试构建证据

当前 public/default BuildID `25136463`，manifest `7280684617482783161`；全部本地成品短测已通过。用户确认后，SteamCMD 强制更新应用信息已回读 `25136463`，`timeupdated=1788581012`。新 default 隔离回下载、哈希和独立主菜单启动复核均已通过；本机 Steam 客户端检查仍为旧 `25121101`，需要客户端下载更新，不是服务端阻塞，本机新包启动未计为通过。

- `build_test_snapshot.py` / `test_snapshot.json`：独立测试快照、2364 文件及完整哈希。不是正式发行门禁放行。
- `test_snapshot_verified.json`：源码与快照导出后再次逐文件校验。
- `snapshot_import.log`、`export_with_templates.log`：成功导入和导出日志；`export.log` 保留首次默认模板路径缺失的失败证据。
- `run_package_smoke.py` / `package_smoke.json`：实际单文件 EXE 的 11 案自动短测及命令/环境覆盖；8 关、驻守硬伤、末波清理、主菜单均通过。
- `app_build_5088120_test_preview.vdf` / `app_build_5088120_test.vdf`：本次唯一预览与上传配置，不含自动 SetLive。
- `steam_preview_*`：预览只含一份 EXE。
- `steam_upload_app.log` / `steam_upload_depot.log`：Steam 返回的新 BuildID 与 manifest。
- `package_direction_contract.gd` / `package_direction_contract.json` / `package_direction_contract_clean.log`：同版本引擎挂载成品内嵌 PCK 的 90 项契约，64 资源、48 动作单元全部通过；不是发行 EXE 执行外部脚本。
- `package_visual_capture.gd` / `visual/`：成品 PCK 的主菜单、驻守战两张 1280×720 Vulkan 截图与机器报告。主代理已目检；首轮长 APPDATA 的缓存失败证据保留，短路径重跑无错误。
- `verify_server_download.py` / `server_download_verified.json`：default 隔离回下载复核已通过；`StateFlags=4`、`UpdateResult=0`、`buildid=TargetBuildID=25136463`，manifest 与 EXE 大小/哈希一致，独立 release EXE 无界面主菜单退出 0、错误 0。与本机 Steam 客户端状态分开记录。
- `github_sync_push_receipt_20260905.json`：代码/美术增量提交 `863fcf0` 已回读确认，main 未改。

机器测试、固定机位人工目检、真人连续游玩必须分别记录。尚无真人 30 波或长时性能结论。完整状态以 `docs/STEAM_TEST_BUILD_20260905.md` 和最终构建收据为准。

本机客户端补查：通过正常 `steam.exe -applaunch 5088120` 短启动后，仍为 `buildid=TargetBuildID=25121101`、旧包 SHA-256 `2F0C5786B368BD9F2C4A56893F1AB5872511B72DCB84BC96D667C3075F4295F6`；日志错误 0 不计为新包通过。游戏已自动退出，未重启/关闭 Steam 或覆盖安装文件。服务端交付已完成，客户端须刷新并下载更新。
