# 独立 compiled PCK 验证入口（尚未实跑）

```powershell
& $Python -X utf8 scratchpad/run_gameplay_rng_runtime/run_pck.py --godot $ActualGodot
& $Python -X utf8 scratchpad/run_gameplay_rng_runtime/run_pck.py --godot $ActualGodot --run
```

`--run` 独占共同 Godot 锁，所有导出/运行按序完成；使用精确冻结非 console 引擎，不改生产工程配置。默认预检不复制、不导出、不创建 profile。

只复制下列六项到 `pck_runs/<UTC>/project/`，无玩家内容、旧导入镜像或全库素材：production codec，runtime gameplay_rng.gd（保留受信 res:// 路径），pck_driver.gd → 根 pck_driver.gd，pck_project.godot → project.godot，pck_main.tscn → main.tscn，pck_export_presets.cfg → export_presets.cfg。三份 GD 各自生成的 canonical UID 和私有 `.godot` 缓存是唯一允许的额外生成输入。preset 使用 `script_export_mode=2`。

runner 的第一实际进程执行：

```
<actual Godot> --headless --path <private project> --editor --export-pack "RNG QA PCK" <run>/runtime.pck --quit
```

导出日志必须无严格告警/错误、真实子进程已退出、PCK 非空且源未变。若本机导出依赖缺失，按真实失败记录中止，不读写或搬运真实玩家目录来规避。只依赖 PCK 导出，无需复制整个游戏/Steam EXE。

接着从全新的空 `<run>/empty_launch/`，以两个独立实际进程依次运行：

```
<actual Godot> --headless --path <empty launch> --main-pack <run>/runtime.pck
```

没有外部 `--script`，使用 PCK 的 main.tscn 和编译后驱动。Godot 会消费 `--main-pack`，因此不检查 `OS.get_cmdline_args()` 中是否仍存在该参数；实际 Popen 命令、空路径、PCK 原字节 SHA、固定 Script 加载和 GD 源原文件缺失共同绑定入口。GD 直接读取自身实际 EXE SHA，与 host 实测匹配。writer/reader 的实际报告 PID 必须等于 Popen.pid 并不同。CREATE_NO_WINDOW 保持后台运行；每 0.1 秒检查自己的日志并在严格错误时立即停止精确子进程，退出确认后才进入收尾。三个进程各用独立 APPDATA/LOCALAPPDATA/TEMP/TMP；manifest 只能指向同轮次新建路径。

预计断言 writer **24**、reader **33**：三份 `.gd` 原始文件不存在而资源可加载；真实 native 对照的 7 个 seed（含 signed64 极值及超 JSON 安全整数）前缀/后缀；真实磁盘 tagged JSON；reader 完整 checkpoint restore、每 seed 64 个混合后续值及终态；无关随机噪声；其他可信内容版本拒绝旧记录且保持未初始化；host 钉住 writer 报告/输入、PCK 和 manifest 前后不变。PCK 简短矩阵不重复 source 的全部畸形 codec/范围负例。

完整日志在 `<stage>_process.log`，真实进程收据 `<stage>_process.json`；报告/manifest 各 `<writer|reader>_report.json`、`<stage>_manifest.json`，精确 handoff.json、源码/玩家/私有源前后收据和最终 receipt.json 均保留。只有实际全部成功且锁安全释放，才记录 `pck_tested=true`；默认/准备状态为 false。失败或退出无法确认即停止后续进程，现场/锁保留规则沿现有 reviewed lifecycle。

此包仅验证 runtime 模块无源码条件下运行与新进程 RNG 续接；不是完整游戏的 PCK 集成、Battle 随机迁移、保存恢复、跨版本兼容或 Steam 发布验收。
