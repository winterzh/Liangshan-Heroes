# 任务框点击展开 QA — 2026-09-07

基线为 `b074ba91c28a9e24a32b1ad2469522094f8267cd`，候选只改变共享任务框的显示/布局；七个原有详细界面夹具显式展开。受测生产候选 SHA-256 为 `036a9bf725efebb9a0c924b0cc7655c91e9a06545916986ed2ea182b15e40887`。

## 最终结果

Godot 4.6.3 默认 Vulkan/Forward+ 的 `passed_vulkan`：导入、115项真实 GUI 检查、22项任务核心合同、5个原有视觉样本均退出0；四阶段无 ERROR/WARNING。来源2881文件与真实玩家目录前后守护一致，所有引擎子进程退出，共享锁已释放。截图来自独立用户目录的真实渲染。

专用驱动覆盖祝家庄/江州/高俅1280×720和祝家庄1920×1080：默认收起、真实展开/收回、定位不发命令、空出区域地图点击、隐藏时计时与文字刷新、阶段保持状态、结束隐藏。高俅追加12条明确夹具任务，实际滚轮抵达末项且不侵入底栏。新局默认收起，既有详情夹具仍验证展开状态。

已查看祝家庄默认/展开、江州四目标、高俅长列表和1920×1080实际画面。[默认收起](passed_vulkan/toggle/level3_1280x720_collapsed.png)、[点击展开](passed_vulkan/toggle/level3_1280x720_expanded.png)。测试含冻结场景及人工构造数据，不构成真人通关、战斗表现或性能基准；截图内FPS不能用作性能结论。未进行Steam上传或发布。

## 首轮记录

`attempt_1_gl_warning` 的同一生产候选已通过115项交互，但临时GL compatibility与工程2D MSAA不相容，产生 `2D MSAA is not yet supported for GLES3` WARNING；严格runner因此终止该轮，后两阶段未运行。随后仅将runner恢复游戏默认渲染方式，生成独立最终通过记录，没有忽略警告。首轮日志/收据/报告保留，重复截图未归档。

## 复现与文件

在基线的相容Git checkout中运行：

```powershell
py -3.14 -X utf8 -B qa/mission_panel_toggle_20260907/run_qa.py --project-root '<工程绝对路径>' --run
```

不带 `--run` 只预检；设置好本机 `godot.local.txt`。runner读取当前提交生产路径白名单的实际字节、覆盖此目录保留的候选和驱动，复制至独立 `.godot/mission_toggle_*`，持项目公共Godot锁，并为APPDATA/LOCALAPPDATA/TEMP/TMP创建全新 `D:/LHUiProfiles` 子目录。首次运行前必须确认没有其他Godot进程或来源修改任务；新HEAD的结果是新验证，不能沿用本轮基线结论。

`passed_vulkan/receipt.json` 保留实际绝对执行路径与生产SHA；`scripts/`、`tools/`、顶层驱动为受测候选，`adapt_visual_fixtures_manifest.json` 给出七个原脚本before/after。普通使用入口见[任务框说明](../../docs/MISSION_PANEL_TOGGLE_20260907.md)。此目录以 `.gdignore` 隔离，Git按原字节保存证据；私有工程、Godot缓存及用户目录不入库。
