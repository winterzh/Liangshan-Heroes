# Android 2.0 发布记录

## 已上线

发布源码/标签 `v2.0`：`9cf45c7204d3a3f6a31a3d3765b3bf5db8439a80`，分支 `codex/sync-20260905-stable`。GitHub Release 于 2026-09-25 16:00:28（UTC+8）公开，Android stable 已为 2.0；未合并 main、更新 Steam 或交付桌面包。

- [GitHub Release](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v2.0)
- [APK 直链](http://120.26.237.195:1234/liangshan/android/releases/LiangshanHeroes-v2.0.apk)
- APK 344,116,603 字节，SHA-256 `78a15c9e1e31b9fbcab2e09ab92f6bbbd6a62a1bcfef7e0896f9c19ab1c249c0`。
- 基线 PCK 315,958,024 字节，SHA-256 `05ee4bb3f04393c898986dd6f1d31483e4ba7fdbebbcfc07e04bd4f888d6e9b7`；不作为玩家下载附件。

`build/receipt.json`、`build/build-source.json` 记录官方 Godot 4.6.3、匹配 Android 模板、3064 生产输入、唯一人工模板路径覆盖和全部通过的构建步骤。沿用项目原有 debug 导出模板和证书以保持原流程与覆盖安装身份；APK 的 debuggable 标志仍为 true，本次未轮换签名或宣称经过商店签名/加固。版本与菜单不带 TEST。

独立核验 `build/lsh_android_v2_independent_20260925.json` 重算 APK 与基线 3290 个共同资源的实际内容 MD5，全部一致；APK 仅额外包含 `_cl_` 和 `assets.sparsepck`。3064 个源文件及私有覆盖哈希通过；16 个 UID 和一个 SVG 导入侧车为引擎生成元数据，已明列。首次把生成侧车误当源码漂移的过严检查失败原样保留，不隐去失败。

`publication/publication_receipt.json` 确认三平台签名、Android 新基线、GitHub 公开状态/正文/附件元数据以及两个入口整包下载哈希；Windows/macOS 清单与签名字节等于 `server_before/`。`apk_live_update.log` 使用最终 APK 的真实资源及内置公钥联网验签，结果 current 2.0；`legacy_live_update.log` 另外加载 `v1.8` tag 原样引导器（bootstrap 3），结果 full_update，完整包链接指向 2.0。两个检查均为私有宿主模拟，非手机验收。

构建首次调用曾因手动传入错误的 expected-commit 被前置门禁立即拒绝，尚未创建目录或输出；改为完整实际 SHA 后通过。发布后只补收据/文档，不移动标签或重建 APK。

2026-09-25 从 `7f4a67c0` 准备 2.0 / versionCode 16 / bootstrap 4。授权为 stable 源码、`v2.0` 标签、GitHub Release/APK、Android 更新服务器；不合并 main、不发布 Steam、不改桌面历史 stable。

## 本次修改

- 包、菜单、导出与更新基线统一 2.0，原包名和签名保留。
- 桌面运行时在缓存和 HTTPRequest 初始化前停用更新，平台 override 不能重启桌面导出更新器。
- 完整 APK 与 PCK 从同一生产白名单冻结副本导出；正式包无 TEST，来源证明只声明 Android。
- 签名发布、完整包回读、单 Android stable 提升和失败回滚；旧客户端安装完整 2.0 后再接收同基线累计补丁。

## 验证与发布状态

tag 前已完成以下验证；正式构建及公开回读完成后另加收据。测试和上传中间失败保留原始证据，不以脚本实现代替成功构建或上线。

- `source_qa/`：官方 Godot 4.6.3，10 组 740/740 项通过，3332 个冻结输入及 checkout 零漂移。
- `transport_b/report.json`：38/38 场景通过，包括签名 HTTP、下载/重启挂载、坏签名/大小/hash/平台/架构/跨基线/坏缓存拒绝，以及桌面缓存/网络关闭。1.8 迁移场景为当前引导器旧版本常量夹具；另只读确认正式 `v1.8` 引导器 bootstrap 为 3、公钥一致，其 min_bootstrap 分支兼容新完整包提示，不冒充旧 APK 真机实测。
- `release_policy.log`：Android-only 发布目标、来源证明、Git/tag/漂移检查、保护路径删除/改名、冻结导出、签名输入哈希、提升失败回滚与桌面历史不变全部通过。
- `server_before/`：发布前公网三平台 stable 清单与签名原字节。桌面均仍为 1.8；上线后按字节核对。

本地旧 1.8 来源证明已原样归档为 `build/updates/build-source-v1.8-3331e08b.json`，SHA-256 `3331e08bcf5b3c197ad3477a11519c46075cd86c2dbe71c59672f3260d3b5c51`。未覆盖旧安装包/基线，正式构建拒绝覆盖已有 canonical 输出。

首轮 `transport_a` 三个禁用策略场景通过；后续公网查询本身通过，但夹具遗留无效 JSON 哨兵产生解析错误，严格日志门禁拒绝整批。已修复夹具在逐文件比对后清理自己生成的哨兵。未改真实玩家目录。

## 边界

宿主模拟 Android 不等于手机安装、触控、网络、性能或生命周期验收。Android 不开放 Windows Steam 专属中途续玩和平台在线功能。旧电脑安装包不会因本次源码提交自动停用其旧更新器；旧服务器文件保留，新完整桌面包才使用新禁用策略。
