# Windows Steam 更新包：2026-09-06

本目录是独立 Windows 更新快照、成品和验收证据。所有内容均从已提交源码冻结，未修改生产源码、共享导出预设、玩家存档或 Steam 安装目录；本子任务没有上传、切换 Steam 分支或正式发行。

- 源提交：`954ffde683e79fe90656e5acba78692bc5de67b8`。
- 冻结运行输入：2,462 个文件，275,485,594 字节；树 SHA-256：`98c8e50c416714d1a21b4f2ec9b13fef71d0cdacf80ce3adf8716ba51f9db870`。
- 输入直接读取 Git blob，逐文件保存 SHA-256、大小和 Git blob ID。`source/` 保存原始冻结内容，`project/` 是独立导入/导出副本。两者生产文件及导入侧车在导出后保持一致，Godot 在副本内生成了 8 个缺失 UID。
- 明确纳入当前运行的 36 个宋江/林冲 SpriteFrames、22 张角色生产源图及 UI 单图。排除原图、生成草稿、开发工具、QA、文档、凭据、玩家数据和旧 Godot 缓存。正式发布门禁没有修改；32 个既有环境缺图继续使用当前源码的回退。

## 成品身份

`windows/LiangshanHeroes.exe`：286,979,872 字节；Windows x86_64，嵌入 PCK，文件/产品版本沿用已提交预设 `1.8.0.0`。

- SHA-256：`f7e7fdabbf3869e56a6b5b0d1869069e89122ccb8dc4c2e091ed16b188e0bcf3`
- SHA-1（供 Steam Depot 网页核对）：`7862a6ba3adbee4a0c9fd862f34f4c8a12354610`

`windows/LiangshanHeroes-Windows-20260906.zip`：217,926,716 字节；根目录只有 `LiangshanHeroes.exe`。已完整验 CRC，并解压读取内部 EXE 验 SHA-256。

- ZIP SHA-256：`031b2d01826b9e042015626e59a69f96900145af3eafeb23644a5cd46b6336fb`

## 验证结果

- Godot 4.6.3 官方 Windows release 模板。全新导入 216.935 秒、标准 release 导出 109.002 秒；退出码 0，错误和警告均为 0。
- 同版本 Godot console 以 `--main-pack` 加载上述 EXE 的内嵌 PCK；437 项契约通过，覆盖 36 个 TRES、100 个排帧、22 张生产图导入资源、Art 实际路由以及包内开发文件排除。外部 QA 脚本不进入 PCK。
- 实际 release EXE 使用每个子进程独立的 APPDATA 执行 11 次短测：八关 8/8、驻守硬伤 9/9、末波清理 12/12、主菜单启动。日志无脚本、解析、资源错误或警告。
- 同一内嵌 PCK 在 RTX 3070 Ti / Vulkan / Forward+ 生成 1280×720 主菜单和驻守画面 2/2，Codex 已逐张打开目检。主菜单完整；驻守建筑、墙门、单位、资源栏、小地图及说明完整。截图角落短时 FPS 不作为性能测量。
- 导出、测试和 ZIP 打包后 EXE 哈希一致。独立复核代理另行验证了全部输入的 Git blob SHA-1/本地 SHA-256、动态依赖和包内条目，无冻结遗漏。

这些检查证明当前更新包可启动且本轮资源完整，不能代替真人完整八关、驻守30波、30分钟稳定性、平衡、性能预算或商业美术来源验收。`package_visual_capture.json` 中 `human_visual_review=false` 表示没有真人试玩；代理图片目检单独记录于 `visual_review.json`。

## 复现与归档

工具以自身目录作为输出目录，主仓库路径默认为上两级，Godot 取 `GODOT_PATH` 或仓库 `godot.local.txt`。从全新本轮目录开始，按顺序执行：

```powershell
py -3 -X utf8 -B freeze_snapshot.py freeze
py -3 -X utf8 -B build_windows.py
py -3 -X utf8 -B verify_package.py
```

只有打开并检查两张新图片、写入与新图/新 EXE 哈希绑定的 `visual_review.json` 后，才能运行 `prepare_upload_zip.py`。冻结/导出/ZIP 助手拒绝覆盖既有产物。当前成品已经完成，不应在上传前无故重导出。

归档采用 `archive_manifest.json` 内逐文件名单：根目录助手、输入/构建/测试/ZIP收据和日志，以及 `smoke/`、`visual/` 证据。`source/`、`project/`、`userdata/`、`windows/` 不进入 Git 文档提交；不要将导出 EXE、ZIP 或 Godot 模板上传到源码仓库。
