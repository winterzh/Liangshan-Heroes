# 完整包与内容更新

## 当前平台策略（2026-09-18）

| 平台 | 架构 | 完整包 | 应用内内容更新 |
| --- | --- | --- | --- |
| Windows | x86_64 | EXE | 暂停；安装新完整包或通过 Steam 更新 |
| Android | arm64 | APK | 保留；下一次先安装 bootstrap 4 新完整包 |
| macOS | arm64 | DMG | 保留；受保护变更需新完整包 |

Windows 客户端在创建网络请求、读取更新缓存或挂载 PCK 之前即停用更新器；环境变量不能重新启用原生 Windows 导出程序。既有缓存文件不删除，但本轮新 EXE 不会加载。发布脚本不再提升 Windows stable；已经安装的旧 EXE 不会因源码改变而自动停用，用户需要换装包含此修复的 EXE/Steam 构建。本轮未发布任何安装包或服务器内容。

Android/macOS 更新器验证 RSA 签名、平台、架构、底包兼容性、大小及 SHA-256，补丁保存在平台独立用户目录，重启后挂载。它不改写 EXE、APP 或 APK，也不能替换原生库或启动配置。Android 新基线迁移详见 [ANDROID_RELEASE.md](ANDROID_RELEASE.md)。

## 版本与源码规则

- `vX.X`：完整发包，GitHub Release 同时包含 EXE、DMG、APK。
- `vX.X.X`：当前完整发布线上的 Android/macOS 累计差异内容包，不创建新安装包；Windows 不接收这类 PCK。
- 当前源码版本仍为 `1.8`，引导协议已升到 `4`。本轮同号诊断包不可直接作为新正式基线；后续应选新的两段式版本，提高 Android versionCode 并同步各平台版本字段。
- 日常源码同步仅推 `codex/sync-20260905-stable`。合并 main、tag、GitHub Release、Steam 和更新服务器发布均需相应授权，不能把日常推送当作发布。
- 正式构建/发布要求干净工作区（包括未跟踪文件），HEAD 精确等于已验证 tag，不得绕过构建来源证明。

## 完整版流程

1. 同步 `export_presets.cfg`、`Campaign.VERSION`、更新器底包版本与 `tools/update_release.env`。
2. 运行游戏回归、更新器端到端和串包/跨底包拒绝测试，完成各目标系统原生验收。
3. 白名单提交并推送既定分支；获得发布授权后，在同一提交创建/推送 `vX.X` tag。
4. 运行 `bash tools/build_packages.sh "$VERSION"`，生成三端完整包与三个基线 PCK。
5. 创建 GitHub Release，上传对应 EXE、DMG、APK；公网核对三包哈希。
6. 运行 `bash tools/publish_update_baseline.sh "$VERSION" "更新说明"`。

`build/updates/build-source.json` 绑定源码提交、tag 和六个产物的大小/SHA-256，发布时重新验证。Android/macOS 新完整基线的 `patch` 都为 `null`，客户端不兼容时提示安装完整包。Windows 完整包仍保留在 GitHub Release，但不发布或切换其应用内更新清单。

Steam 是另一条独立发布链，按 [Steam 发布指南](STEAM_RELEASE_GUIDE.md) 准备原生整合 QA 与专用候选；诊断单文件 EXE 不能替代 Steam 六文件候选。

## 小版本与保护边界

同一完整基线内，验证、提交、推送并创建三段式 tag 后：

```bash
bash tools/publish_hot_update.sh "$CONTENT_VERSION" "更新说明"
```

脚本只处理 Android/macOS，取各自已签名清单指定的固定底包生成累计差异，上传不可变版本文件，公网回读验签/验哈希，再一起切换两个 stable。

下列变化不得走小版本：`project.godot`、`export_presets.cfg`、`scripts/android_updater.gd`、`scripts/campaign.gd`、各平台原生工程目录、`.gdextension`、DLL/dylib/SO/framework。命中保护规则应发布下一个完整版本，不得放宽检查来强行生成内容包。

## 服务器与回滚

Android/macOS 公开文件分别位于 `/var/www/pAI/liangshan/{android,macos}/{stable,releases}/`，私有基线位于 `/root/liangshan-update-bases/{android,macos}/base-X.X.pck`。Windows 与 Android 1.4.0 的历史文件保持原位，不删除、不覆盖，不把它们当新版本兼容基线。

不要重启或替换 1234 端口的文件服务；发布只需要原子替换 stable 文件。提升进程预加载 Android/macOS 两端文件，任一替换失败恢复两端旧清单。版本化清单、补丁和底包不可覆盖。

回滚 stable 只能阻止尚未下载的客户端继续获取新版，不能让已安装 PCK 自动降级。已发布故障应以更高内容版本修复；涉及底包/引导器/原生层时改发更高完整版本。

## 本地诊断（不是发布）

```bash
python3 tools/update_release_policy_qa.py
python3 tools/run_update_transport_qa.py --godot "$GODOT_PATH" --out "$QA_OUT" --live
python3 tools/verify_platform_exports.py --godot "$GODOT_PATH" \
  --android-sdk "$ANDROID_SDK_ROOT" --java-home "$JAVA_HOME" --build
```

测试输出必须放在 checkout 外新目录。导出诊断不改版本、不创建 tag、不生成正式 `build-source.json`，也不上传文件；它只能证明实际导出、资源清单和签名校验，不能证明 Windows/Android 原生启动和真机操作。详见 [本轮 QA](../qa/controls_update_20260918/README.md)。
