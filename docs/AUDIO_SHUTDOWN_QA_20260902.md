# 音频退出生命周期修复与验证（2026-09-02）

## 问题与根因

旧版退出日志会稳定出现 `AudioStreamWAV` 2 个、`AudioStreamPlaybackWAV` 2 个、ObjectDB 泄漏警告和 `Master` 孤儿引用。数量与 `Music` 常驻节点中同时播放的 calm、battle 两个 `AudioStreamPlayer` 对应。

仅执行 `stop()`、清空 `stream` 并等待三帧仍有竞态；即使同步释放播放器节点，连续测试中 battle 和 direct core 路径仍复现 2+2。失败日志保存在 `qa/audio_shutdown_20260902/race_failure_pre_drain/`，没有用删除测试或过滤日志掩盖问题。

最终修复在退出阶段同步销毁播放器，并在曾经建立过音频 playback 时给独立音频线程 120 ms 释放窗口。这个等待只发生在退出过程中，不影响游戏运行帧率。

## 产品修改

- `scripts/app_lifecycle.gd`：新增统一、幂等的退出入口；先关闭 Sfx 和 Music，等待三帧后再调用 `SceneTree.quit()`；桌面关闭请求关闭自动退出并进入相同流程。
- `scripts/music.gd`：退出后拒绝播放和延迟入库；停止、清空并同步释放两个播放器；等待后台生成线程结束；清空曲目和间隔缓存；`_exit_tree()` 继续兜底。
- `scripts/sfx.gd`：退出后拒绝新音效；停止、清空并同步释放音效池；清空音效资源库；`_exit_tree()` 继续兜底。
- `scripts/menu.gd`、`scripts/battle.gd`、`scripts/android_updater.gd`：菜单退出、战斗退出、测试退出和更新后重启都改走 `AppLifecycle.request_quit()`。
- `project.godot`：注册 `AppLifecycle` autoload。
- `tools/audio_shutdown_regression_test.gd`、`tools/run_audio_shutdown_regression.ps1`：加入退出路径与菜单、战斗音频连续性回归。

静态路由检查确认，`scripts/` 下仅 `scripts/app_lifecycle.gd:30` 直接调用 `get_tree().quit()`。

## 验证结果

连续三轮执行 fast、battle、原 campaign core，共 9 次进程退出，9/9 通过。每次都满足：退出码 0、AudioStream 泄漏 0、全部 leaked instance 0、ObjectDB 警告 0、孤儿 StringName 0、脚本错误 0。

完整矩阵 8/8 通过：

| 路径 | 结果 | AudioStream | ObjectDB | orphan | 脚本错误 |
|---|---:|---:|---:|---:|---:|
| 快速启动退出 | PASS | 0 | 0 | 0 | 0 |
| 菜单返回退出 | PASS | 0 | 0 | 0 | 0 |
| 战斗 HUD 退出 | PASS | 0 | 0 | 0 | 0 |
| AndroidUpdater 重启入口 | PASS | 0 | 0 | 0 | 0 |
| 桌面窗口关闭通知 | PASS | 0 | 0 | 0 | 0 |
| 音效正在播放时退出 | PASS | 0 | 0 | 0 | 0 |
| 菜单→战斗→菜单 | PASS | 0 | 0 | 0 | 0 |
| 原 campaign core 直接退出兜底 | PASS | 0 | 0 | 0 | 0 |

菜单→战斗→菜单同时确认：calm 音乐、battle 音乐、返回 calm、两个音乐播放器和即时 Sfx 都能正常工作，修复没有破坏正常播放。

## 证据

- 总报告：`qa/audio_shutdown_20260902/report.json`，SHA-256 `5363b39de92fc3fde80434e5fe9b2fafff72cba4b83d99cea98c3ae4fb41de89`
- 完整矩阵：`qa/audio_shutdown_20260902/runner_summary.json`，SHA-256 `d6728724d68c42babc211d95a041d43a71137ff34caebe5f047f4870dafa9731`
- 三轮重复门槛：`qa/audio_shutdown_20260902/repeat_rounds_post_drain/summary.json`，SHA-256 `f1b36c1116e8f6d451aec6bbe5370027834bf00db3f7eeb285f77f00299edebd`
- 修复前竞态失败：`qa/audio_shutdown_20260902/race_failure_pre_drain/`，清单 SHA-256 `645bc15d0346e06fbed3faed3b4979fc40fae3371fcb1e9ae8c223736df03cb5`
- 初始备份：`C:/Users/rsb/Desktop/AI项目/水浒/implementation_20260902/pre_audio_shutdown_20260902_065438/`，清单 SHA-256 `942576f72ac0166720504b57ba0cd682c877f60962919017af4a89725bbfd0d4`
- 播放器释放前增量备份：`C:/Users/rsb/Desktop/AI项目/水浒/implementation_20260902/pre_audio_player_free_20260902_0711/`，清单 SHA-256 `a44b0565b51feb675b5eefb0020e77540d1f00db28e6c7061d6fc02356d3720e`

两份备份在验证完成后移到项目外层证据目录，避免嵌套 `project.godot` 触发编辑器扫描告警，也避免开发备份进入候选工程。QA JSON 中的原路径记录的是验证当时位置。

## 边界

- 没有运行 30 分钟 soak。
- 没有修改 Steam 发布目录，没有操作网页或环境美术。
- 桌面关闭用产品通知处理器模拟，且已验证 `SceneTree.auto_accept_quit=false`。
- AndroidUpdater 的产品方法已在 Windows headless 环境执行；本轮没有 Android 真机生命周期测试。更新落盘发生在调用退出前，没有发现必须保留旧退出行为的平台限制。
- 验证结束后 Godot 进程数为 0。
