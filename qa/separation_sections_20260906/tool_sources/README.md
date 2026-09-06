# 分离四阶段诊断：冻结源码、隔离运行草稿

状态：**首次私有导入在 300 秒超时，尚无分段测量结果；未实现优化，未改当前生产或公共工具。** 原失败在 `runs/20260906T104036739951Z/`，日志与收据保持原字节。来源扫描修正后 43 项静态/合成账本检查、23 项续跑临时文件反例通过，均非 Godot 运行验证。准备缺失原件时使用过只读 `git show 4baafc1:<path>`；没有 checkout、stash、reset、worktree、提交或推送。来源见 `frozen_git_receipt.json`。

## 单一目的与运行上限

本稿只回答：完整分离求解的 `profile_cells` 准备是否占有值得继续投入的成本。只在原 `solve` 的四个大阶段边界读时钟，不优化建桶、不添加 per-pair 时钟、不增加细粒度计数矩阵。

将来显式运行一次时固定执行：独立工程必要导入 → **timed/fixed/10 秒一轮** → **clockless/fixed/10 秒一轮**，每轮沿用 M1 的 300 个实际物理步热身。两轮完成即退出，根任务看收据后决定是否继续。没有自动 20/60 秒、auto 相机或增加重复。Battle 分派计数两轮都保留；候选对/重叠对/导航回退等独立计数进程目前没有实现，它们只在根任务认为必要时另做。

## 交付与冻结来源

- `prepare.py`：只写本目录，核对冻结来源、生成插桩/驱动/patch/pins。原方法和调用必须唯一，插入内容反向去除后必须完整恢复原 LF 字节。
- `generated/battle_instrumented.gd.txt`、`crowd_instrumented.gd.txt`、`instrumentation.patch`：只供隔离副本；绝不应用到当前 M2C。
- `driver.gd.in`、`ledger.gd.in`、`generated/driver.gd`、`ledger.gd`：实际准备入口及预分配记录器。
- `analyze.py`：核对同钟 M1 区间、physics/process/presentation 关联，统计四阶段及分派。
- `launch.py`：默认计划；显式 `--run` 才导出 Git 冻结副本并运行。
- `static_checks.py`、`static_receipt.json`：Python AST、源码结构/哈希和异常账本拒绝；不把这些称为 GDScript 或运行验证。
- `pins.json`、`preparation_receipt.json`、`launch_plan.json`：完整来源/生成件 SHA 与未运行状态。

固定完整提交 `4baafc11af55b0e46a57a48e54df181b8c1917a2`。11 份关键源冻结为本目录的 `frozen/` 文件：Battle/Unit/Settings/Campaign、crowd solver/GameMap/更新器、M1/父测试/环境工具和 project.godot；另冻结已经增强的进程安全助手。冻结 Unit LF `c8a692bf…`、Battle LF `784373ee…`、crowd solver LF `3f6eb822…`，完整 SHA 在 pins。

准备时发现当前 `tools/polish_performance_probe.gd` 已不同于旧基线，哈希拒绝后从明确提交只读取得旧原件；没有把 live 内容重新定义成参照。未来运行使用 `git archive` 从同一个完整提交导出 `project.godot`、运行源/场景/素材/公共 tools 等白名单到新的 `runs/<UTC>/project`。它不读取当前 index/未提交改动作为输入，也不要求当前 HEAD 回退。归档逐项拒绝目录逃逸、绝对路径、链接和特殊文件；关键源 LF SHA 再核对后，仅改那份副本的 Battle/crowd，并放入两个诊断脚本。原归档留在本次 `base.tar`，无需恢复当前工作树。

## 四阶段、顺序与计时边界

`crowd_separation.solve` 的完整原函数体按以下相邻边界划分：

1. `snapshot_us`：原 sources/indexes/order、保留 bucket-only 邻居、原 Packed/flags/profile/开放导航格快照。
2. `profile_cells_us`：原 `profile_cells` / groups / 最大 ID / Packed 索引建桶。
3. `pairs_us`：原 order → 九格 → 原桶条目顺序、拒绝条件、逐对位移、NAV_OPEN 与原跨格回退。
4. `publish_us`：原最后一次位置写回循环。

入口一次、三个内部边界、出口一次，共 **5 次时钟读取/完整 solve**（仅 timed）。不计调用者到原函数进入前/原函数返回后的分派开销。原函数体全部保留，没有只抽一段热循环；所有浮点运算、状态读取、分派门槛、相位推进、桶/重复条目顺序、导航调用和最终写回均保持原文。现有 solve 没有早退；未来若出现早退，准备器拒绝，不能靠现有尾部打点假装完整。

stage 函数在读时间后才写账本：其记录/返回开销进入下一段，最后记录开销没有后段承接；begin/end 分派也有探针开销。这是原体加探针的四段观察值，不是扣除了探针的纯算法耗时。clockless 执行同样 stage/分派/账本控制流程，只去掉这 5 次 solve 时钟，四阶段成本输出 `null`，不能把零当测量结果。

