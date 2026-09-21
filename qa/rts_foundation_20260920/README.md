# RTS 综合修复 QA（2026-09-20 批次，09-21 收尾）

最终统一批位于 `/tmp/lsh-rts-refinement-20260920-final`，Godot 4.6.1，独立用户目录 `LSH-rts-refinement-lsh-rts-refinement-20260920-final`。通过生产白名单冻结 3324 份源码、资源及测试工具，导入及所有套件退出码为 0；私有副本与工作区来源 SHA 均零漂移。详见 [冻结收据](source-receipt.json)。

| 套件 | 通过项数 | 证据 |
| --- | ---: | --- |
| 基础命令、巡逻、据守、相机、改采及取消交接 | 47 | [报告](foundation-result.json) |
| 1v1 经济、真实生产/研究和阵营隔离 | 66 | [日志及结果](rts_economy_rules_qa.log) |
| 英雄选择、血瓶、真实复活、物品移交及手动施法 | 64 | [报告](hero-items-result.json) |
| HUD v1/v2 验证与实际活/死英雄捕获 | 38 | [报告](hud-snapshot-result.json) |
| 既有输入回归 | 122 | [报告](input_controls_regression_report.json) |
| 既有战斗回归 | 95 | [日志](combat_controls_regression_qa.log) |
| 既有战役操作回归 | 32 | [日志](campaign_controls_regression_qa.log) |
| 功能合计 | **464** | 全部通过 |
| 原生尺寸图形布局/四语状态 | **173 个样本** | [布局收据](touch-layout-report.json) · [日志](touch_visual.log) |

没有脚本错误或解析错误；图形兼容渲染只有已知的 `2D MSAA is not yet supported for GLES3` 警告，不计原生安卓 FPS 或 MSAA 验收。功能断言数与图形样本数口径不同，不相加包装为性能/真机测试。

## 代表截图与设备

- [小米 12S Ultra，3200×1440，安全区＋信息与物品同开](touch_xiaomi_12s_ultra_safe_both.png)
- [vivo X300 Ultra，3168×1440，全员托管＋瞄准时操作行](touch_vivo_x300_ultra_safe_auto_aiming.png)
- [联想 Y900 13 2026，3840×2560，安全区＋信息与物品同开](touch_lenovo_y900_13_2026_safe_both.png)

按实际机型区分新 Y900 13 的 3:2 与旧 Y900 14.5 的 3000×1876；保留旧款、通用 16:10、4:3 和 PC 作为附加覆盖。六英雄每人四技能、全部操作按钮、各浮层、安全区、托管/瞄准/死亡及四语均纳入检查。完整 173 张原生 PNG 只留私有输出，入库仅三张与本次要求直接相关的代表图；截图是固定场景夹具，不是自然战役通关。

同一份最终 HUD 已由主代理目检三个目标机型和英文本地化操作行；专项代理另目检死亡行、桌面、工人和训练说明。图形模式与手指操作、系统 DPI/手势、安全区实报仍有差别，不能据此保证未接入的实体设备已验证。

## 其他证据与限制

- [四语文案/菜单验证](economy_localization_check.json)：57 新键、171 条译文，原键不改；八张四语菜单图在独立开发副本目检。该记录的源码 SHA 是当时检查点；最终生产来源以统一收据为准。后续修改没有新增文案键。
- 血瓶测试用真实最大生命与物品按钮，1×：`HP 1→265 / Max 320`；3×：`1→307.6667 / Max 533.3333`。实际消耗一瓶，满血不扣，近满血封顶；实际死亡并完成付费复活队列验证补瓶、保留堆叠和满栏不覆盖。
- AI 经济包含 180 秒自然 tick 的局部经营样本，不是长期难度平衡或 60 波通关。全局托管不会自动喝药。
- HUD 快照测试显式 `full_save_continue=false`，使用真实 HUD 与验证器，捕获门禁的 HELD 边界由夹具提供；不是完整世界保存/继续。
- 开发时真实堵墙复现了“走近失败转待机后仍返回旧锚点”，[修复前日志](foundation-idle-before.log)保留两项失败；最终 47 项包含该问题的通过回归。其他早期布局失败/迭代图留在 `/tmp/lsh-rts-hud-fix-20260920-laqAI0/`，不把旧通过结果冒充最终统一批。
- 无真机安装、Windows 原生运行或长时间性能测试；未发布 Steam、Release、APK 或更新服务器；没有修改正式玩家数据、签名、版本或生产更新基线。

