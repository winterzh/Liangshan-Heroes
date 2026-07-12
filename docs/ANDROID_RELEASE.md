# Android 完整包与热更新发布

本项目仅为 Android 启用在线内容更新。Windows、macOS 仍按原流程发布，不检查更新服务器。

## 架构

- GitHub Releases：只存放完整 APK。
- 更新服务器：`120.26.237.195:1234`，只存放签名清单和累计 Patch PCK。
- 基线 APK：`1.4.0`，`versionCode=10`，热更新引导器版本 `1`。
- 清单地址：`http://120.26.237.195:1234/liangshan/android/stable/manifest.json`
- 签名地址：`http://120.26.237.195:1234/liangshan/android/stable/manifest.sig`
- 补丁目录：`http://120.26.237.195:1234/liangshan/android/releases/`

服务器当前由已有 Flask 静态服务（端口 1234）提供文件。HTTP 本身不可信，因此客户端必须同时满足：

1. RSA-3072 清单签名有效；
2. PCK 文件大小与签名清单一致；
3. PCK SHA-256 与签名清单一致。

任何一步失败都不会加载补丁，也不会影响 APK 内的基础版本。

端口 1234 的服务已登记为 `/etc/systemd/system/pai.service` 并启用开机自启。服务器重启后可用以下命令检查：

```bash
systemctl status pai.service
curl -fsS http://127.0.0.1:1234/liangshan/android/stable/manifest.json
```

## 发布机密钥

以下文件不进入 Git：

```text
~/.config/liangshan-update/manifest-signing-private.pem
~/.config/liangshan-update/manifest-signing-public.pem
~/.ssh/liangshan_update_ed25519
```

私钥丢失后，现有客户端不会信任新补丁。必须离线备份 `manifest-signing-private.pem`。服务器只保存 SSH 公钥和基准 PCK，不保存清单签名私钥。

## 首次发布 1.4.0 完整基线

发布前先提交并推送全部源码，确认 `git status --short` 为空；GitHub Release 的 tag 必须对应这份源码。

只构建 Android，不会重新导出 Windows/macOS：

```bash
bash tools/build_android_release.sh
```

产物：

```text
build/LiangshanHeroes.apk
build/android-update/base-1.4.0.pck
```

发布 GitHub 完整 APK、服务器基线清单，并把基准 PCK 备份到服务器私有目录：

```bash
bash tools/publish_android_baseline.sh
```

基准 PCK 不提供给玩家下载，只用于以后计算累计差异。

### Android APK 签名注意

当前构建保持项目既有 Godot debug 签名，以便已安装 `1.3.5` 的设备覆盖安装 `1.4.0`。必须备份当前机器的 `~/.android/debug.keystore`；如果以后换 APK 签名，用户必须卸载旧包才能安装，应用存档也可能丢失。

## 发布普通热更新

适用于：

- GDScript、AI、技能、数值；
- 场景、关卡、UI；
- 图片、音效和其他 Godot 资源。

先完成代码修改和回归测试，然后使用递增内容版本：

```bash
bash tools/publish_android_hot_update.sh 1.4.1 "修复末波残敌与帧率问题"
```

脚本会自动：

1. 使用 `base-1.4.0.pck` 生成“1.4.0 基线到当前源码”的累计补丁；
2. 计算大小与 SHA-256；
3. 用本地 RSA 私钥签名清单；
4. 上传版本化 PCK；
5. 最后原子替换 stable 清单，避免客户端看到半套更新。

累计补丁意味着玩家从 1.4.0、1.4.1 或任何旧内容版本升级，都只下载最新的一个 PCK。

## 必须发布完整 APK 的修改

以下情况不能只发 PCK：

- Godot 引擎或 Android 导出模板升级；
- Android 权限、Manifest、包名、图标变化；
- 原生 `.so`、Android 插件变化；
- 热更新引导器协议发生不兼容变化。
- `project.godot` 或任何 Autoload 脚本变化（Autoload 在补丁装载前已经初始化，不能可靠覆盖）。

此时提高 APK `version/name`、`version/code` 和 `BOOTSTRAP_VERSION`，发布新的 GitHub APK，并把服务器清单的 `min_bootstrap` 提高。旧客户端会显示“需要更新完整 APK”，点击后打开 GitHub 下载页。

## 服务器目录

```text
/var/www/pAI/liangshan/android/stable/
  manifest.json
  manifest.sig

/var/www/pAI/liangshan/android/releases/
  patch-1.4.0-to-1.4.1.pck
  manifest-1.4.1.json
  manifest-1.4.1.sig

/root/liangshan-update-bases/
  base-1.4.0.pck
```

部署使用专用 SSH 密钥：

```bash
ssh -i ~/.ssh/liangshan_update_ed25519 root@120.26.237.195
```

脚本和文档中不得写入服务器密码。

## 回滚

补丁文件和每版清单都会保留。回滚只需把旧版签名清单恢复到 stable，必须同时恢复 JSON 和对应签名：

```bash
ssh -i ~/.ssh/liangshan_update_ed25519 root@120.26.237.195 \
  'install -m 644 /var/www/pAI/liangshan/android/releases/manifest-1.4.1.sig /var/www/pAI/liangshan/android/stable/manifest.sig && \
   install -m 644 /var/www/pAI/liangshan/android/releases/manifest-1.4.1.json /var/www/pAI/liangshan/android/stable/manifest.json'
```

先复制签名，最后替换 JSON。客户端只会接受签名匹配的完整清单。

## 发布检查

```bash
curl --noproxy '*' -fsS \
  http://120.26.237.195:1234/liangshan/android/stable/manifest.json

curl --noproxy '*' -fsS \
  http://120.26.237.195:1234/liangshan/android/stable/manifest.sig
```

Android 端主菜单左下角显示检查和下载状态；“更多”中可以手动检查。下载完成后退出并重新打开，补丁会在其他 Autoload 和场景加载前生效。