Battle 的原唯一 `.solve(...)` 调用仍执行一次。计数放在已经选定的缓冲分支，或原 `stagger` 计算后的直接分支；不重新判定分派条件。路线 `0=buffered`、`1=direct`、`2=phased direct`。每 M1 物理步要求分派一次，buffered 要求一次完整 solve 和四阶段 mask=15；其余路线不得出现 solve。没有为直接路线增加计时，因此不得把缓冲每调用均值当作所有分離步成本。分析同时给出每 buffered solve 和每全部 M1 物理步的均值。

没有新增 RNG 调用或 Node；多加载一个共享 GDScript Resource、Packed 缓冲、计数分派/信号处理仍可能改变实例编号、CPU/分配成本和战斗墙钟演化。M1 本身保留音频墙钟 RNG 与渲染帧飞斧结算的非确定性，因此两轮不能仅凭 FPS 差值精确扣减探针开销，更不能当正常性能对照。

## 同一时钟的公共锚

仍继承原 M1 的配置/建场/观察器/清理。为了保存原来仅为局部变量的 `started`、`now`，生成驱动将**完整冻结 M1 `_run`**复制为子类方法，只插入 5 个唯一锚点位置：prepare、连接边界、原 started、原每帧 now、测量结束；反向移除插入内容后与原完整 `_run` LF 字节一致。公共 M1 文件本身不修改，原 raw interval、300 步预热、输入/状态检查和报告规则保留。该驱动须作为“带诊断锚的 M1”标记，不能称为零修改的继承 `_run`。

- `physics_frame` 信号：Time 时钟 + Engine physics ID；打开步时立即把 signal 时间另存为本步标量，避免下一步信号覆盖上一步尚未收取的时间。
- `_on_tick`：先收上一步，再恰好调用一次父观察器，然后记录本步 M1 tick、Engine physics/process ID 及观察时钟。上一步可以已在 presentation 处收过，pending 为 false 时不会重复。
- `process_frame` 信号：记录同一 Time 时钟、Engine process/physics ID，包括没有物理步的呈现周期。
- `begin_measurement(started,start_tick)`：直接使用原 M1 刚取得的 started，先完成热身末步归档，记录实际开始 tick/行边界。不是按 `tick==300` 猜测墙钟起点。
- `presented(now,physics_tick)`：使用原 M1 计算 raw_frame_ms 的同一个 now；收该呈现周期最后一步，再记录区间起止、process/physics ID、M1 tick 和半开 step 行范围。零物理步可显式为 `[n,n)`。collector 自身发生在 now 之后，成本会落入下一原始间隔，不冒充本帧完整物理成本。
- 测量结束同钟记录 start/end；`_dispose(b)` 用传入 b 禁用处理、补收 pending 末步、停探针/断开信号，然后执行原父清理。父已清空 battle_ref 的情况不丢末步。

分析器要求每个 presentation 的同钟区间与对应原 M1 raw_frame_ms 精确一致；每个所包含物理步的 signal/observer 必须落在该区间且 process ID 一致，过程 signal 也要属于相同 ID/区间。起止 tick、总数、行范围必须无漏/无重。首测若引擎的真实 signal/frame 顺序不满足这些条件，严格失败并审查，不放宽成近似关联。导出的 `collected_us` 只是归档时间，不当 physics 完成时间；原生四段也不能与完整 Battle/Unit 再相加。

## 独占、导入与执行

默认准备/检查命令已执行：

```powershell
python scratchpad/separation_sections_diag/prepare.py
python scratchpad/separation_sections_diag/static_checks.py
python scratchpad/separation_sections_diag/launch.py
```

未来根任务完成审查、独占 Godot 后的唯一执行入口：

```powershell
python scratchpad/separation_sections_diag/launch.py --run
```

引擎路径取 `--godot`、`GODOT_PATH` 或当前 checkout 被忽略的 `godot.local.txt`，先解析再把安全助手的 ROOT 指向副本。不硬编码本机路径。

隔离工程没有共享的 `.godot` 缓存，故先执行一次有界 `--headless --editor --import`（首次最长 300 秒，属于素材/脚本准备，不是性能窗口）。导入前后要求所有已有源/metadata 字节保持；允许集从副本中原本缺少 UID 的全部 `.gd` 精确生成，本次声明 76 项，不能只列两个新增诊断脚本。每个实际新增 UID 都须格式合法并记录原脚本与 UID 哈希；原 UID 不得改写。来源扫描包含隐藏文件，根目录缺失、扫描失败或未知源增加都拒绝。导入警告/错误、源变化或未知新增文件均停止，不开始测量。

导入与 timed/clockless 各自使用独立空 APPDATA/LOCALAPPDATA 目录，仅传给子进程；不修改父环境。固定项目拒绝自定义 user-dir，实际 QA 启动立即校对 `user://` 归属。原 Campaign QA/玩家配置哈希逻辑仍执行。本方案不使用未知 `--user-dir` 参数，不复制真实玩家配置/内容补丁目录。

