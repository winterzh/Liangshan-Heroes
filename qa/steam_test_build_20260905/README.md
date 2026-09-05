# 2026-09-05 Steam Windows 测试构建证据

当前上传 BuildID `25136463`，manifest `7280684617482783161`；全部本地成品短测已通过。default 原生网页确认需要用户完成，SteamCMD 最后刷新仍为 `25121101`，新 default 回下载尚未执行。

- `build_test_snapshot.py` / `test_snapshot.json`：独立测试快照、2364 文件及完整哈希。不是正式发行门禁放行。
- `test_snapshot_verified.json`：源码与快照导出后再次逐文件校验。
- `snapshot_import.log`、`export_with_templates.log`：成功导入和导出日志；`export.log` 保留首次默认模板路径缺失的失败证据。
- `run_package_smoke.py` / `package_smoke.json`：实际单文件 EXE 的 11 案自动短测及命令/环境覆盖；8 关、驻守硬伤、末波清理、主菜单均通过。
- `app_build_5088120_test_preview.vdf` / `app_build_5088120_test.vdf`：本次唯一预览与上传配置，不含自动 SetLive。
- `steam_preview_*`：预览只含一份 EXE。
- `steam_upload_app.log` / `steam_upload_depot.log`：Steam 返回的新 BuildID 与 manifest。
- `package_direction_contract.gd` / `package_direction_contract.json` / `package_direction_contract_clean.log`：同版本引擎挂载成品内嵌 PCK 的 90 项契约，64 资源、48 动作单元全部通过；不是发行 EXE 执行外部脚本。
- `package_visual_capture.gd` / `visual/`：成品 PCK 的主菜单、驻守战两张 1280×720 Vulkan 截图与机器报告。主代理已目检；首轮长 APPDATA 的缓存失败证据保留，短路径重跑无错误。
- `verify_server_download.py`：用户确认 default 之后的隔离服务器回下载检查入口，目前未运行。
- `github_sync_push_receipt_20260905.json`：代码/美术增量提交 `863fcf0` 已回读确认，main 未改。

GitHub 副本不保留本机绝对路径。运行 `run_package_smoke.py` 前设置 `LIANGSHAN_TEST_EXE`，可选设置 `LIANGSHAN_TEST_DATA`；运行 `verify_server_download.py` 前设置 `LIANGSHAN_SERVER_DOWNLOAD`、`LIANGSHAN_UPLOAD_EXE`，可选设置 `LIANGSHAN_SERVER_TEST_DATA`。报告中的 `<...>` 为公开副本路径占位符，不改变测试结果、构建哈希或 Steam 状态。

机器测试、固定机位人工目检、真人连续游玩必须分别记录。尚无真人 30 波或长时性能结论。完整状态以 `docs/STEAM_TEST_BUILD_20260905.md` 和最终构建收据为准。
