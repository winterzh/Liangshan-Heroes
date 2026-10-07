# 普通源工程与原生 QA 依赖范围更正建议

正常源工程开发只需本机 Godot 4.6.3 与项目资源导入。没有 vendor 或没有编译 reader，本身不会必然阻断普通 `tools/run_local.ps1 -Mode import` / play。SteamService 在无 steam 特性或测试环境下提前返回；普通源工程不安装原生扩展，vendor 被 `.gdignore` 隔离。这里是源码合同核对，不是新电脑已启动通过的声明。

建议将 OFFICE_START 第2节标题改为“原生续玩 QA 的依赖准备（普通开发无需先执行）”，首句写：“先正常导入和开发即可。只有开始重新建立原生续玩 QA 基线时，才需要下面的 vendor/reader 依赖及完整来源核验。”

`tools/setup_steam_dependency.py` 仅下载并验证固定 GodotSteam 包，写 vendor/provenance，不会自动把扩展安装到普通 Root。reader 的构建/smoke/promotion 也属于原生 QA 准备。真正安装 native 的 `tools.run_steam_integration_qa.install_native(project)` 由 QA producer 对隔离工程调用：复制 DLL 到其 addons，并在首次 import 前注册 extension_list；不把这一步当普通源码启动前置。

原第2节两个只读命令可以保留，但注明：第一条（无 --run）核对 source/Godot/lock，第二条 native_dependencies 核对 vendor 文件和 manifest/SHA；缺依赖只阻断原生 QA，不要求用户先编 reader 才能正常开发。普通开发导入成功不代表 native restore/Steam统计或奖励已通过。

原 R1 草稿、审查和执行工具保持原样；本更正供 Root 纳入新最终交接。本次没有执行 import/play、下载、编译、promotion 或引擎。