共同锁仍为当前工作区 `.godot/redraw_rejection_source.lock`。测量使用冻结的增强进程助手，导入使用同样精确 Popen 所有权与退出确认；超时/中断后 kill+wait，无法确认退出时保留句柄/锁。运行前后另对当前 M2C 关键源取原字节 SHA，只为证明未改动，不把它用作旧版本输入。不调用任何生产恢复/reset；未知源变化保留收据和锁，由根任务处理。归档、副本、导入日志和两轮报告都留在本次 runs，不做递归删除。

## 根任务首次 review 的关键点

1. 比较 `instrumentation.patch`：只有四阶段时钟/原分支计数；完整旧 solve、唯一调用与复制的 M1 `_run` 插入点反向恢复证明是否符合预期。
2. 先看独立工程导入/初始化。此前已有启动时 Autoload 过早解析风险；新 Ledger 不引用 Autoload，驱动的原 M1 仍通过 root 取 Settings。静态检查不证明 GDScript 解析通过。
3. 检查第一轮所有 same-clock/frame/tick 严格约束，特别是本步 signal 保存、presentation 收末步、零物理帧、M1 真实起止；不要将新锚误当完整 physics 或 GPU 时间。
4. 两轮只诊断 buffered 分派比例和 `profile_cells` 预算。clockless 用于识别明显探针干扰，不能无条件相减不同战斗。若成本小/覆盖少/扰动大，停止；没有证据不写单 profile 优化。

43 项检查包括 Python AST、11 份冻结源、唯一入口/出口/调用、原体恢复、manifest 缺根目录/错误类型/扫描失败拒绝与隐藏文件/缓存边界，以及合成的 2+1 追赶步同钟关联。缺末步、重复 tick、缺阶段、错时钟零点、错 process ID、重叠行范围、raw interval 不一致、重复分派、clockless 带时钟值共 9 类异常均拒绝。这些是准备证据，不是引擎计时或正常 FPS 结论。

## 已失败导入的受控续跑

`resume_contract.json` 冻结原失败记录、原 `base.tar` SHA 与当次完整 pins。`resume.py` 默认只读核对并写 `resume_plan.json`；必须显式 `--run` 才启动。不会复制大工程、抽换生产文件或覆盖失败日志。

```powershell
# 使用本机实际引擎路径；若传入 _console.exe，只选择已存在的同目录非 _console.exe。
python scratchpad/separation_sections_diag/resume.py --godot "<本机 Godot.exe 路径>"
python scratchpad/separation_sections_diag/resume.py --run --godot "<同一本机 Godot.exe 路径>"
```

续跑在共同独占锁内重新读取原 tar 的每个文件、验证 Git commit 标记和原字节哈希，叠加四份当次冻结 generated 源，以此重建完整应有清单，再与失败 run 的 private project 逐文件比较。只允许原 76 项声明中的合法新 UID；对本次续导入前已存在的 UID 也冻结原字节，不能借第二次导入改写。根目录、扫描、归档目录逃逸/重复/大小写冲突等失败立即拒绝。

首次严格 raw 预检正确拒绝了 1,182 个 `.import` 差异，记录在 `resume_source_mismatch.json` 与 `resume_preflight.log`。随后 `resume_metadata_readonly.json` 逐项确认它们只有 CRLF→LF，零内容变化。根任务授权后，仅原 tar 内的 `.import` 允许原 raw 或原始字节精确 CRLF→LF；其他文本和二进制仍严格 raw 相等，UID/path/参数任何内容变化均拒绝，已是 LF 的文件也不得在第二次导入反向改为 CRLF。原 raw、允许 LF、当前 raw 逐项保存在 `resume_import_policy.json` 和续跑收据。完成导入后，测量阶段冻结实际 raw，不继续容许规范化。默认预检已通过：3,226 个重建源文件、76 个合法新增 UID，合计 3,302 个当前文件；没有启动引擎。

原失败 run 的缓存只用于继续导入，不是已通过或性能证据。新的 `resume_runs/<UTC>/` 保存自己的计划、导入日志、600 秒超时收据和后续两轮报告；直接启动经验证的非 console 引擎，通过同一个增强 Popen 助手确认进程退出。重新导入必须成功且严格无错误/警告，然后再核对全部源/metadata，并冻结完整 `.godot` 缓存清单。测量前后所有已有导入资源、类/UID及其他非 shader 缓存必须不变；只有 `shader_cache/` 下变化可接受并逐项记录旧/新 SHA。导入缓存和 shader cache 本身不归档为成绩。

随后复用 `launch.py` 的 `measure_pair`，只执行 timed/fixed/10 秒、clockless/fixed/10 秒，仍保留原 300 个物理步预热、驱动/账本与分析器；不自动延长。每轮独立 APPDATA/LOCALAPPDATA，启动后的实际 user:// 校验继续保留，外层也只读记录真实玩家 settings/campaign/screen 哈希。任何无法确认的进程退出、未知源变化或锁归属冲突均保留锁，不自动恢复或覆盖文件。新 23 项临时反例覆盖精确 UID、源缺失/漂移、二次导入改 UID、归档异常、精确 `.import` 换行转换及 shader/资源缓存界限，不启动实际子进程。
