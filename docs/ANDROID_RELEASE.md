# Android 完整包与内容更新发布

## 当前规则（2026-09-25 候选）

本次目标为 Android `2.0` 完整 APK，`versionCode=16`、引导协议 `4`，沿用包名 `com.liangshan.heroes` 和原签名证书。正式候选不含 `TEST` 版本后缀或菜单标记。这是候选要求；构建、真机验收和上线状态以当批 QA 与发布收据为准，本文不表示已经发布。

以后应用内内容更新仅保留 Android；Windows/macOS 客户端均在网络请求、缓存读取和 PCK 挂载前停用更新器。此次不发布桌面完整包或桌面 PCK，不切换桌面 stable，旧线上文件原样保留。用户本次授权 GitHub 代码、`v2.0` tag 和 Release/APK 附件；不涉及 Steam。服务器发布工具本身不依赖 GitHub Release。

**2.0 必须先发完整 APK，不能把当前工程直接制成旧 1.8 客户端的内容补丁。** 新增的 Autoload、工程配置及更新引导器不能通过旧进程挂载 PCK 完整替换。2026-09-18 的历史说明使用 `1.8` / `versionCode=15`，当时 macOS 通道仍保留；该批诊断包不属于本次正式基线。

- 完整发包：`vX.X`，本次仅交付 Android；不要求同时导出三端。
- 差异内容更新：`vX.X.X`，仅针对兼容底包的 Android，不创建新安装包，不发布 Windows/macOS PCK。
- Godot、Autoload/工程配置、导出配置、引导器或原生库变化，必须发下一个完整版本。
- 客户端仅内置验签公钥；私钥、SSH 密钥、签名材料不得提交到仓库。

## 新完整包基线

本次同步 `Campaign.VERSION`、`export_presets.cfg`、`scripts/android_updater.gd`、`tools/update_release.env` 的 `2.0` 版本字段，Android versionCode 提高到 `16`。版本字段同步不代表桌面产物已构建或发布。Android 新完整基线的清单必须是：

- `packaged_base.version` / `patch_base.version` 均为新完整版本，两份描述的大小和 SHA-256 一致。
- `patch: null`，`min_bootstrap: 4`（以后协议升级时相应提高）。
- `full_package` 与兼容字段 `full_apk` 指向同一完整 APK，大小和 SHA-256 可公网回读验证。

旧客户端应提示安装完整 APK，不再生成 `1.4.0 → 新工程` 的跨工程累计补丁。历史 1.8 服务器文件保留原样；`base-1.4.0.pck` 只属于历史发布线，不能作为新完整版本的基线。

完整版本内的小更新仍是**从该完整基线到最新内容版本的累计差异**，因此不用逐版下载。差异包不是 APK 二进制差分，也不会替换安装包自身。

## 构建与发布

先验证源码、更新交接记录，按文件白名单提交并推送 `codex/sync-20260905-stable`。不得自行直接推 main 或合并。正式发布需当次授权；本次在已验证提交创建 `v2.0` tag，完整构建要求工作区干净且 HEAD 精确匹配 tag。

Android-only 完整构建入口如下，工具链路径可由 `GODOT_PATH`、`ANDROID_TEMPLATE`、`ANDROID_SDK_ROOT`、`JAVA_HOME` 显式提供。引擎与 Android 模板须版本匹配并保留校验记录；不替换全局编辑器、模板或签名配置。

```bash
bash tools/build_android_release.sh 2.0
```

构建在私有目录冻结生产白名单，复制前后核对源文件与副本 SHA-256，结束时再次检查源码与副本漂移。APK 与 `base-2.0.pck` 必须来自同一冻结源码；正式包不得加入测试标签。产物及日志目录以当次收据为准，`build/updates/build-source.json` 绑定 tag、提交、大小和哈希，平台范围只声明 `android`，不得声称验证了桌面产物。

APK 必须校验包名、arm64、`versionName=2.0`、`versionCode=16`、INTERNET 权限及签名。证书 SHA-256 必须匹配 `tools/update_release.env` 的原证书契约，并验证 v2/v3 签名，保证覆盖安装身份不变。不要读取或打印签名密码。

完成对应验收、取得发布授权后，发布 Android 完整包及基线；此入口不依赖 GitHub Release：

```bash
bash tools/publish_update_baseline.sh 2.0 "本次实际交付的更新说明"
```

脚本仅上传 Android 清单、不可变基线与完整 APK，公网回读验签/验哈希后提升 Android stable；提升失败恢复该通道旧清单。Windows/macOS 历史 stable、版本文件和基线不写、不删。旧入口 `publish_android_baseline.sh` 是同一安全流程的参数透传别名。

`build_packages.sh` 仍保留多端完整构建用途，但不用于此次 Android 发布，也不据此发布桌面 PCK。桌面完整包另行授权、另行验收。

完整包已部署、通过真实设备验收后，兼容的小版本可运行：

```bash
bash tools/publish_hot_update.sh "$CONTENT_VERSION" "本次实际交付的更新说明"
```

脚本仅从 Android 已签名清单获取固定基线；受保护文件变化会拒绝小版本。旧入口 `publish_android_hot_update.sh` 是同一 Android-only 流程的兼容别名，不再处理 macOS。

## 发布前验收

1. 新完整 APK 全新安装、覆盖安装均可启动，真实设备菜单版本正确，旧存档保留。
2. 旧 APK 能看到完整包升级提示，不下载不兼容基线补丁；完整包覆盖后旧缓存不回退版本。
3. 新 APK 真实联网检查、下载兼容补丁，重启后显示新内容版本并加载补丁资源。
4. 错误签名、平台、架构、大小、SHA-256、底包版本及损坏缓存均被拒绝。
5. 断网/恢复、取消、重启和下载失败可重试，下载失败不破坏现有可运行内容。
6. 真机确认当前 HTTP 服务可以访问；主机上的 Android 平台模拟和静态 INTERNET 权限检查不能代替真机网络验收。

2026-09-18 的自动化和同号诊断构建见 [历史 QA](../qa/controls_update_20260918/README.md)，不能代替 2.0 验收。宿主 Godot 加载最终 APK 资源时须使用全新独占 profile，明确记录 Android 平台模拟；该检查不证明 Android 真机启动、覆盖安装或网络可用。通用流程及回滚见 [DESKTOP_RELEASE.md](DESKTOP_RELEASE.md)。
