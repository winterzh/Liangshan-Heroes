# Android 完整包与内容更新发布

Android 已纳入三端统一更新链。当前完整基线为 `v1.7`，`versionName=1.7`、`versionCode=14`、更新引导协议为 `3`。

版本规则：

- 完整发包使用两段式 `vX.X`，例如 `v1.7`。Windows、macOS、Android 必须同版。
- 不重发安装包的差异更新使用三段式 `vX.X.X`，例如 `v1.7.1`。三端内容版本一起提升。
- 更换 Godot、更新引导器、工程配置、导出配置或原生库时，必须发下一个 `vX.X` 完整包。

## v1.7 修复后三端基线

Android v1.4.x/v1.5.x 已有可用的旧引导器，因此服务器继续生成 `base-1.4.0.pck -> 1.7` 的累计补丁，旧 APK 不需逐版升级。v1.6 新安装包的通用更新器因 feature tag 判断错误会被关闭，需要安装 v1.7 完整包修复。

完整 APK 同时发布到：

- GitHub Release：`LiangshanHeroes-v1.7.apk`
- 更新服务器：`http://120.26.237.195:1234/liangshan/android/releases/LiangshanHeroes-v1.7.apk`

客户端仅内置清单验签公钥。私钥、SSH 密钥和 Android 签名材料只保存在发布机，不得入库或上传到安装包以外的公开位置。

## 构建完整包

先同步版本号，完成源码回归，再提交、推送并创建同一提交上的 `v1.7` tag。构建脚本只允许在干净工作区且 HEAD 精确指向 tag 时运行：

```bash
bash tools/build_packages.sh 1.7
```

它会生成：

```text
build/LiangshanHeroes-v1.7.apk
build/updates/android/base-1.7.pck
build/updates/build-source.json
```

APK 会校验 `versionName/versionCode`、arm64 和已有签名证书，以保证可覆盖安装。`build-source.json` 绑定 tag 提交与三端六个产物的大小/SHA-256，发布脚本会重新验证。

## 发布完整基线

先把三个完整包上传到 GitHub Release，确认公网可下载后运行：

```bash
bash tools/publish_update_baseline.sh 1.7 "修复三端导出程序未启动更新器"
```

脚本会：

1. 校验 tag、构建来源证明和 GitHub 三包哈希。
2. 取回不可变的 Android 1.4.0 基线，生成到 1.7 的累计 PCK。
3. 生成带 `platform=android`、`architecture=arm64` 的签名清单。
4. 镜像完整 APK，上传版本化清单/补丁，并从公网回读验签、大小和 SHA-256。
5. 与 Windows/macOS 一起提升 stable；任一端失败时回滚三端旧清单。

历史脚本 `publish_android_baseline.sh` 已禁用，不得重发 1.4.0 stable。

## 发布 v1.7.1 及以后小版本

小版本也要先提交、推送并创建同提交 tag，然后运行：

```bash
bash tools/publish_hot_update.sh 1.7.1 "更新说明"
```

Android 始终从不可变的 1.4.0 基线生成累计补丁，因此旧 APK 也可直升最新小版本。脚本会拒绝与当前 `v1.7` 发布线不一致的版本，也会拒绝必须改发完整包的受保护文件。

## Android 回归矩阵

每次正式切 stable 前至少检查：

1. 全新安装 v1.7 APK，菜单显示内容 1.7 且真实导出程序会请求 stable 清单。
2. v1.4.0、v1.5.2 旧 APK 均能发现/下载累计补丁，重启后显示内容 1.7。
3. 覆盖安装 v1.7 后，不会再被用户目录中的旧 PCK 回退。
4. 破坏签名、大小、SHA-256、平台或架构任一字段时，客户端必须拒绝。
5. 旧引导器加载新 PCK 后，技能充能、忠义双旗、减伤/攻速来源和托管落点全部正常。

旧 Android 引导器的 Autoload 实例不会被 PCK 替换，因此 `AndroidUpdater` 名称、旧常量、旧环境变量和 `full_apk/open_full_apk()` 兼容入口不能删除。新菜单对新方法使用动态检查，以保证旧 APK 加载新菜单不崩溃。

三端通用流程、回滚和服务器目录见 [DESKTOP_RELEASE.md](DESKTOP_RELEASE.md)。
