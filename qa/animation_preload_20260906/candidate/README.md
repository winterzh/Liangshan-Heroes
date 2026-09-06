# 当前单位常用动作预加载：私有入口实验

状态：仅静态准备，未运行 Godot。来源 `06c2c69601bc6fb6e1172ab5d195a3ef5c143a3a`；关键原文件和本草稿的 raw/LF SHA 见 `pins.json`。不改生产、Autoload、Settings 文件、M1 三工具或项目导入缓存；不建镜像。这里不是已经接入玩家开战流程的功能。

## 唯一实验差异

`driver.gd` 继承当前 `tools/polish_performance_probe.gd`。两次新进程使用同一份 driver/helper：`ANIM_LOAD_MODE=none` 是控制，`current_units` 执行有限计划。helper 在 Autoload 已就绪后、原夹具创建前以相同方式加载，不提前编译依赖 Art 的 Unit。

原 `_new_battle()` 恰好执行一次，保持 seed、200 敌人夹具、身份创建顺序、音频逻辑、镜头、输入和 300 物理步 warmup。父方法返回后 Battle 已 `PROCESS_MODE_DISABLED`，TickDriver 尚未创建，才开始准备。确认其子树所有 Unit 均不能 `can_process()`，并比较准备前后已有 Unit 的身份和显式关键字段，以及 M1 状态/tick；这些检查不是完整战斗/RNG 等价证明。

计划只从此时在场、存活、非建筑/资源的 Unit 收集去重 key/variant。仅已进入 melee_mode 的单位增加对应 melee key；不调用会隐式查询 Art 的 `Unit._anim_key()`。动作是 attack、walk，各四方向，英雄优先，最多 12 种身份/96 请求。不扫描全资源库，不加入未来召唤物/死亡/剧情专用动作。只调用原 `Art.unit_anim_frames()`，原 alias、variant、fallback、缺资源行为均保留；请求返回空帧原样记录。

每次完整同步请求之后等一次实际 `frame_post_draw`；无 Unit 新建/删改、命令、预播、静音新开关或 RNG 调用。软限为总准备 8 秒、纹理监控增量 96 MiB、静态内存增量 128 MiB；末次请求也检查。单次原 API 不能中断，可能一次超额，随后报告无效并保留现场，不把软限当帧时长保证。每请求原 API 的耗时、帧数、清单，以及准备总墙钟、缓存新增 key、引擎内存指标都落盘。

加载会创建资源和 AtlasTexture，可能改变后来创建对象的 ID。保证不重写当前 Unit ID，不承诺未来对象 ID 或统计战斗轨迹相同。控制模式也做公共的列表、快照和缓存读取，但不执行 Art 请求、不人为补齐等待；预加载增加的资源与等待正是干预。加载时间包含资源解析/解码/纹理及帧对象构建等，不能称纯磁盘 I/O。

## 主任务执行合同：先串行 2 × 10 秒

无需新 runner。主任务可沿现有 `run_polish_performance.environment()` 清理生产诊断开关，使用已审计的真实引擎句柄、共锁、独立 APPDATA/LOCALAPPDATA、玩家目录前后守护和完整 source receipt。**公共 `run_polish_performance.py` 本身不提供完整私有 profile/共锁保护，不应直接照其 main 入口运行本实验。** 不复用玩家配置，不复制玩家内容。保留默认 Vulkan Forward+、真实渲染窗口；不传 headless、fixed-fps、disable-render-loop 或单独关闭音效。

每个模式创建全新目录：`scratchpad/animation_load_candidate/runs/<fresh-stamp>_<mode>/`。父进程先确认它不含 reparse/link、没有与玩家目录重叠，且所有目录均为本次新建。该目录下 `private_profile/appdata` 和 `private_profile/localappdata` 只供子进程。环境字段：

