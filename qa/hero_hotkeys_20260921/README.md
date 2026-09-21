# F1～F8 连续英雄选择 · 2026-09-21

用户明确取消 F2 全军，要求连续 F1～F8。本批基于 `a9821c564b20293f7ec8929707a336145d3864f8`，没有改伤害、AI、版本或发布平台。

## 变化

- F1～F8 直接选择固定名册的第 1～8 位英雄，与头像键帽一致。F2 不再跳过；F8 可选择第八位。
- 删除键盘 `select_army` 动作、默认值、设置面板改键行与快捷键说明；屏幕“全军”按钮保留。
- 全部 F1～F8 禁止被其他命令重绑。英雄输入排在普通命令之前，异常旧字典中的 F2 技能绑定也不能抢走英雄键。
- 旧 `settings.cfg` 中的全军条目忽略；曾经换到 F2 的其他操作退回默认，顺着冲突链恢复其他受影响动作，保留无关自定义和音量。无需删除旧设置。未在主工程运行加载/保存夹具。
- Ctrl/⌘+F1～F4 存镜头、Shift+F1～F4 跳镜头保持原行为；未定义组合键没有另加规则。阵亡/空槽不选替补、不让其他英雄换位。

## 验证

冻结批 `/tmp/lsh-hero-hotkeys-20260921-r2`：**557 项通过**，含专项93 + 原有464；来源与工作区/副本均零漂移。原始总收据见 `source-receipt.json`，专项日志/结果见 `hero_function_keys_qa.log`、`hero-function-keys-result.json`。

专项实际调用 `Battle._unhandled_input`，不是只测索引函数：逐个 F1～F8、F2 从全军转为第二英雄、空槽/阵亡、按键抬起/重复、旧 F2 交换链、默认重置/保留键、桌面及触屏两处实际头像键帽、镜头组合键均覆盖。场景为私有暂停的真实 1v1，含出生/致死夹具，不算自然对局或真机输入验收。

首批 r1 的生产输入、迁移和旧464项均通过；新 HUD 夹具错误访问桌面尚未创建的触屏栏导致专项失败。仅修复测试工具：先测桌面，再通过真实触屏切换入口创建技能栏，最后恢复桌面；没有更改生产 HUD。保留 `initial-hero-function-keys-result.json`，未将失败批计入557项。

## 四语与来源保留

设置概要改为 F1～F8，去掉键盘全军说明，简中/繁中/英/日及占位符检查通过。生成词库仅删除两条旧快捷键 key、加入两条新 key，其余所有译文值与基线相同。

首次重建发现前批57条 RTS 译文只有运行时 catalog、没有来源分片。已从基线逐项原样恢复至 `assets/localization/zz_rts_refinement_20260920.json`；构建工具对显式提供的繁体保留原值，其余仍由 OpenCC 生成。57条三种译文逐字一致，未借此改写旧翻译。全库有8条原有缺译项，与基线集合完全相同，不能把本批“无新增缺译”当全库全覆盖。

```sh
python3 tools/build_localization.py --opencc-path /absolute/dependency/path --strict
python3 tools/localization_catalog.py --validate assets/localization/catalog.json
python3 tools/run_rts_refinement_qa.py --godot "$GODOT_PATH" \
  --out /absolute/new/directory/outside/checkout
```

本轮不重跑手机分辨率矩阵或60波性能，因为没有改布局计算/战斗循环；原触屏适配边界仍以 [前批 QA](../rts_foundation_20260920/README.md) 为准。

## 最新 Mac 测试包

- 冻结生产提交 `55089263e68376d831ce9ef2327163fc2a432dbd`，3062份生产来源逐一匹配 Git blob、构建 SHA，私有覆盖层外零漂移。
- 本机目录 `build/macos-test-20260921-hotkeys/`：双击 `水浒英雄传-TEST-20260921-55089263.app`；同名 DMG 386,667,685 字节。
- 菜单左下 `TEST 0921-55089263`，独立 profile `LSH-macos-test-20260921-55089263`，更新器停用。此包不读取旧测试包或正式包的设置/进度；旧设置迁移另在功能专项真实 `_load` 中验证。
- Universal（arm64/x86_64），Godot 4.6.1；本机 Apple M4 Max / Metal 实际 App 主入口录帧4帧、退出0，截图 `macos-menu.png` 已目检。未验证 Intel 或 Apple 公证。
- 实际 PCK 由原生 Godot 宿主 `--main-pack` 加载，39项通过，包含菜单身份、隔离、血瓶恢复/消耗。报告 mode 是 `packed_resources_native_host`，不冒称 release 二进制执行了外部脚本。全键映射由上述93项源码冻结批验证，包内来源完全匹配该提交。
- 严格 ad-hoc 验签和 `hdiutil verify` 通过。正常定帧退出仍有音频实例残留提示，日志保留，不宣称零警告或真人整场验收。
- DMG SHA-256：`029e3efdda93640d28ce043e0c5f9ff586c734a48e05ba43cdbd5cba2dd2361a`。
- PCK SHA-256：`dc50c521ac24f9c4fddc9dfacb32c45fe8d4a1695fe65fd3eddd2c04f2f0be5f`。

构建原始收据 `macos-build-receipt.json`，后续启动收据 `macos-handoff.json`，包内宿主结果 `macos-packed-host-result.json`。构建收据的 `native_launch_tested=false` 保留其“构建工具本身未负责启动”的原意，启动另有收据。完整私有目录 `/tmp/lsh-macos-hotkeys-20260921-55089263/`。旧 e3be6474 包保留历史，不再作为本次修改的测试入口；不创建 Release、不更新 Steam/服务器。
