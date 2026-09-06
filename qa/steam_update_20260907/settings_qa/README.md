# 新 Windows 包：设置与新增模块的补充检查

这是外部 QA 草稿，准备阶段未运行 Godot。目标包来源为 `443e75e887afd76f9569cae17b0527a72408aedc`；运行器从本轮 `build_receipt.json` 验证 EXE 身份，再用实际非 `_console.exe` 引擎的 `--main-pack` 挂载该 EXE。没有修改或替换包内 Settings、SettingsPanel、菜单或 codec。

`package_settings_qa.gd` 与 `run_settings_qa.py` 配合，顺序启动两个真实独立进程，共用本轮新建的隔离 APPDATA/LOCALAPPDATA。默认入口仅只读预检；只有显式 `--run` 才申请共同引擎锁和运行。根任务负责实跑，本目录准备者没有运行许可。

1. `write`：确认实际 Autoload 默认 `standard`、不存在 settings.cfg；由实际菜单的 `_show_settings` 打开实际 SettingsPanel，滚轮使显示区可见，真实鼠标点击“精简”，确认设置值和互斥选中状态；绘制后导出一张 1280×720 Vulkan 设置界面 PNG；真实点击“返回（保存）”。
2. `read`：全新 OS 进程从同一隔离目录启动；不预先设置 `effects_quality`，验证真实 Autoload 恢复 `reduced`，面板亦显示“精简”；关闭后配置字节保持。
3. 两进程均检查面板 `z_index == 300`、真实 mouse filter 和 `PROCESS_MODE_ALWAYS`；把菜单夹具设为暂停，确保仍可操作而关闭不解除暂停。关闭后确认面板实际释放，解除夹具暂停后实际菜单按钮能收到 hover。这是暂停状态的菜单夹具，未覆盖完整战斗内暂停菜单调用链或所有 HUD 遮挡组合。
4. 两进程均执行 `load("res://scripts/run_state_value_codec.gd") is Script`。这里只证明新增基础脚本可从包中加载，不验证完整存档/续局或开放继续按钮。

脚本使用真实菜单生产打开方法，省略“更多→设置”的菜单导航点击；质量选择、滚动和保存退出使用真实 Viewport 输入，并记录恰好一次 pressed 信号。只有输入后状态变化成立才通过，不以人工触发信号代替点击。截图来自新包实际根视口，须根任务单独目检，不能把截图或这些断言解释为完整真人交互验收。

运行示例（仓库根目录；`--out` 必须尚不存在）：

```powershell
$releaseReceipt = Get-Content .godot/steam_update_20260907/build_receipt.json -Raw | ConvertFrom-Json
python -B scratchpad/steam_update_extra_20260907/run_settings_qa.py --godot $releaseReceipt.godot --exe $releaseReceipt.executable
python -B scratchpad/steam_update_extra_20260907/run_settings_qa.py --godot $releaseReceipt.godot --exe $releaseReceipt.executable --run
```

预计输出为 `runs/<UTC>/` 下两个模式的 JSON/日志、实际设置 PNG 和总收据；具体文件名以运行器收据为准。每份报告包括实际 PID、userdir、源码提交、EXE 与外部脚本 SHA；运行器核对实际进程句柄、严格日志、前后来源摘要和真实玩家目录守护。任何失败保留本轮日志和报告，不覆盖前次结果；无法确认引擎退出时保留锁与失败现场。

仍需保留本轮既有 437 项包内资源契约、11 个短启动/专项与菜单/驻守两图。它们与本补充检查合起来也不等于八关完整通关、全部新任务交互、30 波驻守完成、30 分钟持续运行、真人试玩或性能验收。先前生产专项的范围见 `docs/POLISH_FEEDBACK_20260906.md` 与 `docs/REDUCED_EFFECTS_20260906.md`。
