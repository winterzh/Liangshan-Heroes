# 三端完整包与差异更新

从 `v1.6` 开始，Windows x86_64、macOS arm64 和 Android arm64 使用同一套签名内容更新协议，但每个平台拥有独立基线、补丁和 stable 清单，不允许串包。

## 版本规则

- `vX.X`：完整发包。GitHub Release 必须同时包含 EXE、DMG、APK。
- `vX.X.X`：当前完整版发布线上的三端差异内容包，不创建新安装包。
- 所有发布都要先提交、推送、创建 tag。脚本要求工作区完全干净（包括未跟踪文件）且 HEAD 精确等于 tag。

`v1.6` 是桌面端第一个含更新引导器的完整包。v1.5.2 Windows/macOS 无法自行下载差异包，用户必须首先安装 v1.6 完整包。因此 v1.6 桌面清单的 `patch` 为 `null`；真正可下载的三端差异 PCK 从 v1.6.1 开始。

## 平台通道

| 平台 | 架构 | 完整包 | 清单 |
| --- | --- | --- | --- |
| Android | arm64 | APK | `/liangshan/android/stable/manifest.json` |
| Windows | x86_64 | EXE | `/liangshan/windows/stable/manifest.json` |
| macOS | arm64 | DMG | `/liangshan/macos/stable/manifest.json` |

更新器先校验 RSA 签名，再校验平台、架构、大小和 SHA-256。PCK 保存到平台独立的 `user://` 目录，重启后在主场景和其他 Autoload 前优先装载。它不改写 EXE、APP 或 APK，也不会破坏原安装包签名。

## 完整版流程

1. 同步 `export_presets.cfg`、`Campaign.VERSION`、更新器基线和 `tools/update_release.env`。
2. 运行游戏回归、更新器端到端测试和跨平台串包拒绝测试。
3. 提交并推送 `main`，在同一提交创建/推送 `vX.X` tag。
4. 构建三端完整包与基线：

   ```bash
   bash tools/build_packages.sh 1.6
   ```

5. 创建 GitHub Release，上传 `LiangshanHeroes-v1.6.exe/.dmg/.apk`。
6. 公网三包可下载后，发布签名基线：

   ```bash
   bash tools/publish_update_baseline.sh 1.6 "更新说明"
   ```

构建脚本会写入 `build/updates/build-source.json`。发布脚本重新计算三个完整包和三个基线 PCK 的大小/SHA-256，并要求其提交与 tag 完全一致，避免误发 `build/` 中的旧产物。

## 小版本流程

提交、推送并创建 `v1.6.1` tag 后：

```bash
bash tools/publish_hot_update.sh 1.6.1 "更新说明"
```

脚本会从三端固定基线生成累计差异包，上传版本化文件，公网回读验签/验哈希，最后一起切换三端 stable。

下列受保护变更不允许走小版本：

- `project.godot`、`export_presets.cfg`
- `scripts/android_updater.gd`、`scripts/campaign.gd`
- Android/iOS/macOS/Windows 原生工程目录
- `.gdextension`、DLL、dylib、SO、framework

命中时脚本会中止，应改发下一个两段式完整版。

## 服务器布局

公开文件：

```text
/var/www/pAI/liangshan/{android,windows,macos}/stable/
/var/www/pAI/liangshan/{android,windows,macos}/releases/
```

私有不可变基线：

```text
/root/liangshan-update-bases/{android,windows,macos}/base-X.X.pck
/root/liangshan-update-bases/base-1.4.0.pck   # Android 历史累计基线
```

不要重启或替换当前 1234 端口的文件服务进程；发布只需要原子替换 stable 文件。版本化清单、补丁和基线均不允许覆盖。

## 回滚

- stable 提升由同一个远程进程预加载三端新文件，任一替换失败会恢复三端旧清单。
- 手工回滚只能阻止尚未更新的客户端继续获取新版；已下载 PCK 的客户端不会自动降级。
- 已发布内容存在问题时，优先修复后发更高的 `vX.X.X`；若涉及引导器/工程/原生层，发更高的 `vX.X` 完整包。

## 发布后验证

1. 三端 stable 的 `content_version`、`platform`、`architecture` 与预期一致，且签名有效。
2. v1.6 Windows/macOS 显示“已是最新”；Android 旧包可获取累计补丁。
3. v1.6.1 模拟清单在三端都能完成检查、下载、哈希校验、保存和重启装载。
4. 将 Android 清单提供给 Windows/macOS，或修改架构字段，客户端必须明确拒绝。
5. 服务器公网回读的补丁/完整 APK 大小和 SHA-256 与本地一致。
