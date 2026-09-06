# 特效设置 GUI 夹具草稿

仅用于未来标准/精简特效候选的 GUI 验证。当前没有运行 Godot、解析 GDScript、操作真实窗口、修改生产文件或 Git，没有 GUI 已通过或性能改善结论。文件限定在本目录；生产候选由根任务另行整合。

## 候选接口与来源

与 `scratchpad/reduced_effects_v2/` 的负责人核对：`Settings.effects_quality` 是 `standard` / `reduced` 字符串，保存为 `[show] effects_quality`；设置面板“显示”区新增“特效细节”，选项为“标准”“精简”。V2 通过动态 `get/set` 兼容没有该字段的旧 Autoload，旧实例隐藏新增行；本 GUI 夹具要求新 Autoload，旧实例降级另由 V2 验证。

`reviewed_sources.json` 保留本次读取的 menu/settings_panel/hud/settings 原始字节和 LF SHA，并锁定未修改的菜单、HUD、Campaign、Screen、AppLifecycle、更新器、project.godot 和安全 helper。运行时必须读取 V2 的 `pins.json`，验证四份候选的 LF SHA，另存本轮真实 raw SHA。不会把当前已读的旧 Settings/面板当新候选，也不会从临时插桩 Unit 重新定版。

运行器不应用补丁。只有根任务完成候选整合、相关导入并释放共享锁之后，才适合显式使用 `--run`。它复用 `.godot/redraw_rejection_source.lock` 和已有的精确 Popen/退出确认 helper，阻止与性能测量或源码切换并发；未知退出状态保留锁和记录，不执行生产恢复，因为此工具从不改生产源码。

## 真正经过的 GUI 路线

每个分辨率使用全新私有用户目录，随后启动两个独立 Godot 进程，共四次启动：

| 阶段 | 操作与检查 |
| --- | --- |
| write：主菜单 | 实际加载 menu.tscn；鼠标点击“更多”再点击“设置”；滚轮滚到“特效细节”；验证初始标准；依次点击精简→标准→精简；点击“返回（保存）”，核对同一菜单、未暂停、真实配置文件已保存精简。 |
| write：战斗 | 点击实际“竞技场”入口，点击实际 intro 的“继续”和开战按钮；发送 Esc 按下/释放，核对已有 Battle 暂停；点击暂停“设置”，滚到显示行；标准→精简切换，核对单位位置/HP、资源、phase、scene ID 都保持冻结。 |
| write：关闭/返回 | 设置内 Esc 只关闭设置、回到暂停菜单，不让同一个键穿透恢复战斗；重新打开设置再点“返回（保存）”，仍暂停；点击“继续”恢复同一 Battle 和设置速度；再 Esc，通过已有“返回主菜单→确认”释放旧 Battle 并回到未暂停菜单。 |
| read：独立重启 | 新 Popen 使用同一私有用户目录；任何 GUI 操作之前检查实际 Autoload 已读到 reduced，且加载前后保存 raw SHA 对得上；再通过真实菜单设置入口/滚轮确认精简高亮；Esc 保存返回菜单。 |

测试同时覆盖 **1440×900** 与 **1280×720**。实际窗口、root.size 与 content_scale_size 必须一致。滚轮经真实 Viewport 输入分发，要求 ScrollContainer 的真实偏移发生变化；不通过赋 `scroll_vertical` 把行搬到可见处。

点击使用 `Viewport.push_input` 的鼠标移动及左键按下/释放，生产按钮上额外连接只观察的 pressed 计数器，要求恰好一次。Esc 和滚轮也保存具体事件、位置、前后暂停/滚动状态。没有直接 `pressed.emit()`、设置质量赋值、调用 `_show_settings/_open_pause/_close_pause`、调用 Settings.save/Campaign.save_prefs 来冒充 GUI 路径。原有按钮回调负责改变值与保存。

这是 Godot 输入系统的合成事件测试，不是系统桌面自动化，也不替代人工键鼠、触屏、游戏手柄或辅助技术检查。

## 用户数据隔离

