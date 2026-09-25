# Android 2.0.1 累计热更新

## 范围与授权

目标为 `winterzh/Liangshan-Heroes` / `codex/sync-20260905-stable` 的源码与 `v2.0.1` 标签，以及 Android 更新服务器的 stable。用户明确“只做热更新，不发 release 包，github 的版本要一致”，并补充“可以先上更新服务器”。不创建 APK 或 GitHub Release，不合并 main，不操作桌面/Steam。

用户先确认原 2.0 的安装/覆盖安装、联网及触控验收完成；本机没有连接手机，本轮 2.0.1 实际 Android 性能、DPI、安全区和触控由用户发布后验收。自动化只声明 macOS 上的隔离 Android 模拟，不能推导真机 FPS。

## 待发布内容与版本身份

游戏修复来自 `166da65360d33c62a4751b10738737896d51b633`，本轮只有发布工具和文档/QA 变化；[此前 816 项逻辑、173 个布局、静态渲染 A/B](../android_controls_performance_20260925/README.md)适用于同一生产内容。包括托管取消后 AI 自动恢复、混选状态/FPS 遮挡、平板栏位过大修复及静态岸线/台地绘制优化。

- 固定完整包：2.0 / versionCode 16 / bootstrap 4，APK SHA-256 `78a15c9e1e31b9fbcab2e09ab92f6bbbd6a62a1bcfef7e0896f9c19ab1c249c0`，344,116,603 字节。
- 固定 PCK 基线：2.0，SHA-256 `05ee4bb3f04393c898986dd6f1d31483e4ba7fdbebbcfc07e04bd4f888d6e9b7`，315,958,024 字节。
- 内容版本：2.0.1，菜单预计 `2.0 · 内容2.0.1`；APK 系统版本仍是 2.0，这是内容热更新，不是重安装。
- 正式构建要求 HEAD=发布 tag，签名清单 `source_commit` 绑定该源码；发布后的收据提交不移动标签。

## 发布前验证

- `transport/`：38 场景全部通过，含真实 HTTP 下载/跨进程挂载、签名/平台/基线/大小/哈希/损坏缓存拒绝，以及桌面更新停用。私有工程仅临时测试公钥，未改生产公钥，原始日志/JSON 保留，不复制私钥。
- `server_before/`：Android 2.0、Windows/macOS 1.8 的公开 stable 原始清单与签名。三者均验签通过，作为范围不越界的后验比较基准。
- `trial_build/`：以 `166da653` 试构建，3066 生产文件双侧 SHA 零漂移、Godot 4.6.3 导入/导出无错误。13 个差分资源，2,374,976 字节，试验 SHA-256 `dca962377715f38401b8d630420822b499080a6b628a692948f8301c2e6e0828`；此值不是正式发布哈希。
- `trial_apk_gate/`：实际原 APK 资源+原生产公钥+上述试补丁，14 项全部通过；菜单、翻译、新静态批绘制脚本、1280×853 六英雄 FPS/25% 技能栏、托管取消后的 AI 状态均通过。未修改 APK 原资源，输入零漂移。
- `policy.log`：发布策略离线通过，包含 30 个差分纯函数正负例、保护字段/开发和原生资源拒绝、两道原 APK 检查必须先于服务器写入/stable 提升，以及模拟提升失败回滚。

正式发布会在标签源码重新构建，针对最终同一 SHA 补丁重复门禁；试构建不能代替正式产物验收。公开不可变文件、真实 stable 下载/重启与 GitHub 回读将在发布后补充。

## 文件与证据边界

原始批位于 `/private/tmp/lsh_hot_update_201_transport_20260925`、`/private/tmp/lsh_hot_update201_build_trial_20260925` 和 `/private/tmp/lsh_hot_update201_candidate_trial_20260925`。仅归档白名单报告/日志/资源清单，不复制缓存、整个冻结工程、玩家配置、APK/PCK、签名私钥或 SSH 材料。原始生成日志保持字节，不因格式检查改写。正式构建在 Git 忽略的 `build/update-publish/hot-2.0.1/run.*/`。
