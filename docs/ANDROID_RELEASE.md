# Android 完整包与内容更新发布

## 当前规则（2026-09-18）

安卓继续支持签名 PCK 差异更新；Windows EXE 暂停应用内更新，macOS 通道保留。当前源码引导协议为 `4`，包版本仍为 `1.8` / `versionCode=15`，本轮只是修复与诊断导出，没有发布新版。线上 Android stable 的历史版本仍为 `1.8`（2026-09-18 只读回读结果）。

**下一次正式发布必须先发新的完整 APK，不能把当前工程直接制成旧 1.8 客户端的内容补丁。** 工程新增的 Autoload、工程配置及更新引导器不能通过旧进程挂载 PCK 完整替换。下一次完整版本应使用新的两段式版本号、更高的 Android versionCode、现有签名证书；不要把本轮同号诊断候选当作正式更新包。

- 完整发包：`vX.X`，EXE、DMG、APK 的版本保持一致。
- 差异内容更新：`vX.X.X`，仅针对兼容底包的 Android/macOS；不创建新安装包，不发布 Windows PCK。
- Godot、Autoload/工程配置、导出配置、引导器或原生库变化，必须发下一个完整版本。
- 客户端仅内置验签公钥；私钥、SSH 密钥、签名材料不得提交到仓库。

## 新完整包基线

以用户确认的下一完整版本为准，同步 `Campaign.VERSION`、`export_presets.cfg`、`scripts/android_updater.gd`、`tools/update_release.env`，并提高 Android versionCode。Android 新完整基线的清单必须是：

- `packaged_base.version` / `patch_base.version` 均为新完整版本，两份描述的大小和 SHA-256 一致。
- `patch: null`，`min_bootstrap: 4`（以后协议升级时相应提高）。
- `full_package` 与兼容字段 `full_apk` 指向同一完整 APK，大小和 SHA-256 可公网回读验证。

旧客户端应提示安装完整 APK，不再生成 `1.4.0 → 新工程` 的跨工程累计补丁。历史 1.8 服务器文件保留原样；`base-1.4.0.pck` 只属于历史发布线，不能作为新完整版本的基线。

完整版本内的小更新仍是**从该完整基线到最新内容版本的累计差异**，因此不用逐版下载。差异包不是 APK 二进制差分，也不会替换安装包自身。

## 构建与发布

先验证源码、更新交接记录，按文件白名单提交并推送 `codex/sync-20260905-stable`。不得自行直接推 main、合并、创建 Release 或更新服务器；正式发布仍需当次授权。授权后在同一已验证提交创建版本 tag，完整构建要求工作区干净且 HEAD 精确匹配 tag：

```bash
bash tools/build_packages.sh "$VERSION"
```

产物包括三个完整包、各平台 `base-X.X.pck` 和绑定 tag/提交/大小/哈希的 `build/updates/build-source.json`。APK 必须校验包名 `com.liangshan.heroes`、arm64、versionName/versionCode 和既有证书，保证覆盖安装身份不变。

三端完整包上传 GitHub Release、确认公网三包哈希后：

```bash
bash tools/publish_update_baseline.sh "$VERSION" "本次实际交付的更新说明"
```

脚本仅上传 Android/macOS 更新清单与不可变基线、镜像完整 APK、回读验签/验哈希，再一起提升这两个 stable；失败回滚这两个通道。Windows 历史 stable 不读写，不发新 PCK。历史 `publish_android_baseline.sh` 已禁用。

完整包已部署、通过真实设备验收后，兼容的小版本可运行：

```bash
bash tools/publish_hot_update.sh "$CONTENT_VERSION" "本次实际交付的更新说明"
```

脚本从已签名清单获取平台固定基线；受保护文件变化会拒绝小版本。旧入口 `publish_android_hot_update.sh` 是 Android/macOS 共用流程的兼容别名，不是只发 Android。

## 发布前验收

1. 新完整 APK 全新安装、覆盖安装均可启动，真实设备菜单版本正确，旧存档保留。
2. 旧 APK 能看到完整包升级提示，不下载不兼容基线补丁；完整包覆盖后旧缓存不回退版本。
3. 新 APK 真实联网检查、下载兼容补丁，重启后显示新内容版本并加载补丁资源。
4. 错误签名、平台、架构、大小、SHA-256、底包版本及损坏缓存均被拒绝。
5. 断网/恢复、取消、重启和下载失败可重试，下载失败不破坏现有可运行内容。
6. 真机确认当前 HTTP 服务可以访问；主机上的 Android 平台模拟和静态 INTERNET 权限检查不能代替真机网络验收。

本轮自动化、诊断构建与尚未完成的真机验证见 [QA 记录](../qa/controls_update_20260918/README.md)。通用流程及回滚见 [DESKTOP_RELEASE.md](DESKTOP_RELEASE.md)。
