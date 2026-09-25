# 完整包与内容更新

## 当前平台策略（2026-09-25）

| 平台 | 架构 | 完整包 | 应用内内容更新 |
| --- | --- | --- | --- |
| Windows | x86_64 | EXE | 停用；安装新完整包或通过 Steam 更新 |
| Android | arm64 | APK | 保留；2.0 / versionCode 16 / bootstrap 4 完整包已发布 |
| macOS | arm64 | DMG | 停用；需另行安装新完整包 |

本次 Android 完整包与内容基线、GitHub `v2.0` tag 和 Release/APK 已发布，不涉及 Steam。服务器发布工具不依赖 GitHub Release。源码为 stable `9cf45c72`，桌面历史 stable 和签名字节未变；实际验收及手机未测边界见 [本批 QA](../qa/android_release_20260925/README.md)。

Windows/macOS 客户端均须在创建网络请求、读取更新缓存或挂载 PCK 之前停用更新器；环境变量不能重新启用原生桌面导出程序。既有缓存文件不删除，新桌面程序不加载。已安装的旧程序不会因源码改变而自动停用，需要另行换装包含此策略的完整包；此次没有桌面安装包交付。

Android 更新器继续验证 RSA 签名、平台、架构、底包兼容性、大小及 SHA-256，补丁保存在独立用户目录，重启后挂载。它不改写 APK，也不能替换原生库或启动配置。迁移详见 [ANDROID_RELEASE.md](ANDROID_RELEASE.md)。2026-09-18 曾保留 macOS 更新通道；这项历史策略已被本候选取代，旧线上文件仍原样保留。

## 版本与源码规则

- `vX.X`：完整发包，按当次授权选择平台；不要求同时构建三端或创建 GitHub Release。
- `vX.X.X`：当前完整发布线上的 Android 累计差异内容包，不创建新安装包；Windows/macOS 不再接收这类 PCK。
- 本次完整版本为 `2.0`，引导协议 `4`，Android `versionCode=16`，沿用原包名和签名证书。历史 `1.8` 同号诊断包不可作为 2.0 正式基线。
- 日常源码同步仅推 `codex/sync-20260905-stable`。合并 main、tag、GitHub Release、Steam 和更新服务器发布均需相应授权，不能把日常推送当作发布。
- 正式构建/发布要求干净工作区（包括未跟踪文件），HEAD 精确等于已验证 tag，不得绕过构建来源证明。

## 本次 Android 完整版流程

1. 同步 `export_presets.cfg`、`Campaign.VERSION`、更新器底包版本与 `tools/update_release.env`。
2. 运行游戏回归、更新器端到端和串包/跨底包拒绝测试；桌面运行时停用条件另行回归，不把跨平台导出当原生验收。
3. 白名单提交并推送既定分支；获得发布授权后，在同一已验证提交创建/推送 `v2.0` tag。
4. 运行 `bash tools/build_android_release.sh 2.0`，从同一私有冻结白名单生成正式无 TEST 标记的 APK 与 Android 基线 PCK。可显式设置 `GODOT_PATH`、`ANDROID_TEMPLATE`、`ANDROID_SDK_ROOT`、`JAVA_HOME`；不改全局工具链或签名配置。
5. 核对复制前后及构建结束时的双侧 SHA-256、来源范围、APK 版本/包名/arm64/权限和原证书 v2/v3 签名，完成 Android 真机验收。
6. 运行 `bash tools/publish_update_baseline.sh 2.0 "更新说明"`，公网回读 APK、清单及签名后提升 Android stable；无需先创建 GitHub Release。

`build/updates/build-source.json` 绑定源码提交、tag、APK 与 Android 基线的大小/SHA-256，平台范围只声明 `android`，发布时重新验证。新基线 `packaged_base` 与 `patch_base` 都是同一 2.0 PCK，`patch=null`、`min_bootstrap=4`；旧客户端须安装完整 APK，不生成跨旧工程的累计补丁。

历史多端工具 `build_packages.sh` 仍可用于另行授权的完整包构建，不用于本次发布。其桌面 PCK 只可作为本地留档，不上传、切换或发布为桌面应用内更新；历史三端 GitHub Release 文件保持原样。新的桌面交付须单独记录目标架构、原生验收和签名状态。

Steam 是另一条独立发布链，按 [Steam 发布指南](STEAM_RELEASE_GUIDE.md) 准备原生整合 QA 与专用候选；诊断单文件 EXE 不能替代 Steam 六文件候选。

## 小版本与保护边界

同一完整基线内，验证、提交、推送并创建三段式 tag 后：

```bash
bash tools/publish_hot_update.sh "$CONTENT_VERSION" "更新说明"
```

脚本只处理 Android，取已签名清单指定的固定底包生成累计差异，上传不可变版本文件，公网回读验签/验哈希后切换 Android stable。旧命令 `publish_android_hot_update.sh` 是该流程的兼容别名。

下列变化不得走小版本：`project.godot`、`export_presets.cfg`、`scripts/android_updater.gd`、`scripts/campaign.gd`、各平台原生工程目录、`.gdextension`、DLL/dylib/SO/framework。命中保护规则应发布下一个完整版本，不得放宽检查来强行生成内容包。

## 服务器与回滚

本次只写 Android 公开目录 `/var/www/pAI/liangshan/android/{stable,releases}/`，私有基线位于 `/root/liangshan-update-bases/android/base-X.X.pck`。Windows/macOS 的 stable、版本文件、私有基线，以及 Android 1.4.0/1.8 的历史版本文件保持原位，不删除、不覆盖，不把旧基线当作新工程的兼容基线。发布前后回读桌面清单与签名摘要，确认其字节未变。

不要重启或替换 1234 端口的文件服务；发布只原子替换 Android stable 文件，提升失败恢复 Android 旧清单。版本化清单、补丁、完整 APK 和底包不可覆盖。

回滚 stable 只能阻止尚未下载的客户端继续获取新版，不能让已安装 PCK 自动降级。已发布故障应以更高内容版本修复；涉及底包/引导器/原生层时改发更高完整版本。

## 本地诊断（不是发布）

仅需 macOS 本地试玩时可用 `tools/build_macos_test.py`：只在冻结副本加入独立用户目录、禁更新和测试标记，输出 Universal App/DMG，使用本地 ad-hoc 签名，不创建正式 tag/基线证明。实际测试架构须单独记录，不能把 Universal 文件当作 Intel 与 ARM64 均已验收。2026-09-21 本地包与入口验证见 [历史 QA](../qa/macos_test_20260921/README.md)。此路径不代替正式发布流程或 Apple 公证，不是本次 Android 完整构建入口。

```bash
python3 tools/update_release_policy_qa.py
python3 tools/run_update_transport_qa.py --godot "$GODOT_PATH" --out "$QA_OUT" --live
python3 tools/verify_platform_exports.py --godot "$GODOT_PATH" \
  --android-sdk "$ANDROID_SDK_ROOT" --java-home "$JAVA_HOME" --build
```

测试输出必须放在 checkout 外新目录，运行使用全新独占 profile，不接触玩家存档或重设 HOME。导出诊断不改版本、不创建 tag、不生成正式 `build-source.json`，也不上传文件；它只能证明实际导出、资源清单和签名校验，不能证明 Windows/Android 原生启动和真机操作。`verify_platform_exports.py --build` 包含 Windows 导出，不是本次 APK-only 正式流程。2026-09-18 的记录见 [历史 QA](../qa/controls_update_20260918/README.md)，不作为 2.0 已通过的证据。
