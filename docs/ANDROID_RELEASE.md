# Android 完整包与热更新发布

本项目只在 Android 上检查内容更新。Windows 和 macOS 仍按普通完整包发布，不访问更新服务器。

## 当前版本和基线

- 当前完整 APK：`1.5`，`versionCode=11`，热更新引导器版本 `1`。
- GitHub APK：`https://github.com/winterzh/Liangshan-Heroes/releases/download/v1.5/LiangshanHeroes-v1.5.apk`
- 累计补丁基线：`base-1.4.0.pck`。
- 基线 SHA-256：`d2198b09743d692041c6a5b976a6c3f58943f1955086f5332f9395e6e1a144de`。
- 清单：`http://120.26.237.195:1234/liangshan/android/stable/manifest.json`
- 签名：`http://120.26.237.195:1234/liangshan/android/stable/manifest.sig`
- 补丁目录：`http://120.26.237.195:1234/liangshan/android/releases/`

`base-1.4.0.pck` 是已发布客户端的固定差异基线，不能用新导出物覆盖。`tools/publish_android_hot_update.sh` 在生成补丁前会校验上述 SHA-256，校验不一致时直接停止发布。

1.4.x 客户端与 1.5 使用同一版引导协议，因此旧 APK 可直接下载从 1.4.0 计算的 1.5 累计补丁。新安装的 1.5 APK 已自带 1.5 内容；它在启动时会删除用户目录中内容版本小于或等于 1.5 的旧补丁，防止覆盖安装后又被旧 PCK 回退资源。

## 验证机制

服务器由 Flask 静态服务在 1234 端口提供文件。HTTP 传输本身不作为信任依据，客户端会依次检查：

1. RSA-3072 清单签名；
2. PCK 文件大小；
3. PCK SHA-256。

任何一项失败都不会加载补丁，APK 内的基础内容仍可启动。服务器保留了 `/etc/systemd/system/pai.service` 并设置开机自启，但发布前应以实际端口和 HTTP 检查为准；当前 1234 端口可能由既有手工进程提供，不要在发包过程中贸然重启服务：

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
~/Library/Application Support/Godot/keystores/debug.keystore
```

必须离线备份 `manifest-signing-private.pem` 和当前 APK 实际使用的 `~/Library/Application Support/Godot/keystores/debug.keystore`。不要误用本机另一枚 `~/.android/debug.keystore`。当前兼容旧安装所需的 signer SHA-256 固定为 `5d1a80e66ce545a69acb6e2ffc7c22d61d0c62961ac44a9b0b9619888196ac54`，构建脚本会校验它。丢失清单私钥后，已发布客户端不会信任新补丁；更换 APK 签名后，旧安装也无法直接覆盖升级。服务器只保存 SSH 公钥和基准 PCK，不保存清单签名私钥。

## 发布 1.5 完整 APK

先提交和推送全部源码，保证 `v1.5` tag 指向实际打包的提交。只导出 Android 时运行：

```bash
bash tools/build_android_release.sh
cp build/LiangshanHeroes.apk build/LiangshanHeroes-v1.5.apk
```

产物包括：

```text
build/LiangshanHeroes-v1.5.apk
build/android-update/base-1.5.pck
```

`base-1.5.pck` 只是完整包内容留档，本轮累计补丁仍使用不可变的 `base-1.4.0.pck`。不要重新运行历史基线发布脚本去覆盖服务器上的 1.4.0 基准。该脚本也会强制校验 APK 必须是 `1.4.0/code 10`、PCK 必须命中固定 SHA-256，以防新包被误传到历史 Release。

发包前至少检查 APK 版本、CPU 架构和签名证书是否与上一版一致。GitHub Release 中的 APK 文件名必须是 `LiangshanHeroes-v1.5.apk`，否则更新清单中的完整包链接会失效。

## 发布 1.5 累计补丁

先确认 GitHub 上的 `LiangshanHeroes-v1.5.apk` 已可下载，再更新 stable 清单：

```bash
bash tools/publish_android_hot_update.sh 1.5 "宋江杏黄旗技能与战斗数值更新"
```

脚本会使用 `base-1.4.0.pck` 生成 `patch-1.4.0-to-1.5.pck`，校验基线和补丁哈希，签名清单，上传版本化文件，最后替换 stable 清单。补丁是“1.4.0 基线到当前源码”的累计差异，玩家无需逐版下载 1.4.1、1.4.2 等中间包。

后续普通内容更新可使用三段版本号：

```bash
bash tools/publish_android_hot_update.sh 1.5.1 "修复战斗问题"
```

适合热更新的内容包括 GDScript、AI、技能、数值、场景、关卡、UI 和 Godot 资源。

## 必须发完整 APK 的修改

以下变更不能只发 PCK：

- Godot 引擎或 Android 导出模板升级；
- Android 权限、Manifest、包名或图标变化；
- 原生 `.so` 或 Android 插件变化；
- `project.godot` 或 Autoload 脚本变化，因为 Autoload 在补丁装载前已经初始化；
- 热更新协议发生不兼容变化。

兼容的引导器修复也要随完整 APK 发布，但可保持 `BOOTSTRAP_VERSION` 不变，让旧客户端继续接收累计补丁。只有协议不再兼容时，才同时提高 APK `version/name`、`version/code`、`BOOTSTRAP_VERSION` 和服务器清单的 `min_bootstrap`。旧客户端将改为提示下载完整 APK。

## 服务器目录

```text
/var/www/pAI/liangshan/android/stable/
  manifest.json
  manifest.sig

/var/www/pAI/liangshan/android/releases/
  patch-1.4.0-to-1.5.pck
  manifest-1.5.json
  manifest-1.5.sig

/root/liangshan-update-bases/
  base-1.4.0.pck
```

部署使用专用 SSH 密钥：

```bash
ssh -i ~/.ssh/liangshan_update_ed25519 root@120.26.237.195
```

脚本和文档中不得写入服务器密码。

## 回滚

服务器会保留每版补丁和清单。回滚时必须把 JSON 和对应签名一起恢复，先复制签名，最后替换 JSON：

```bash
ssh -i ~/.ssh/liangshan_update_ed25519 root@120.26.237.195 \
  'set -e; \
   install -m 644 /var/www/pAI/liangshan/android/releases/manifest-1.5.sig /var/www/pAI/liangshan/android/stable/manifest.sig; \
   install -m 644 /var/www/pAI/liangshan/android/releases/manifest-1.5.json /var/www/pAI/liangshan/android/stable/manifest.json'
```

## 发布后检查

```bash
curl --noproxy '*' -fsS \
  http://120.26.237.195:1234/liangshan/android/stable/manifest.json

curl --noproxy '*' -fsS \
  http://120.26.237.195:1234/liangshan/android/stable/manifest.sig
```

应同时检查清单中的 `content_version=1.5`、`full_apk.version_code=11`、补丁大小与 SHA-256，并确认 GitHub APK 链接返回成功。Android 主菜单左下角会显示检查和下载状态；下载完成后退出并重新打开，补丁会在其他 Autoload 和场景加载前生效。
