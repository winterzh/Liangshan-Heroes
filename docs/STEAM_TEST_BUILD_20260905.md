# Steam Windows 四向与阵亡表现测试更新（2026-09-05）

## 范围与当前状态

用户授权上传当前版本并写更新说明；目标为 AppID `5088120` 的 Windows `default` 跨设备测试，不执行 Release App、不改 macOS 或外部更新器。

- SteamPipe 上传成功：BuildID `25136463`，Depot `5088121`，manifest `7280684617482783161`。
- 分支切换尚未完成：Steamworks 预览已确认从 `25121101` 切到 `25136463`、仅更新 Windows Depot；内部更新注释已填写。点击上线按钮后出现浏览器原生确认框，自动控制连接失效，已请用户手动确认。随后 SteamCMD 强制刷新应用信息仍读到 public/default `25121101`，因此当前不能说玩家已获得新包，也未执行新包的 default 回下载。
- 成品：`<steam_build>/windows/LiangshanHeroes.exe`。
- 版本 `1.8.0.0`；大小 `278,050,128` 字节；SHA-256 `B333E117755C0A33FBBC5731FD3768514A68FCE21C5E45DC730F38DD138BBFC1`。
- 更新说明：`STEAM_TEST_UPDATE_20260905.txt` 与 `STEAM_TEST_UPDATE_20260905_ENGLISH.txt`；尚未发布新社区公告。

## 内容

四类高频官军的四向行走、攻击与倒地首批，弓手西南方向修订，绘制脚点对齐、骑兵枪术表现、死亡受击闪色和阴影收尾，以及血迹/装备残留缩放和延迟淡入。本批不改战斗数值、玩家命令、存档、波次和平衡。

## 构建与验证

冻结快照：`<frozen_project_snapshot>`，共 `2364` 个允许的输入文件，树 SHA-256 为 `5237d3734b478c3f364932b2c97088e4f35958cc15482f4026fe9c89894a7092`。导出后再次对源码/快照逐文件校验通过。

通用正式发布白名单尚未列入的 26 张现用 UI 图及导入描述，已在本次独立测试快照中明确纳入；33 个实际尚未生产的环境备选槽沿用既有回退，未伪造资源。没有降低或修改正式发布门禁。

- 冻结工程编辑器导入：退出码 0，无脚本或资源错误。
- Windows 导出：退出码 0，无错误。首次尝试因 C 盘默认位置无导出模板失败；随后为导出子进程使用 D 盘已安装的同版本模板，未下载或修改生产导出配置。
- 实际 EXE 八关启动烟测：8/8，每关均进入对应关卡，无脚本/解析/资源错误。
- 实际 EXE 驻守硬伤自检：9/9，`ALL=true`。
- 实际 EXE 最终波清理自检：12/12，`ALL=true`。
- 实际 EXE 主菜单启动：退出码 0，无错误。
- 同版本 Godot 以 `--main-pack <EXE>` 读取成品内嵌 PCK：四向/阵亡契约 90/90、资源 64/64、动作单元 48/48，最终日志无错误或告警。发行 EXE 的 `--help` 不提供 `--script`，最初用 EXE 执行外部脚本的尝试不计为通过；仅本次 QA 进程被关闭，没有关闭玩家游戏。
- 同一成品 PCK 的 1280×720 Vulkan 主菜单/驻守战截图 2/2，主代理已打开图片目检。首次使用过长隔离 APPDATA 导致 FSR2 shader cache 创建失败，改用子进程短路径 `<isolated_appdata>` 后重跑日志无错误；未修改系统或生产配置。画面角落短时 FPS 标签不作为性能数据。
- Steam Preview：只映射一份 EXE；分支变更预览显示旧包到新包更新下载约 37.9 MB。

## 证据与复现

证据目录：`qa/steam_test_build_20260905/`。

```powershell
py -3 -X utf8 -B qa/steam_test_build_20260905/build_test_snapshot.py verify
py -3 -X utf8 -B qa/steam_test_build_20260905/run_package_smoke.py
```

导出命令记录在 `export_with_templates.log` 对应过程：Godot 4.6.3，`--headless --path <冻结工程> --export-release "Windows Desktop" <成品EXE>`；导出子进程 APPDATA 为 `<godot_export_userdata>`。每个烟测子进程的 APPDATA 单独隔离，不接触玩家存档。

SteamPipe 实际上传脚本是同目录 `app_build_5088120_test.vdf`，没有 SetLive；不得重跑历史 wrapper，也不得选此前失败的未分配 BuildID `25121260`。

## 后续收尾

只需在已打开的 Steamworks 确认框中完成 `25136463 -> default` 的确认，不要再次上传生成重复构建。完成后刷新分支并用 SteamCMD 隔离回下载到 `<server_verify>/Liangshan_5088120`，设置 `LIANGSHAN_SERVER_DOWNLOAD`、`LIANGSHAN_UPLOAD_EXE` 后运行 `qa/steam_test_build_20260905/verify_server_download.py`，核对 appmanifest、EXE 哈希和独立启动。最后更新本记录、构建收据和 GitHub 同步文档。

本轮代码、生产素材、必要来源链与测试工具已推送 GitHub `codex/sync-20260905-stable`，提交 `863fcf0a1546c6ee7b5026db4bd4c5486a4ef61a`；项目文档及成品证据追加提交 `77d6d6cc477b828fc58300e5e30147a948dfcf55` 已远端回读。PR #1 标题/正文也已更新并通过官方 API 回读一致；远端 main 未改，未合并。

## 未覆盖项

本轮不是全阵容美术完成、真人 30 波通关、兵海峰值性能或 30 分钟稳定性验收。严格四向覆盖仍为 109/347，环境 36/69；旧广域阴影夹具 101/105 的四项旧地图前提失败仍保留。本轮成品短测不会替代这些门槛。
