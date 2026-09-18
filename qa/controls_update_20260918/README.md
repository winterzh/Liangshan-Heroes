# 操作修复、平台导出与安卓更新检查（2026-09-18）

本轮按用户要求修复审查中确认的八处问题，检查 Windows EXE / Android APK 生成和安卓在线更新，暂停 EXE 应用内更新。源码基点为 `03ef62bdc387e2783e5459243573a0ff25024c8a`，目标分支 `codex/sync-20260905-stable`。本记录随修复代码白名单提交；不是上线收据。

## 修复与对应证据

| 问题 | 修复 | 回归 |
| --- | --- | --- |
| 手机底栏在初始化后不恢复 | 按最终触屏模式重新计算折叠状态，保留桌面空选折叠 | 触屏冷启动、英雄/工人/建筑选择及桌面恢复 |
| 紧凑技能按钮的升级加号点不中 | 绘制与命中共用几何，保留小范围触摸容差 | 紧凑/普通按钮可见加号中心命中 |
| 双指触摸时镜头误滚动 | 模拟鼠标不退出触屏模式；真实鼠标可恢复边缘滚屏 | 真实输入事件分发、双指和鼠标切换 |
| 高攻速重置动作导致普攻不出伤害 | 攻击动画/伤害点和攻击 CD 使用同一攻速倍率 | 五种武器 × 四档攻速，自然 Unit/Projectile tick |
| 近战停在建筑旁边无法攻击 | 攻击距离按实际注册占地边缘计算，同时验证接近线段 | 房屋/大厅、正面/斜角、AI 拆障、墙/水陆/单位阻挡 |
| 多角色先到任务点却丢失指令 | 仅续期有效任务到达凭证，索敌/托管/受击反击不抢走等待 | 串行办理、主动取消/停止/离场/阻断/换阶段、普通移动、嘲讽 |
| 高俅登岸后空船沉没导致押俘失败 | 只在登岸前要求运输船存活，完成封港后不追溯封港船损失 | 空船死亡、真人质死亡、封港前/后、实际上岸与送达 |
| 竞技场回菜单再进战役仍沿用旧模式 | 战役卡片启动显式清空 arena 旗标 | 实际菜单按钮回调 |

没有改技能数值、美术或存档格式。任务等待没有全局关闭 AI 或反击，只保护仍有效的现场任务；新命令和嘲讽仍有效。

## 自动化结果

- [输入报告](input_controls.json)：122/122 通过。
- [战斗日志](combat_controls.log)：95/95 通过。武松 8 秒的 1/1.9/3.42 倍攻速实际命中为 10/19/34 次；真实醉酒加旗组合在 1.2 秒内命中 5 次，保留刀攻击样式。
- [战役日志](campaign_controls.log)：32/32 通过，包括真实 AI tick 与敌方弓箭伤害下的任务等待。以上共 249 项。
- [原有自检](combat_selftests.log)：物品与战斗统计 ALL=true，108 英雄/432 技能施放无崩溃，468 个技能说明渲染成功，kit2 14/14；初始场景无英雄/少单位的两项为日志声明的跳过，不计通过数量。
- [更新链路](update_transport.json)：34/34 通过。离线 `tools/update_release_policy_qa.py` 也通过，包括 shell 语法、Windows 发布排除、三端完整包只读验证、bootstrap 4、新安卓基线与导出过滤。

本机使用 Godot `4.6.1.stable.official.14d19694e`。玩法测试是私有副本中的无界面边界测试和自然 tick，不是本轮八关真人通关、60 波整场压力测试或手机视觉验收。受控敌人/地形/耐久夹具在各脚本注释中说明，没有通过直接调用命中函数伪造攻速结果。

## 更新链路与发布边界

Windows 在 `_init` 中先于网络及缓存加载返回 disabled，原生 Windows feature 不受测试平台覆盖变量影响；菜单不显示更新功能，旧缓存保留但不挂载。发布工具仅上传/提升 Android 与 macOS，Windows 历史 stable 不改；完整 Release 的 Windows 包仍做只读哈希验证。既有旧 EXE 需换装新 EXE 才会获得停用逻辑，Steam 自身更新不受影响。

安卓 bootstrap 升为 4。新完整包的 `packaged_base` / `patch_base` 均绑定自己的完整版本，之后小更新从该固定基线累计生成。下载前和启动缓存挂载前都校验两份描述的版本、大小/hash一致性；跨完整底包、缺失描述、历史 1.4.0 链及错误类型拒绝。版本由签名发布证据绑定不可变基线；客户端不重新计算安装包对应的完整基线 PCK 哈希，因此禁止同版本号重打不同底包仍是必需约束。