| 变量 | 值 |
| --- | --- |
| `ANIM_LOAD_MODE` | 第一进程 `none`，第二进程 `current_units` |
| `ANIM_LOAD_OUT` | 本次新目录的绝对路径 `/preparation.json` |
| `ANIM_LOAD_USER_ROOT` | 本次新目录的绝对路径 `/private_profile` |
| `APPDATA` | 上述 private_profile 下 `appdata` |
| `LOCALAPPDATA` | 上述 private_profile 下 `localappdata` |

driver 自行固定 `defense200/fixed/10/standard`，将原 M1 报告写到同目录 `m1_10s.json`。沿用当前项目名产生的实际 `user://` 必须落在该 private_profile 内；父进程仍应核对实际报告路径与预期完整路径相等。命令参数列表：

```text
<实际 Godot exe> --path <当前 checkout> --script res://scratchpad/animation_load_candidate/driver.gd
```

不要直接用会派生另一进程的 console 包装器持有伪引擎句柄；使用既有经过验证的实际引擎路径。准备期间仍占用 Godot 共锁。每轮实际进程退出后才检查并释放/切下一轮，超时或中断保留日志和失败收据。

父进程分别留存：完整来源摘要（生产目录按原 M1 规则，另加本草稿 GD/pins）、清理后的允许环境字段、实际引擎 SHA/渲染器、私有路径、日志、`preparation.json`、`m1_10s.json`、退出与玩家目录守护收据。运行前后来源必须一致；driver 内仅记录 13 个关键源 SHA，**不能替代完整生产/资源来源摘要**。

有效入口要求：真实引擎退出 0，无 SCRIPT ERROR/ERROR/FAIL；preparation 的 `valid/completed_plan/observed_state_equal/still_frozen` 为真，`measurement_finished` 为真，关键源 before/after 相等；M1 原完整性检查、完整 10 秒、真实接战、普通质量和玩家文件检查均过。`none` 的 API 请求为 0；candidate 请求数等于计划，且所有已有 Unit 身份前后相等。两模式初始部署/输入摘要必须一致。失败结果独立保留，不混作全绿。

首次两窗口只看入口可运行、实际准备费用/缓存增量、前 10 秒 frame gap/物理步及原始轨迹是否值得继续；两者 `acceptance_eligible=false`，不能据单次 FPS 或 248 ms 旧热点声称性能改善已证。若值得再由主任务决定交替/多重复正式对照，不自动扩展 3 × 60 秒。

## 当前证据和未来生产入口边界

旧首用诊断的 sample 中李逵 attack/se 外层 248.224 ms、内层 loader 248.045 ms 是包含关系，不可相加；36 次动画 miss 合计约 502.75 ms，既不是纯磁盘耗时，也不解释所有卡顿。该诊断源为 4baafc1，需本次普通版实测验证是否仍出现。当前计划不覆盖例如关刀死亡、未来龙召唤等首用。

真实驻守 `scripts/levels/skirmish.gd` 的 `deploy()` 只建 5 工人/2 刀兵和建筑资源，没有 M1 注入的六英雄。因此本实验成功也不能声称覆盖玩家后来招募李逵。后续生产有限名单应另审开局实际身份 + 固定可招募六将 + 当前模式有限波表；维持剧情 variant/运行 alias，分开预算，禁止每 spawn 同步加载。

生产 `Battle._ready()` 在 `level.deploy()` 后才知道实际 roster；`_on_intro_done()` 会自动调用开战，`_on_start_battle()` 会执行关卡 on_start。单凭 INTRO 不可当冻结：Battle 自身 early return，Unit 的 physics 仍可能运行；DEPLOY 也跑 Battle 部分 pass。若正式接入，最小入口需要显式冻结整个战斗子树、防重复开始、显示准备进度，完成后恢复并恰好一次调用原开战流程。该钩子和玩家加载体验本草稿均未实现，不能直接把这里的 await 塞入开战函数。

## 静态复验

运行 `python scratchpad/animation_load_candidate/static_checks.py` 只校验文本、Python AST、关键源码与 pins，不启动引擎、不复制目录。首次冻结用 `--freeze`，存在 pins 时拒绝覆盖。`static_check_receipt.json` 明确不证明 GDScript 编译成功。真实引擎结果仍待主任务。
