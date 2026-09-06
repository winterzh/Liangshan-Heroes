# 快活林短篇 QA — 2026-09-06

基线从2d22c37安全快进至3a218f0，本批生产变更仅快活林菜单/独立脚本；复用原地图、角色素材与共享数值。最终六项作业全部退出0、没有脚本错误，共 **257条PASS**：实际三路线52、独立边界31、两尺寸四阶段UI40、核心68、共享经营/跨模式39、实际Vulkan酒路27。没有把早期尝试或冻结夹具算成实战。

| 最后三路线回放 | 游戏秒 | 指令数 | 武松最低生命/440 | 演义 |
|---|---:|---:|---:|---:|
| wine | 69.72 | 46 | 303.69 | 4/4 |
| direct | 71.00 | 58 | 130.62 | 2/4 |
| standing | 68.62 | 55 | 34.77 | 1/4 |

酒路四家、可选练步和挑衅均由玩家接口办理；直接路线从店前实际攻击开打。三者均实际打倒并留命、谈条件，施恩实际走回收店。酒路/直接路线避开两类招式并在当前窗口完成W换位后E命中；站桩没有主动躲招和拳路信用。相同种子回放仍受命令帧与暴击时机影响，早期和Vulkan的战损也不同；这是策略风险证据，不是稳定平衡或真人5—10分钟验收。自动玩家知道地图，4倍运行，截图FPS不能用于性能结论。

`all/report.json`与`routes.log`是最后真实路线；`wine_rendered/`及对应日志是另一次真实Vulkan酒路，5张实战图。`boundaries/`与日志明确使用位置/阶段/冷却/伤害注入，验证真实共享技能结算、冲锋、墙/水阻挡、过期/原地/踢空、1血留命、练步、重打按钮及模式隔离。`ui/`8图是冻结场景，显式刷新HUD/任务布局并选择武松，验证滚动末项、指令面板与纯定位；不冒充实战。

`attempts/`保留原始错误/早期结果：baseline日志证实旧版历史闪避可给拳路、冲撞位移为0；`baseline_from_log.json`从该原日志解析，未使用后来被覆盖的临时JSON。旧驱动只在基线有效。compile探针冻结物理，不能据其0位移否定新的真实冲撞。boundary第1次25项全绿但总数误写26，所以退出1；第2次未bake注入地形，两项失败；第3次27项通过。后续模式夹具误把Defs当autoload报错，终止后修复为静态类，再经当前31项通过。初版UI冻结后仍显示准备阶段，最终显式刷新真实战斗状态并选择武松。

复现（Godot路径由忽略的godot.local.txt读取）：

```powershell
$godotExe=(Get-Content godot.local.txt -Raw).Trim()
$env:KH_CASE='all'
& $godotExe --headless --path . --script res://tools/kuaihuolin_short_test.gd
& $godotExe --headless --path . --script res://tools/kuaihuolin_short_boundaries.gd
& $godotExe --path . --script res://tools/kuaihuolin_short_ui_test.gd
$env:KH_CASE='wine'
$env:KH_VISUAL='1'
& $godotExe --path . --script res://tools/kuaihuolin_short_test.gd
```

旧深度工具转至当前边界入口；历史QA不覆盖。receipt.json记录本批主要输入和冻结证据的本机/提交字节SHA-256，旧文本仅允许明确的CRLF/LF差异，PNG与冻结证据保持原字节。这不是整个发行包或素材来源完整性审计。

Codex已检查实战重拳/冲撞/反击、1280技能面板和1440收店画面。施恩旧持械造型、店牌、技能图标和酒保换酒动画仍待整理；全库四向、教程/战斗保存恢复、真人与发行验收未完成。本批无新生产图片、导出或Steam操作。细节见[实现说明](../../docs/KUAIHUOLIN_SHORT_20260906.md)。
