# 安卓驻守战开局、Y900 HUD 与托管检查（2026-09-25）

## 范围与状态

- 检查源码：`winterzh/Liangshan-Heroes`，`codex/sync-20260905-stable`，`3fe9eecf82c322ad77dfcbbfff216caec7de9a06`。
- 已执行 `pull --ff-only`，无新增提交；收尾回读远端 SHA 与本地一致，工作区干净。
- 本轮只诊断。未改生产代码、发布 APK、推送 GitHub、更新服务器或 Steam。诊断脚本与结果仅在本临时目录。
- 私有工程/存档与生产分离；3332 个冻结输入分别在原 checkout 与私有副本通过 SHA-256 复核。独立固定 gameplay RNG seed 5088120。
- 没有连接安卓设备。图形采样在 Apple M4 Max / Godot 4.6.3 / Compatibility 上进行，不能当作 Y900 帧率、温度或功耗实测。

## 已复现的功能问题

### FPS 被技能栏遮住

`opening_b/before_heroes.json`：无英雄，FPS `(1216,68,50,24)`，没有技能控件重叠。

`opening_b/after_heroes.json`：6 英雄，FPS 仍 visible，仍有 `FPS 60` 文本，但技能按钮 `(1193,70,77,77)` 覆盖它。对应 PNG 已目视检查，英雄出现后 FPS 不可见。

原因：HUD 的 FPS 在 `_ready` 中创建，触屏技能栏在后续 setup 中创建，后加入的同层控件覆盖前者；FPS 与技能栏的 y 分别为 68/70。源码 `scripts/hud.gd:241,257,848,2438`。

建议：为 FPS 与菜单保留独立顶部空间，再排技能栏；不能只提高 FPS 层级把文字叠在图标上。

### Y900 组件尺寸与顶栏

- 本次 3000×1876 物理视口、1280×800 逻辑视口：技能栏宽397，占31.0%；6行高482。
- 已有 `qa/rts_foundation_20260920/touch-layout-report.json` 的3840×2560测试视口：技能栏宽402，占31.4%。该项是已有测试尺寸，不据此断言用户平板具体型号。
- 原规则主要从可用高度推格子大小，最大78；没有技能栏占屏宽上限。`hud.gd:848`。
- 顶部状态条采用剩余宽度铺满，非按内容收紧；safe-area 顶边也需要同时核对。`hud.gd:532`。
- 现有几何 QA 检查最小点击尺寸、是否出界和部分面板重叠，但漏测 FPS、顶栏及技能栏最大占屏比。

建议：保留6英雄全部主动/被动格，增加约24–25%安全区宽度预算，并保留至少48逻辑像素点击目标；顶栏按内容与最大宽度收紧。需要截图和真机触控验证后再定最终尺寸。

### 托管按钮两处逻辑错误

真实 HUD pressed 回调和 Battle AI 方法已复现，详见 `autoplay/autoplay-bug-probe.json`，不是只从源码推断：

1. 混选英雄状态 `[false,true]`，主英雄为 false，按钮显示“托管”；点击后实际变 `[false,false]`。文案依据主英雄，动作依据选中集合，语义相反。
2. 全托管 level3：`[true,true]` → 点击取消 `[false,false]` → 下一次 `_auto_micro_pass()` 又变 `[true,true]`。取消被全局策略强制覆盖。

建议：统一按钮文案、可见性与动作的选择集合。全托管取消应明确切换为允许手动接管的策略，或明确不可取消并解释原因，不能提示成功后自动恢复；切换策略是否影响经济/镜头需要确定。

## 性能证据

### 静态场景绘制是已定位的宿主热点

真实渲染，3000×1876，6英雄开局，冻结模拟后按组件隔离。相反顺序重复两次，避免单一测试顺序；这些隐藏操作仅用于诊断，不是拟交付的视觉改动。