真实设置面板 `close()` 会同时调用 Settings.save() 和 Campaign.save_prefs()，所以不能只隔离一个 Settings 对象，也不能等 Autoload 之后再换保存地址。

已有 helper 默认设置 `CAMPAIGN_QA=1` 会令 Campaign._save 提前返回；GUI 启动器在私有目录保护下明确清除此开关，并核对关闭设置后真实的私有 campaign.cfg 已保存偏好，避免用测试分支跳过实际保存。自动检查内容更新被显式关闭，两项开关记录在最终受控环境中。

运行器仅修改新建子进程的 `APPDATA` 和 `LOCALAPPDATA`，都指向 `runs/<timestamp>/<size>/private_profile/`；父进程环境不变，不复制任何玩家保存文件。当前 project.godot 使用默认 user 路径；若未来新增 custom_user_dir 或项目名称需要特殊清理，运行器拒绝启动，要求重新审查映射。

Godot 4.6 的 Windows 实现明确由 APPDATA 派生 data path，再拼接项目用户目录，见 [OS_Windows 官方实现](https://github.com/godotengine/godot/blob/4.6/platform/windows/os_windows.cpp#L2252)；默认 user 路径说明见 [Godot 文件路径文档](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)。未使用不存在的 `--user-dir` 开关。

所有生产 Autoload 因此从进程启动时就读写私有用户目录；GDScript 启动后再次核对 `globalize_path("user://")` 必须等于外部记录、位于本目录 runs 下。这项运行后检查只是核验，主要保护来自进程启动前的环境隔离。真实玩家 settings.cfg、campaign.cfg、screen.cfg 只读 raw SHA 对照，绝不备份覆盖、删除或“自动恢复”。变化时失败并保留证据，避免盖掉其他真实游戏进程的修改。

独立重启通过两次精确 Popen 生命周期和私有保存原字节连续性证明。Windows 可以复用 PID，所以不把 PID 数字必须不同当必要条件。每次运行保留实际 PID。

## 收据与未完成验证

- 运行前后重新枚举九类生产目录（含隐藏文件）并计算 raw 文件 SHA、目录集合；异常扫描失败。所有来源变化使运行失败。生成 driver 的 raw SHA、本轮固定来源、V2 pins、引擎二进制 SHA、受控环境记录和完整事件放在 runs 下。
- 每次实际渲染截图保留分辨率、特效行/裁剪矩形、互斥高亮、暂停状态与 PNG SHA。检查选项、标签、保存返回按钮无遮挡于视口/滚动裁剪边界，标签宽高足以呈现文本，按钮不相交。
- `gui_valid` 只代表运行时输入、状态和几何检查。截图仍标记 `manual_visual_review: pending`；根任务必须实际看图确认文字、遮挡、对比度和两个档位高亮，不得仅因 PNG 存在就称视觉验收通过。
- 不比较设置关闭前后的 campaign 文件完全相等：生产关闭逻辑本来会保存偏好。所有这类保存发生在私有 profile，并记录前后 SHA。切档期间会比较其他 Settings 偏好不变；进入 Battle 会合法重设托管默认值，所以战斗检查以进入后的真实偏好为基准。
- 不覆盖技能伤害/随机数/效果绘制削减，这些由 V2 的独立行为/绘制 QA 负责。竞技场只是用来验证真实战斗暂停 UI，不是压力段或实际通关证据。

只读静态检查（不生成产物、不运行 Godot）：

```powershell
python scratchpad/reduced_effects_ui/prepare_and_run.py
```

根任务未来完成候选安装且取得独占时段后，可先选择一个分辨率试入口，再跑另一分辨率；默认覆盖两种：

```powershell
python scratchpad/reduced_effects_ui/prepare_and_run.py --run --sizes 1440x900
python scratchpad/reduced_effects_ui/prepare_and_run.py --run --sizes 1280x720
```

Godot 路径由 `--godot`、`GODOT_PATH` 或本 checkout 忽略的 godot.local.txt 提供。运行器不创建发布包、不改公共 tools、不改任何真实设置/存档。初次运行仍可能暴露 GDScript 解析或 GUI 调度问题，必须先修复并记录，再讨论通过。
