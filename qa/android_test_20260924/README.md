# Android 最新源码测试包（2026-09-24）

用户要求“拉下来最新代码然后编译 apk”。工作区干净时，将 `codex/sync-20260905-stable` 从 `0854f07b` 快进到 `391603074db1852a76c4e2279b21e7fa5a29af68`；没有合并或改写 main。此任务仅本地 APK，不创建 tag、GitHub Release、Steam 构建或服务器更新。

## 构建前验证

使用官方 Godot **4.6.3.stable.official.7d41c59c4**，在 `/tmp/lsh-android-source-qa-20260924-39160307` 冻结工程和独占用户目录运行现有完整 RTS 回归：**740/740** 通过，3332 份受测来源与副本/工作区均零漂移，无 SCRIPT ERROR / ERROR / WARNING。禁用 Steam 和自动更新，不重设 HOME，不访问玩家存档。

Godot 与安卓模板从官方固定版本获取，下载 SHA-256 与 GitHub release digest 一致；只解压到独立临时目录，不替换本机已安装的 4.6.1，不主动改全局编辑器设置。最终构建前后既有 editor settings 文件 SHA-256 一致。来源与摘要见 [toolchain.json](toolchain.json)。

## 交付状态

最终文件位于 Git 忽略的 `build/android-test-20260924-final/水浒英雄传-Android-TEST-20260924-39160307.apk`，**344,116,603 字节**（约 344 MB / 328 MiB）。SHA-256：`92c52b6c2a6b4bba2678082f3abd04959009cdd903d93585b3f582642f1fb646`。

- 包名 `com.liangshan.heroes`，versionName `1.8-test.20260924.39160307`，versionCode 15；菜单标记 `TEST 0924-39160307`。
- 原证书 SHA-256 `5d1a80e66ce545a69acb6e2ffc7c22d61d0c62961ac44a9b0b9619888196ac54`，apksigner 的 v2/v3 验证通过；沿用既有 debug 测试签名流程，不作为正式发布包。
- 冻结3064个生产文件，仅副本 `export_presets.cfg` 加测试 versionName/自定义官方模板路径，`scripts/menu.gd` 加可见标记。生产来源、获准覆盖后的副本、构建脚本及复用 helper 的摘要均匹配。
- APK ZIP CRC、3292个包内资源、arm64-v8a、INTERNET、版本与证书检查通过，无工具/QA/文档/签名材料进入游戏资源。
- 从最终 APK 解出的实际 assets 在全新独占 profile 中加载菜单，确认测试标记、Android 更新器模式/1.8基线、无已挂载补丁，Steam 与续玩入口关闭。5个构建/检查步骤全部退出0，日志无 SCRIPT ERROR / ERROR / WARNING。
- 独立复核再次比对生产来源、获准副本、APK与交付副本及收据，并逐文件核对3292个解包资源与实际探针目录，均一致。

完整构建证据见 [receipt.json](receipt.json)，源码回归见 [source-qa-receipt.json](source-qa-receipt.json)，最终包菜单检查见 [apk-menu-host.log](apk-menu-host.log)。APK 不随 Git 提交，也没有安装到手机或上传服务器。

原始日志按运行结果保留，包括测试标签末尾空格；源码及文档的空白检查通过，不为消除 Git 的原始日志空白提示而改写运行证据。

## 构建与失败记录

新增 `tools/build_android_test.py`，复用现有生产白名单/签名/资源检查，专门构建 Android 测试 APK。需要已配置的 SDK/JDK/原 debug 签名，并使用与 Godot 版本对应的官方模板；不创建正式基线、tag 或其他平台安装包。

```sh
python3 -B tools/build_android_test.py \
  --godot /path/to/Godot --android-sdk /path/to/sdk --java-home /path/to/jdk \
  --android-template /path/to/matching/android_debug.apk \
  --out /absolute/new/outside-checkout \
  --delivery-dir /absolute/checkout/build/new-android-test \
  --expected-commit 391603074db1852a76c4e2279b21e7fa5a29af68
```

首批在导出前发现 Android preset 没有预留 `custom_template/debug` 空键，工具的替换锚点失败；修复为只在副本 Android options 中插入。r2完整导出/检查通过，审阅又补上交付异常时的 `passed=false` 与工具自身来源守卫，随后用最终脚本重新冻结构建。唯一最终验收批为 `/tmp/lsh-android-test-20260924-39160307-final`；此前副本保留作诊断，不冒充最终验收。首批失败摘要见 [diagnostics.json](diagnostics.json)。

覆盖安装时不要先卸载旧应用；若系统提示签名/版本冲突，保留现有应用和提示。安装后先检查菜单测试标记，缺失时不要清除进度，先记录实际显示版本。

## 平台边界

Android 仍为 arm64-v8a。今日围栏修复属于共享玩法源码，包含在本批来源中；经典 30 波中途续玩仅向 Windows Steam 开放，APK 不开放该入口，也不启用 Steam SDK 功能。

保留原包名/证书/code 15 和更新器 1.8 基线，仅对冻结副本加测试版本标记；不是正式完整版本或补丁基线。宿主加载实际 APK 资源不等于手机安装、触摸输入、性能或原生网络验证。覆盖安装设备若已有合法的更高内容版本缓存，仍可能按原更新器规则挂载；测试版 versionName 本身不改变更新基线。不要为了安装清除玩家数据。
