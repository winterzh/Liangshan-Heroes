# Android 完整包与热更新发布

本项目只在 Android 上检查内容更新。Windows 和 macOS 仍按普通完整包发布，不访问更新服务器。

## 当前版本和基线

- 当前完整 APK：`1.5.2`，`versionCode=12`，热更新引导器版本 `1`。
- 当前内容补丁：`1.5.2`。从本版起完整包、Android APK 与热更新内容统一使用同一个版本号。
- GitHub APK：`https://github.com/winterzh/Liangshan-Heroes/releases/download/v1.5.2/LiangshanHeroes-v1.5.2.apk`
- 累计补丁基线：`base-1.4.0.pck`。
- 基线 SHA-256：`d2198b09743d692041c6a5b976a6c3f58943f1955086f5332f9395e6e1a144de`。
- 清单：`http://120.26.237.195:1234/liangshan/android/stable/manifest.json`
- 签名：`http://120.26.237.195:1234/liangshan/android/stable/manifest.sig`
- 补丁目录：`http://120.26.237.195:1234/liangshan/android/releases/`

`base-1.4.0.pck` 是已发布客户端的固定差异基线，不能用新导出物覆盖。`tools/publish_android_hot_update.sh` 在生成补丁前会校验上述 SHA-256，校验不一致时直接停止发布。

1.4.x、1.5.x 客户端使用同一版引导协议，因此旧 APK 可直接下载从 1.4.0 计算的累计补丁。新安装的 1.5.2 APK 已自带 1.5.2 内容；它在启动时会删除用户目录中内容版本小于或等于 1.5.2 的旧补丁，防止覆盖安装后又被旧 PCK 回退资源，并可继续加载 1.5.3 及更高内容版本。

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

## 发布 1.5.2 完整包

先完成回归并确认 Windows、macOS、Android 的版本配置均为 `1.5.2`，再提交、推送并创建 `v1.5.2` tag；构建必须从该 tag 所指向的干净提交进行。只导出 Android 时运行：

```bash
bash tools/build_android_release.sh
cp build/LiangshanHeroes.apk build/LiangshanHeroes-v1.5.2.apk
```

产物包括：

```text
build/LiangshanHeroes-v1.5.2.apk
build/android-update/base-1.5.2.pck
```

`base-1.5.2.pck` 只是完整包内容留档，本轮累计补丁仍使用不可变的 `base-1.4.0.pck`。不要重新运行历史基线发布脚本去覆盖服务器上的 1.4.0 基准。Android 构建脚本会强制校验 APK 为 `1.5.2/code 12`，并校验覆盖安装所需的签名证书。

发包前至少检查 APK 版本、CPU 架构和签名证书是否与上一版一致。GitHub Release 中的 APK 文件名必须是 `LiangshanHeroes-v1.5.2.apk`，否则更新清单中的完整包链接会失效。必须先让 GitHub APK 公网可下载，再发布热更新；发布脚本会用 HEAD 请求阻止清单提前切流量。

## 发布 1.5.2 累计补丁

先确认 GitHub 上的 `LiangshanHeroes-v1.5.2.apk` 已可下载，再更新 stable 清单：

```bash
bash tools/publish_android_hot_update.sh 1.5.2 "宋江忠义双旗、托管选点与战斗修复"
```

脚本会使用 `base-1.4.0.pck` 生成 `patch-1.4.0-to-1.5.2.pck`，校验基线和补丁哈希，签名清单，上传版本化文件，最后替换 stable 清单。补丁是“1.4.0 基线到当前源码”的累计差异，玩家无需逐版下载 1.4.1、1.5、1.5.1 等中间包。

不得用相同内容版本覆盖已经对外出现过的补丁。客户端只比较 `content_version`，已经安装某版内容的设备不会重新下载同名补丁；任何发布后的修正都必须使用更高版本。

后续普通内容更新可使用三段版本号：