| 组件对照 | 两轮绘制调用/帧 | 渲染 CPU 毫秒，两轮 |
| --- | ---: | --- |
| 完整基线 | 3482 / 3482 | 8.88 / 9.07 |
| 仅隐藏场景装饰子树 | 668 / 668 | 1.61 / 1.53 |
| 仅隐藏 HUD | 3022 / 3022 | 7.95 / 8.03 |
| 仅隐藏单位 | 3313 / 3313 | 8.79 / 8.86 |

来源：`components/performance.json`。场景子树约占本视角81%的绘制调用。渲染 CPU 不等于纯 GDScript 时间，可能包含驱动等待；GPU 计时返回0，视为不可用而不是零开销。

继续保留子节点，只清除两层自身 CanvasItem 的绘制命令，并在清除前等待 `frame_post_draw` 排空重绘：

| 静态层隔离 | 两轮绘制调用/帧 | 相比3482减少 |
| --- | ---: | ---: |
| Scenery 自身命令（岸线、已有阴影/芦苇网格等） | 2079 / 2079 | 1403 |
| Entrance 自身命令（台地立面等） | 2404 / 2404 | 1078 |

来源：`scenery_parts/performance.json`。这两层合计约占71%的绘制调用。

源码热点是 `liangshan_scenery.gd:592` 的逐岸段 polygon/抗锯齿线，以及 `liangshan_entrance.gd:191` 的细分台地与立面画线。命令缓存不等于渲染合批；整圈放在一个大 CanvasItem 中也不利于空间剔除。地面本身已经有 terrain mesh batch，寨门瓦片、静态影、芦苇也已有部分合批，不能重复声称这些尚未实现。

优先优化方向：保持原几何与透明叠放关系，对岸线/台地进行合批和空间分块；另减少静态物体未变化时的变换提交。改善多少必须用安卓真机采样验证。

### 脚本微基准（不代表实际帧耗时）

`cpu/android-ui-cpu-probe.json`：headless 主机，真实固定6英雄，60次预热、200次×3重复。

- HUD `_process(1/60)`：均值0.165ms，P95 0.286ms。
- `_refresh_touch_controls`：均值0.068ms，P95 0.072ms。
- `_layout_touch_action_buttons`：均值0.004ms。
- `_sync_elevated_nodes`：均值0.145ms，P95 0.154ms。

HUD 的几项计时互相包含，不能相加；deferred 布局、重绘和 GPU 不在同步调用微基准内。代码确实有每帧重复布局/本地化/静态位置提交，但现有证据不支持把它们说成唯一或最大瓶颈。

## 探索记录与限制

- `opening.log` 最初的脚本提前解析 autoload 失败，后一次探索夹具写错公孙胜 key，仅5英雄；不得当正式6英雄证据。
- `opening_b` 修正为6英雄，适合 FPS 遮挡和布局证据。活跃场景的多个消融接近60fps，状态也随时间变化，不用于承诺优化收益。
- 旧字段 `mean_cpu_ms/mean_physics_ms` 是 Godot 每秒最大值 monitor 的重复读取均值，不是逐帧CPU平均。后续脚本改名为 snapshot，报告不据此推断性能。[Godot 4.6.3 main.cpp](https://github.com/godotengine/godot/blob/4.6.3-stable/main/main.cpp)
- Compatibility 不支持2D MSAA，因此项目里的4×设置不能解释为Android实际4×渲染负担。[Godot 4.6文档](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-rendering-anti-aliasing-quality-msaa-2d)
- `components` 中 terrain clear 首轮可能被已排队重绘回填，首轮不用于判断地面成本；后续 `scenery_parts` 已在清除前等待完成绘制。
- 开局结论不能外推到60波后期大量单位、热降频、安卓驱动和系统合成；物理触控未验证。

## 本次后续建议

先修复 FPS 占位、平板尺寸规则与托管状态一致性；性能优先处理已定位的静态绘制提交。补充包含0/1/6英雄、FPS矩形与文本更新、技能栏最大占比、多种安全区及托管点击后AI一轮状态的回归检查。之后使用同一APK在Y900采集开局与战斗中的帧时间、GPU负载和温度。
