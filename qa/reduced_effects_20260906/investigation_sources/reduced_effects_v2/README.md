# 精简特效 V2 草稿与验证准备

状态：只生成草稿，未应用到生产，未运行 Godot、未运行 Git。`static_receipt.json` 中 76 项静态检查通过；这不是 GDScript 解析、玩法、图像、GUI 或帧率验证通过的收据。

## 交付与源码基线

| 文件 | 用途 |
| --- | --- |
| `candidate.patch` | 四文件统一补丁，头部带完整 SHA |
| `candidate/*.gd.txt` | 四份完整候选源码，UTF-8/LF |
| `frozen/*.gd.bin` | 对应基线原字节，保留原换行 |
| `pins.json` | 基线 raw/LF、候选 LF、启动依赖与安全助手 SHA |
| `qa.gd.in`、`generated/driver.gd` | 同字节 QA 模板与准备入口 |
| `qa_extra.gd.in` | 本轮新增配置、真实退出与关键反馈检查 |
| `prepare.py` | 只重建本目录内的产物，不应用源码、不启动进程 |
| `static_checks.py`、`static_receipt.json` | 补丁重构、作用域、重绘保留与合成启动拒绝检查 |
| `launch_check.py`、`launch_plan.json` | 启动前源码校验与独占运行草稿；默认只生成计划 |

根任务已报告 M2B 提交及远端确认 `4baafc11af55b0e46a57a48e54df181b8c1917a2`；本子任务未用 Git 再核对。Unit 基线不取运行中可能被插桩的 live 文件：从 `scratchpad/redraw_reject_validation/unit_before.bin`，仅按 `scratchpad/apply_redraw_candidate.py` 内 AST 字面量的两方法替换重建，核对 LF SHA 为 `c8a692bff598b6ac9199d113ccc9ff39ea8943f127012b45fc67ff2cd6c4deec`，原字节 SHA 为 `c8310fd12a29858df8f7410dd06d2f1dc51f40f5eedc0e7a6a16599eb5e58856`。既有两项重绘方法在 V2 保持 LF 字节一致。

Battle 来源为 `scratchpad/physics_step_diag/frozen/battle_original.bin`，基线 LF SHA `784373eede18a82c24fc50a6e36a42b6c20516bf439cf200fe5be7d239db6e2c`。Settings、SettingsPanel 已冻结在本目录，后续准备优先复用；四个基线原字节均有独立校验。旧版两个精简特效草稿原字节保持不变。

候选 LF SHA：

| 源码 | SHA-256 |
| --- | --- |
| `scripts/settings.gd` | `eb5644054a357a2b4e598332163636add65d667f48c4cea5b9c71f2f5c16a5ce` |
| `scripts/settings_panel.gd` | `433718af5cfea3ee8ffb5e81ff5f3bec5fa14e75a5f6d194e1933fb90bce255d` |
| `scripts/battle.gd` | `9b32d8bd4b73d3f4ceb4343548b1ae331c4f9d75272fcabf1c5354fcb7b76208` |
| `scripts/unit.gd` | `f4382456b8c619cbb86c40cd8a9ed6ea9f171ba0a8a90c191538f689176d49ee` |

## 产品行为与兼容边界

新完整源码默认 `effects_quality = "standard"`，保存为 `user://settings.cfg` 的 `[show] effects_quality`；只接受字符串 `standard`、`reduced`。旧配置缺键或值类型/枚举错误回落标准，其他旧偏好按现有逻辑读取。

Settings 面板显示“特效细节”，选项“标准”“精简”。生产绘制使用 `Settings.get("effects_quality")`：旧包已经创建的 Settings 实例没有该字段时返回空值，五类绘制均走标准；面板只在字段是合法字符串时加入这一行与说明。旧 Settings 的 `save()` 不能持久化该字段，因此此兼容分支隐藏选项，不提供一项实际上无法保存的选择。历史 APK/PCK 挂载顺序、缓存脚本类与 Android 真机仍须独立集成验证；桌面 fresh-process legacy 夹具只证明“实际旧 Settings 源码启动 + 新面板/绘制源码”组合。

五类变化均限于 `_draw`：空气浮尘不绘制；普通/重击放射线隔线绘制但白色命中中心保持；地火跳过飞散余烬但地面范围与火焰保持；散射斧跳过拖尾但斧体保持；单位不绘制脚底尘土。创建、随机初始化、数组更新、伤害、范围、技能统计、投射时机、AI 与清理回调原文未改变。静态检查把四个 Battle 绘制体及 Unit 绘制体遮去后，剩余源码与基线逐字节相同（LF 规范化）。此证明限定修改位置，不能替代实际运行。

## QA 的补证内容

