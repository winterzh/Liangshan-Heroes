# Android 2.0.1 累计热更新

## 范围与授权

目标为 `winterzh/Liangshan-Heroes` / `codex/sync-20260905-stable` 的源码与 `v2.0.1` 标签，以及 Android 更新服务器的 stable。用户明确“只做热更新，不发 release 包，github 的版本要一致”，并补充“可以先上更新服务器”。不创建 APK 或 GitHub Release，不合并 main，不操作桌面/Steam。

用户先确认原 2.0 的安装/覆盖安装、联网及触控验收完成；本机没有连接手机，本轮 2.0.1 实际 Android 性能、DPI、安全区和触控由用户发布后验收。自动化只声明 macOS 上的隔离 Android 模拟，不能推导真机 FPS。

## 已发布内容与版本身份

游戏修复来自 `166da65360d33c62a4751b10738737896d51b633`，本轮只有发布工具和文档/QA 变化；[此前 816 项逻辑、173 个布局、静态渲染 A/B](../android_controls_performance_20260925/README.md)适用于同一生产内容。包括托管取消后 AI 自动恢复、混选状态/FPS 遮挡、平板栏位过大修复及静态岸线/台地绘制优化。

- 固定完整包：2.0 / versionCode 16 / bootstrap 4，APK SHA-256 `78a15c9e1e31b9fbcab2e09ab92f6bbbd6a62a1bcfef7e0896f9c19ab1c249c0`，344,116,603 字节。
- 固定 PCK 基线：2.0，SHA-256 `05ee4bb3f04393c898986dd6f1d31483e4ba7fdbebbcfc07e04bd4f888d6e9b7`，315,958,024 字节。
- 内容版本：2.0.1，主菜单右下角显示 `v2.0.1`，其 tooltip 为完整安装包 2.0 / 当前内容 2.0.1；更新器另提供 `2.0 · 内容2.0.1` 组合字符串。APK 系统版本仍是 2.0，这是内容热更新，不是重安装。
- 正式构建要求 HEAD=发布 tag，签名清单 `source_commit` 绑定该源码；发布后的收据提交不移动标签。

## 发布前验证

- `transport/`：38 场景全部通过，含真实 HTTP 下载/跨进程挂载、签名/平台/基线/大小/哈希/损坏缓存拒绝，以及桌面更新停用。私有工程仅临时测试公钥，未改生产公钥，原始日志/JSON 保留，不复制私钥。
- `server_before/`：Android 2.0、Windows/macOS 1.8 的公开 stable 原始清单与签名。三者均验签通过，作为范围不越界的后验比较基准。
- `trial_build/`：以 `166da653` 试构建，3066 生产文件双侧 SHA 零漂移、Godot 4.6.3 导入/导出无错误。13 个差分资源，2,374,976 字节，试验 SHA-256 `dca962377715f38401b8d630420822b499080a6b628a692948f8301c2e6e0828`；此值不是正式发布哈希。
- `trial_apk_gate/`：实际原 APK 资源+原生产公钥+上述试补丁，14 项全部通过；菜单、翻译、新静态批绘制脚本、1280×853 六英雄 FPS/25% 技能栏、托管取消后的 AI 状态均通过。未修改 APK 原资源，输入零漂移。
- `policy.log`：发布策略离线通过，包含 30 个差分纯函数正负例、保护字段/开发和原生资源拒绝、两道原 APK 检查必须先于服务器写入/stable 提升，以及模拟提升失败回滚。

正式发布已在标签源码重新构建，并对最终同一 SHA 补丁重复门禁；试构建没有代替正式产物验收。

## 正式发布与回读

- GitHub `v2.0.1` 和发布时 stable 源码：`b3b0b7ac405f2584b811b0841d085cf2f28b3dc6`，远端 readback 见 `github_release_source.log`。没有创建新 Release；后续仅文档收据提交，标签不动。
- 正式 run：`build/update-publish/hot-2.0.1/run.1AkPUD/`。`formal_build/` 保留构建收据、13 项实际 PCK 资源清单和原始日志；3066 生产来源双侧 SHA 一致，导入/导出无错误。
- 正式 PCK：2,374,976 字节，约 2.3 MiB；SHA-256 `a7b489df78eb30c80e8534963ffbb92258eec3992a6cea76bdd20c09cfa2855c`。构建结果、最终上传副本和公网回读完整 PCK 三者一致；`artifact_sha256.log` 同时记录原 APK/固定基线哈希未变。
- 版本化清单 `published_at=2026-09-25T14:40:02+00:00`（UTC+8 为 22:40:02），`source_commit` 对应上述标签；[Android stable](http://120.26.237.195:1234/liangshan/android/stable/manifest.json) 已提升为同一签名清单。`publish.log` 记录完整门禁、上传、回读和成功提升。
- `offline_apk_gate/`：最终原 APK 自然挂载 14/14 通过；`online_apk_gate/`：原字节版本化清单转发、实际远端 PCK 下载、独立进程重启 20/20 通过。原生产公钥不变，实际 APK 提取资源不变，输入零漂移。
- `stable_apk_gate/`：发布后**直接正式 stable URL**、不做本地转发，20/20 通过；6 项真实下载检查加 14 项重启/功能检查。实际生效补丁 SHA 等于正式 PCK，菜单 2.0.1、翻译、六英雄 FPS/技能栏及取消托管后 AI 行为均通过。
- `server_after/`：公网三通道清单/签名再次回读。Android 与正式候选逐字节一致；Windows/macOS 各自与 `server_before/` 逐字节一致，仍为 1.8。仅修改 Android，不改变旧桌面文件。
- 独立只读复核另通过 24 项：tag/清单/构建收据绑定、三份 PCK、3066 源文件/冻结副本、13 项资源、两道 gate 输入、原 APK 逐资源与提取副本、实际缓存 PCK/state 和签名均一致；未运行第二个 Godot 或服务器写入。本项为协作复核记录，不冒充额外原生设备测试。

用户可在已安装的 2.0 安卓游戏内检查更新、下载、退出后重新打开，主菜单右下角应为 `v2.0.1`。2.0.1 的手机/平板帧率和触控仍需用户后验；本轮没有声称实际 Android 设备通过。

## 文件与证据边界

原始批位于 `/private/tmp/lsh_hot_update_201_transport_20260925`、`/private/tmp/lsh_hot_update201_build_trial_20260925` 和 `/private/tmp/lsh_hot_update201_candidate_trial_20260925`。仅归档白名单报告/日志/资源清单，不复制缓存、整个冻结工程、玩家配置、APK/PCK、签名私钥或 SSH 材料。原始生成日志保持字节，不因格式检查改写。正式构建在 Git 忽略的 `build/update-publish/hot-2.0.1/run.*/`。
