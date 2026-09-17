# 2026-09-07 任务框 Windows Steam 热更新

Steam App5088120 / Windows Depot5088121 / `default` 已更新为 **Build 25164373**，Manifest **7569243532561280133**。后台新清单恰好1个 `LiangshanHeroes.exe`，大小与SHA1均匹配经过验证的本地EXE；重新打开生成版本页面确认default已指向新Build。`steam-integration`仍为25160280。本轮未另做Steam客户端完整下载。

本包从公开版来源 `443e75e887afd76f9569cae17b0527a72408aedc` 冻结2463个运行文件，仅 `scripts/campaign_mission.gd` 使用已提交的 `f3da82f7452a2164c704c34a97c6b2696e99b9c3` 版本。source_manifest逐文件标明origin_commit与Git blob，不能把本包描述为当前stable整包或纯443e75。

八个战役共用任务框默认收起，点击展开/收回；隐藏时目标状态和任务计时继续，空出区域可正常操作地图。

## 同包验证

- Godot4.6.3导入/导出退出0，无错误警告；源文件及导入侧车无差异，只生成公开基线原有9个已知UID。
- 实际EXE内嵌PCK资源合同 **437** 项通过；实际EXE串行 **11** 次短测覆盖八关、据守、末波清理、菜单。
- 同一EXE挂载执行任务框真实鼠标输入 **115** 项通过，含展开/收回、地图区域释放、定位不发移动、隐藏状态更新、长滚动、阶段切换与结算隐藏。
- 共生成菜单/据守2张和任务框9张；实际目检其中7张（2+5），其余校验输出与哈希，`visual_review.json`绑定EXE与图像SHA；源码、真实玩家文件和helper守护通过，子进程退出及公共锁释放。

这不是完整真人战役、30波、30分钟或性能验收。未发布后续Steam集成/恢复功能或生产美术。

EXE 286993472 bytes，SHA256 `0934839ef975fd7fc7e4f31eead65c1df6097bcc1c2fc5570a7a0bb5094c0df5`。ZIP 219058214 bytes，SHA256 `86d9a030e54052bb3d6521f1dc919da141a6696b470c5dced55c385f3ff28973`，成员仅EXE；包和用户目录保持本机忽略路径。公告只写成[草稿](../../docs/UPDATE_ANNOUNCEMENT_MISSION_PANEL_20260907.md)，未发布社区。

## 复现

按source_manifest的Git提交与blob重建来源；把helpers恢复到同一相容checkout的全新 `.godot/<独占目录>/`。准备脚本绑定历史公开归档路径，须保持对应原始归档可读。先运行prepare_helpers，再运行freeze_snapshot.py freeze，然后 `run_guarded.py --profile-root <短绝对目录> --run`；Godot与release模板由参数/环境或本机配置提供。实际操作前必须取得公共Godot窗口，不能复用本轮运行或玩家目录。

重新查看新图并生成绑定同包SHA、base/overlay来源及toggle报告的visual_review后，才可用同入口 `--zip`。helper不会上传或切换Steam。原始源码/日志/截图保留；guard的真实玩家清单已移除，仅保留数量/摘要，转换映射见source_mapping.json。引用原始receipt内部SHA时勿用脱敏文件SHA替代。