- 配置：真实 Settings 源码只替换 `PATH` 常量为本次私有夹具路径。测试缺文件、语法损坏、缺键、非法类型/值、合法值以及其他旧偏好；写入与读回用两个独立 OS 进程。损坏配置检查准确 `ERR_PARSE_ERROR`、默认值及损坏文件不被重写。
- 真实地火退出：Battle/Unit 留在树外、只把冻结处理的 `fx_root` 放进 SceneTree。两次实际生成分别调用原 DOT/TimedFx 步进，等待真实 `queue_free → tree_exited`，要求弱引用失效、预算归零、残留子节点清空，然后第二次生成成功。两档模式都要求同样伤害与退出次数。没有手工补调用预算释放函数。
- 普通/重击：同一冻结实例按标准、精简、恢复标准拍图，比较白色中心像素与核心圆盘；重击仍有更大的可见范围。
- 地火：同一已初始化实例仅在夹具内暂时移除 `_embers`，取标准渲染的完整火焰/地面核心为对照，再恢复原数组。精简图须保留全部核心像素、四个以真实半径导出的地面锚点，恢复标准后的图与原图相同。
- 多目标飞斧：从实际 Art 自动加载器取真实斧纹理，缺素材直接失败。三个分离目标使用实际 LiBrawnAxesFx；独立只画纹理的对照节点按规定轨迹放置斧体。逐目标可见区域、所有斧体核心像素和恢复标准图进行比较，实例、时间、伤害字段保持。
- 继承原草稿的有限固定回调：真实伤害/护盾/DOT/击杀边界及下游 RNG 哨兵对比，仍明确不涵盖全局 RNG 状态、完整 AI、物品触发或整场战斗等价。`freed_target_boundary` 独立运行，现有 typed Unit 取出已释放目标的风险不能混作精简档成功证据。

损坏配置会产生预期的解析控制台报错。模板只在两次同步配置读取之间临时关闭 `Engine.print_error_messages`，不跨 `await`，立即恢复并记录准确错误码及恢复状态；其余日志仍由外部助手严格检查。该属性可用于测试时隐藏预期错误，但会影响其他脚本输出，因此此区间保持最小且不安排异步工作。[Godot Engine 4.6 官方属性说明](https://docs.godotengine.org/en/4.6/classes/class_engine.html#class-engine-property-print-error-messages)。

实际菜单入口、Esc 暂停入口、按按钮切换、关闭/返回、1440×900 与 1280×720、真实 Autoload 跨进程保存由并行 `scratchpad/reduced_effects_ui/` 夹具覆盖。本模板不把直接写字段当作 GUI 测试，且不调用面板 `close()`。本模板保留 `CAMPAIGN_QA=1`，不会声称验证了 Campaign 真实保存回调；GUI 夹具在同样私有配置隔离下另行验证。

## 外部启动准备与故障边界

`launch_check.py` 默认不启动 Godot。只有显式 `--run` 才会调用已增强的 `scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py` 进程助手：独占 Godot 检查、共同锁 `.godot/redraw_rejection_source.lock`、精确子进程句柄、超时/中断后的 kill+wait 确认、严格日志/退出/报告检查。助手本身与其读取的公共环境工具已 pin，未改动它们。

本启动器不应用或恢复任何生产源码；根任务负责在测试前完成受控候选应用。`candidate` profile 要求四份候选，`legacy` profile 要求前三份候选中的 Battle/Unit/面板与原始 Settings。根任务若临时切换 legacy，应复用其既有多文件原字节备份、独占与锁协调方案；本草稿不能绕过一个已占用的共同锁，也不能替根任务恢复此前的临时修改。现有源与预期 profile 不符时，在启动 Godot 前直接拒绝。

启动前校验四份源码、生成 QA、项目配置、更新器和安全/环境助手，避免等到 GDScript/Autoload 解析之后才发现漂移。运行前后还记录脚本、场景、素材等更广来源清单。异常退出只在确认子进程已退出、来源与私有偏好未变化、锁所有权仍属本次后释放锁；未确认退出或来源变化时保留锁和收据。该启动器不自动重置、重写或覆盖未知变更。

每次运行新建 `runs/<UTC>/private_roaming` 和 `private_local`，仅给子进程设置 `APPDATA`、`LOCALAPPDATA`，不改父环境。Godot 4.6 Windows 的配置/数据根读取 APPDATA，缓存根读取 LOCALAPPDATA，项目 user data 在数据根下拼接项目目录；启动前拒绝自定义 user-dir 配置，QA 启动后立即验证实际 `user://` 位于本次私有 roaming 根内。[Godot 4.6 Windows 官方实现](https://raw.githubusercontent.com/godotengine/godot/4.6/platform/windows/os_windows.cpp)。

不要传不存在的 `--user-dir` 参数。运行时路径检查位于 Autoload 初始化之后，因此启动前源码/配置锁与 child env 隔离同样必要。私有目录预置为空，避免用户内容更新包在 `_init` 挂载；真实玩家的配置、存档与更新目录不作为输入。本行为 QA 对私有 Autoload `settings.cfg` / `campaign.cfg` 也要求前后无变化；PATH 重定向夹具保存在本次 runs 的另一路径。

仅准备与检查（已执行，不启动 Godot）：

```powershell
python scratchpad/reduced_effects_v2/prepare.py
python scratchpad/reduced_effects_v2/static_checks.py
python scratchpad/reduced_effects_v2/launch_check.py --render --stages all restart_write restart_read
```

未来根任务在四份候选已受控应用、独占空闲且源码/素材无漂移时，可执行的入口：

```powershell
python scratchpad/reduced_effects_v2/launch_check.py --run --render --stages all restart_write restart_read
```

独立 legacy profile（由根任务先受控准备对应源码组合）：

```powershell
python scratchpad/reduced_effects_v2/launch_check.py --run --profile legacy --render --stages legacy_autoload
```

`--godot`、`GODOT_PATH` 或被忽略的本地 `godot.local.txt` 提供引擎位置。所有进程均有界超时，失败保留日志。`freed_target_boundary` 应独立一次调用并检查失败原因，不能放进全绿结论。GDScript 解析、正确渲染器下像素对照、实际技能警示可读性及标准/精简性能对照全部尚未实测；此草稿不报告正常 FPS 或 30 FPS 改善结论。