```bash
bash tools/publish_android_hot_update.sh 1.5.3 "修复战斗问题"
```

适合热更新的内容包括普通 GDScript、AI、技能、数值、场景、关卡、UI 和 Godot 资源。但“文件已经被加载进缓存”和“PCK 已覆盖同路径文件”是两回事：`class_name`、Autoload 以及被 Autoload 提前引用的脚本必须按下节单独处理。

## GDScript 缓存兼容

1.4/1.5 引导器会在 `_init()` 中装载 PCK，但已发布包的首个 Autoload 曾引用 `Campaign.VERSION`，因此 Godot 会在装包前沿 `Campaign -> LevelBase -> GameMap -> Unit` 预载旧脚本。补丁在 `Battle._ready()` 生成任何单位前，用 `CACHE_MODE_IGNORE` 从补丁路径原位 reload `Unit`，并按内容版本在每个进程中只刷新一次。`CACHE_MODE_REPLACE` 对 Godot 4.6.1 的 GDScript 仍可能返回旧缓存，不能代替该处理。1.5.2 还会探测减伤、充能和来源型攻速光环 API，任何一项缺失都会明确报错。

以后若修改 `Campaign`、`LevelBase`、`GameMap`、`Unit` 或其他早载脚本，必须先用实际旧 APK/PCK 做下载、重启和实战回归。能安全原位刷新时显式刷新对应脚本；不能保证兼容时提高 `min_bootstrap`，让旧客户端安装完整 APK。当前源码也已去掉 AndroidUpdater 对项目全局类的测试引用，供下一版完整 APK 从源头减少早载依赖。

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
  patch-1.4.0-to-1.5.2.pck
  manifest-1.5.2.json
  manifest-1.5.2.sig

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
   install -m 644 /var/www/pAI/liangshan/android/releases/manifest-1.4.1.sig /var/www/pAI/liangshan/android/stable/manifest.sig; \
   install -m 644 /var/www/pAI/liangshan/android/releases/manifest-1.4.1.json /var/www/pAI/liangshan/android/stable/manifest.json'
```

回滚只会阻止尚未升级的设备继续取得新版；已经安装 1.5.2 的客户端不会自动降级。若已发布内容需要修正，应继续发布更高的内容版本。

## 发布后检查

```bash
curl --noproxy '*' -fsS \
  http://120.26.237.195:1234/liangshan/android/stable/manifest.json

curl --noproxy '*' -fsS \
  http://120.26.237.195:1234/liangshan/android/stable/manifest.sig
```

应同时检查清单中的 `content_version=1.5.2`、`full_apk.version_name=1.5.2`、`full_apk.version_code=12`、补丁大小与 SHA-256，并确认 GitHub APK 链接返回成功。Android 主菜单左下角会显示检查和下载状态；下载完成后退出并重新打开才会使用新内容。

发布完成不能只看当前源码启动成功，至少覆盖以下矩阵，并检查全程没有 `SCRIPT ERROR`、`Invalid call` 或补丁验签/哈希错误：

1. 原始 `base-1.4.0.pck` 无补丁启动，联网下载 1.5.2，重启后运行技能专项和一场战斗；
2. 已安装 1.4.1 的旧基包升级到 1.5.2；
3. 已安装 1.5.1 内容补丁的客户端升级到 1.5.2；
4. 完整 APK 1.5.2 启动时清除用户目录中版本小于或等于 1.5.2 的遗留补丁；
5. 旧基包加载 1.5.2 后，忠义双旗充能、视觉、减伤、回血、攻速和托管落点均正常。

旧基包回归时，日志中的 `unit_cache_refresh=true reduction_api=true charge_api=true aura_speed_api=true`、忠义旗 `charge/variant/rank/reduce/loyalty/righteous/overlap/downgrade/aura_restore/exit/despawn` 全为 `true`，且托管专项 `ALL=true`，才可切换 stable 清单。