复现：`python3 tools/run_rts_refinement_qa.py --godot "$GODOT_PATH" --out <checkout外不存在的绝对目录> --visual`。实现与设备参数来源见 [说明](../../docs/RTS_REFINEMENT_20260920.md)，详细矩阵见 [触屏 QA](../../docs/QA_RTS_TOUCH_HUD_20260920.md)。

## 基础操作子套件复现

运行脚本：`tools/rts_foundation_regression_qa.gd`。必须使用已导入资源的私有工程，给该副本配置唯一的 `application/config/custom_user_dir_name="LSH-..."` 和 `application/config/use_custom_user_dir=true`，不得以正式工程或玩家存档运行。

```sh
STEAM_DISABLED=1 CAMPAIGN_QA=1 CONTENT_UPDATE_NO_AUTO=1 LSH_LANGUAGE=zh_CN \
LSH_FOUNDATION_QA_OUT="$QA_DIR/foundation-result.json" \
"$GODOT_PATH" --headless --path "$PRIVATE_PROJECT" \
  --script res://tools/rts_foundation_regression_qa.gd \
  --log-file "$QA_DIR/foundation.log"
```

验收同时要求退出码为 0、JSON `passed=true`、六组运行用例全部走到最后断言，并且日志没有 `SCRIPT ERROR` / `Parse Error`。脚本会拒绝非隔离环境；结果仅在显式设置输出环境变量时写入。

统一 `tools/run_rts_refinement_qa.py` 的 `LSH_RTS_QA_OUT` 也受支持，写入该目录的 `foundation-result.json`。

## 本轮开发验证

2026-09-20，Godot 4.6.1，独立 profile `LSH-rts-refinement-lsh-rts-refinement-20260920-dev`：36 项断言全部通过，退出码 0，日志没有脚本错误、解析错误、引擎错误或警告。

- 行军 180 帧：90.00009 px，队伍上限 30 px/s，寻路 1 次。
- 不可达巡逻 180 帧：寻路 8 次，当前处于有限退避；路线开放和撤离队列测试通过。
- 对向友军绕过据守者：两条分离路径结果一致，友军从 x=160 前进至 x=384.696，据守者从 `(320,300)` 仅偏移约 0.604 px。敌军和悬崖约束通过。
- 施法队列、货物入账、各缩放边界和真实中键反向拖拽均通过。

这是一轮开发副本运行结果；整批修改的最终冻结来源与总回归结果以本轮统一 QA 收据为准。

## 覆盖范围

- 正常低速行军：使用真实地图寻路和单位物理逻辑，3 秒以队伍上限 30 px/s 行进 90 px，只寻路一次；真正静止超过 1.5 秒时仍会重寻，且保留队伍速度上限。交战后的攻击移动也保留上限。
- 不可达巡逻：地图由整列悬崖分隔，有限重试后退避 2 秒；移除悬崖后恢复移动；追加撤离命令不被失败巡逻永久阻塞。
- 施法与 Shift：真实 `Battle` 走近队列、待结算队列及 `Unit` 抬手状态机，验证抬手与走近期间追加移动不打断技能、技能只结算一次再执行移动、Stop 能取消走近、全新即时施法仍替换旧队列。测试只把技能最终效果替换为计数收据，不将此当作技能伤害/特效完整验收。
- 资源携带：真实改采目标、返仓与入账路径；金改木先交原金，木改金按原木折算；无仓库时仍保留原货物类型和数量。
- 据守位置：直接与批量分离路径保持一致；据守只承担 2.5% 软位移，友军承担主要分离，并以可通行的微小切向位移绕行。对向友军真实行军可通过，不把据守者推出阵位；双据守仍能解重叠，不给敌军额外穿透。
- 相机边界：0.5 / 1.1 / 3.2 缩放下实际视图中心与输入位置保持一致，反向平移立即生效，边缘缩小时立即重新夹紧。

## 接口与兼容性

`Unit.continue_action_move()` 用于同一个走近施法动作内部重寻，不覆盖已追加命令；`begin_cast_windup(..., preserve_queue=true)` 用于该动作转入抬手。普通替代命令仍更新 `_order_serial`，Shift 追加不更新。`Battle.unit_action_queue_busy()` 把走近、抬手待结算和物品队列纳入队列交接门闩。

`RTSCamera.clamp_to_limits()` 供外部跳转或缩放后调用；可见性筛选、小地图等读取 `view_center()`。据守几何侧让共用 `Unit.separation_yield_position()`，且逐段检查地图通行条件。此次未新增需要存档序列化的单位状态字段。

本套件不替代完整战役、触摸 UI、存档恢复及大量混编部队的长时间性能验证。