34 项回归包含真实 HTTP 下载、RSA 验签、平台/架构错误、大小/hash错误、更高 bootstrap、跨底包/缺底包/旧链/描述冲突、正常下载保存、新进程 PCK marker 资源挂载、损坏缓存与签名有效但底包不兼容的缓存拒绝。测试密钥只写入隔离副本，不接触生产签名私钥，也不提交私钥。

2026-09-18 公网只读回读：Android stable 仍为 `1.8`，清单记录发布时间 `2026-08-10T10:04:07+00:00`，生产公钥验签成功；历史补丁 1,672,532 字节、SHA-256 `6833974c5f5961599f6c2a29fabcc96143445e54caf4775ad0c13a15bc509ba5`。同版旧清单仅显示已是最新，不引导回装旧 APK。线上没有这轮修复。

当前工程较旧 APK 的 Autoload/工程配置已变化，下一次发布必须先给新两段版本的完整 APK，提高 versionCode，保持证书一致；不能把本轮源码直接热推给 1.8/更早客户端。本轮不改正式版本号、不创建 tag、不推安装包、不改服务器、不发布 Steam。

## 实际导出

最终 [导出收据摘要](platform_exports.json) 绑定 3,057 个白名单源码文件，源码树摘要 `00ee85c8ee540b1e0da3773b5d7644e4cec4b20a0fe5680bc4a0b9e93969691d`，导出前后清单和源码哈希不变。最后一轮包含跨底包守卫，替代此前所有候选。

| 项目 | Windows | Android |
| --- | --- | --- |
| 实际产物 | EXE，420,665,288 字节 | APK，343,927,284 字节 |
| 架构/版本 | x86_64 / 1.8.0.0 | arm64-v8a / 1.8 / code 15 |
| 包校验 | 3,280 资源；实际内嵌 PCK 由宿主 Godot 加载真实菜单/字体 | 3,282 资源；包名 com.liangshan.heroes；v2/v3 签名验证通过 |
| 原生运行 | 未运行 Windows EXE | 未安装或启动 APK |

两包未包含测试工具、QA、文档以及验证器所禁止的来源/提示词目录。APK 的证书 SHA 与既有证书一致，INTERNET 权限存在；未显式声明 cleartextTraffic，这不作为原生 Godot HTTP 成功或失败的推断。EXE 无 Authenticode 签名；APK 按现有 debug 导出签名流程构建，只是诊断候选。不会把这些同号候选当作已发布新版，也不把单文件 EXE 当 Steam 专用候选。

本机尝试启动全新隔离 Android AVD（Android 36.1 arm64），报 `hvf is not enabled on this aarch64 host` 与 `mprotect failed: Permission denied`，adb offline；已关闭本次自建进程，未启动/修改原有 AVD，未安装 APK。故 Windows 原生启动、Android 真机安装/覆盖/运行/HTTP 网络及操作手感仍待目标设备验收，不能用本机平台模拟替代。

## 复现与原始文件位置

先按 `docs/SOURCE_SETUP.md` 配置 Godot。玩法测试应复制到新的独立目录，在副本 `override.cfg` 设置 `application/config/use_custom_user_dir=true` 与唯一 `LSH-*` 名称；使用 `STEAM_DISABLED=1 CAMPAIGN_QA=1 LSH_LANGUAGE=zh_CN`。输入回归还要求 `LSH_INPUT_QA_PROJECT` 和 `LSH_INPUT_QA_PROFILE` 与实际副本/用户目录完全相符；不要重定向 HOME，不要对真实玩家目录运行夹具。

```bash
"$GODOT_PATH" --headless --path "$PRIVATE_PROJECT" --script res://tools/input_controls_regression_qa.gd
"$GODOT_PATH" --headless --path "$PRIVATE_PROJECT" --script res://tools/combat_controls_regression_qa.gd
"$GODOT_PATH" --headless --path "$PRIVATE_PROJECT" --script res://tools/campaign_controls_regression_qa.gd
python3 tools/update_release_policy_qa.py
python3 tools/run_update_transport_qa.py --godot "$GODOT_PATH" --out "$NEW_QA_OUT" --live
python3 tools/verify_platform_exports.py --godot "$GODOT_PATH" \
  --android-sdk "$ANDROID_SDK_ROOT" --java-home "$JAVA_HOME" --build
```

本机原始结果位于 `/tmp/lsh-code-review-hYq7LL/`、`/tmp/lsh-update-baseline-8c721b/`、`/tmp/lsh-platform-exports-4tkzk3tm/`、`/tmp/lsh-platform-avd.d7EAP2/`；临时目录不是长期交付位置。这里只归档小型报告/日志，不提交私钥、安装包、缓存或全量源码副本。正式发布应重新按发布 guard 生成同提交版本化产物，不复用这些候选。
