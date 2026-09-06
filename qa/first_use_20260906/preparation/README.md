# 首次使用耗时实验草稿

仅作归因，不是优化候选或正式 FPS 基线。锁定 `4baafc1`；V2 绘制功能尚未纳入，后续必须显式重基并重审 pins，不能自动采用当前工作树。

当前准备分三层：

1. `inventory_preview.json`：只读当前目录的路径/字节清单。**未读取 Git，不能充当快照来源清单**；包含 untracked 的体积上界，不复制大量目录。
2. 显式 `prepare.py plan`：只读 Git 的固定提交，生成每文件 blob ID/字节数、导入关联/缓存 SHA256/字节数、总量和排除规则。没有 checkout、索引、提交、fetch 或源写入。此步骤完成后先看 `plan.json`。
3. 显式接受计划摘要再 `materialize`：从 Git blob 写入一个新的隔离副本，按计划复制当前导入缓存。所有目标位于本目录；不使用硬链接、符号链接、junction，不覆盖已有副本、不删除失败现场。不执行 Godot。

当前体积预览：2701 个来源文件、465,648,985 字节；整个现有 imported 缓存上界 2908 个文件、423,543,096 字节。两者合计约 848 MiB，**不是已批准的实际复制量**；Git plan 会剔除非快照文件和未引用缓存后给出最终明细。当前没有复制这两组目录。

## 来源、复制边界

Git 来源仅包含 `project.godot`、根目录 `icon.*`、9 个运行时目录 `scripts/scenes/assets/shaders/resources/data/addons/content/scenarios`，以及 M1 的 `tools/polish_performance_probe.gd` / `tools/zhujiazhuang_rts_test.gd`。以快照中的普通文件为准，拒绝符号链接。Sfx/Art/M1 probe/Battle/Unit 的完整 LF SHA 另外锁定在 `transforms.py`，防止无意重基。

缓存仅复制上述 Git `.import` remap 引用的 `.godot/imported` 产物及对应 `.md5`。预先核对：本机对应源资源的 Git blob ID 等于快照、导入配置等于快照、`.md5` source_md5 等于对应源资源。缓存另记字节 SHA256；计划和实际复制之间有变化就停止。**source_md5 是来源关联校验，不能证明缓存从未被其他软件篡改**；缓存当前字节摘要仍保留供复核。缺 remap/产物/摘要时不偷偷重新导入。

按后续明确选择，普通资源的 live 源字节、缓存 source_md5 或导入选项不匹配，以及缓存产物缺失，会在计划中标为 `needs_reimport`，逐项保留 frozen expected / live / cache 摘要、原因和目的路径；**该资源的全部旧 importer 产物都不复制，也不声称匹配**。冻结原始源（含 `icon.svg`）完整保留。其它已匹配缓存仍按原严格规则复制；追溯目录的 ignored-import 与普通资源的 needs-reimport 分开记录。

显式修正的唯一来源目录边界为冻结 `assets/campaign/source/.gdignore`，Git blob `9e8e5ec4e9a53531c71fdc65feb2f05b2f7b929d`。Godot 4.6 [官方说明](https://docs.godotengine.org/en/4.6/tutorials/best_practices/project_organization.html#ignoring-specific-folders)与[扫描实现](https://github.com/godotengine/godot/blob/4.6/editor/file_system/editor_file_system.cpp#L3208-L3227)表明，标记按存在性跳过目录树，内容不支持匹配/反向排除模式。该目录所有原图、历史 remap 和标记仍按冻结 blob 列入来源并复制；只不要求其 importer 缓存，逐条记录忽略依据和未复制目的路径。未冻结的新标记不能扩大范围；相似旁支目录、运行资源、跨忽略边界的 remap 都不接受这一例外。

计划只对这一标记进行 CRLF→LF 文本规范比对，同时记录冻结 Git raw/blob、live raw/LF 两套 SHA；已确认的 live 112 字节与 Git 111 字节只差一个 CRLF。标记删除、内容变化、固定 blob 变化、额外冻结忽略目录均拒绝；实际素材的 Git blob/source_md5 和缓存 SHA 规则不变。冻结 project/GDScript/scene/resource/shader 另做目录字面引用核对；有运行引用就停止审查，不据此跳过资源。该核对不是对任意动态路径构造的通用证明。

`global_script_class_cache.cfg` 是派生缓存：只保留路径在本次 Git 来源集合内的 class 条目；逐项读取该固定 Git blob，核对 `class_name` 和 `extends`（省略继承时为 RefCounted），拒绝重号、同路径旧类名/旧基类或不支持的声明格式。计划记录声明对应 blob ID、输入/输出摘要；输出 raw SHA 和字节数进入 materialization 收据，并在每次运行前后复核。旧收据没有该 pin 时拒绝运行。不复制 `.godot/editor`、shader cache、UID cache、原玩家目录、docs、QA、备份、导出、Git 元数据、本机 Godot 配置或其他临时工具。未来新项目类型/导入器不满足这些规则时，先修改计划并审阅，不自动扩大白名单。

副本只修改 `scripts/sfx.gd`、`scripts/art_db.gd` 和 `project.godot` 的最前诊断 Autoload 条目，新增 `_first_use/{ledger,driver}.gd`；副本 Unit/Battle 均保持快照原字节。正式共享源码完全不写。不要把 `generated_preview/` 当作可运行工程；它只有便于审阅的轻量生成物。

## 观测内容与对照

8 类记录：真实技能冷 `play_ability`、完整 `_build_ability`、WAV 转换、Art `_try_load` 尝试、Atlas 区域缓存 miss、通用动作/方向动画缓存 miss、非空 directional loader、strip 切帧。`_try_load` 返回空时是负查，不声称发生文件 IO；动画 miss 可能是负查/legacy 回退。TRES resolver 验证与正式取帧会保留两个真实调用。战役 variant 不是本次标准夹具的目标，不复制它的缓存判断逻辑来扩大观测。

每个包装只有一个原方法调用点，原完整方法只改私有名字、正文保留；逐步逆变换以及整个文件逆变换都必须恢复原 LF 字节。包装不预播、不取新随机数、不改返回值，不关闭声音，不新增 Unit 或战斗特效。原样保留的函数中本来就有的 RNG/WAV/Atlas 对象创建照常发生。

最前的 `FirstUseDiag` Autoload 在自己的 `_init` 分配相同固定容量：32768 个事件、131072 个 physics/postdraw 时点、128 层嵌套栈。记录整个 Autoload 启动、Music 等待、场景/夹具、原 300 物理步预热、过渡提交及测量 10 秒。阶段切换可读取已有 cache keys，不调用获取器加载资源。只在结束后展开 JSON。溢出或未闭合嵌套即失败。

`clockless` 保留同一份源码、Autoload/节点数量、缓冲容量、原方法和条件分支；关闭**诊断逐事件/逐 physics/postdraw 时钟**，仍保留 M1 原采样时钟、阶段边界时钟、cache snapshots 和调用计数。不能把它叫作完全无时钟的游戏。两个模式都相对于原生程序增加诊断脚本/节点，会改变对象 ID；包装判断、计时和数组写入也增加成本。新副本不复制 shader cache，图形初始化可能不同；控制结果不是可以直接逐帧相减的确定性重放。

M1 `_run` 由原文本定点插入诊断钩子生成；继承 `_new_battle`、设置、AI 输入和 `_on_tick`。没有重排种子或改 `WARMUP_TICKS`。采样保持 fixed、defense200、60Hz、1x、1440×900、Vulkan Forward+、正常 Music 完成、Master 静音；没有延长预热。10 秒入口强制 `acceptance_eligible=false`，没有 30 FPS 通过声明。

## 首次入口命令（尚未执行）

以下命令在项目根目录执行；Python/Godot 路径由本机参数提供，不写死在工具中。

```powershell
python -X utf8 scratchpad/first_use_diag/prepare.py inventory
python -X utf8 scratchpad/first_use_diag/static_checks.py
python -X utf8 scratchpad/first_use_diag/prepare.py plan
$plan = Get-Content -Raw scratchpad/first_use_diag/plan.json | ConvertFrom-Json
$plan | Select-Object snapshot,source_bytes,cache_bytes,plan_sha256
python -X utf8 scratchpad/first_use_diag/prepare.py materialize --accept-plan-sha256 $plan.plan_sha256 --instance entry01
```

先核对 `plan.json` 的来源/字节/排除和 `materialization_receipt.json`。取得 Godot 独占时段后，使用实际新副本路径运行**仅 1×10 秒入口**：

若计划有 `needs_reimport`，诊断入口仍禁止。本次 `entry01` 已按批准的复制计划完整落盘；原 `plan.json` 和 `_first_use/materialization_receipt.json` 保留原字节。`private_import.py prepare` 只读核对整个私有来源、原缓存、派生类声明和精准缺 UID 集合，生成另一个 `private_import_plan_entry01.json`，记录 helper/入口工具 pins 及 `run_entry.py` 的旧/新 raw SHA。它不会启动 Godot；原复制计划 SHA 不代表修改后的导入工具。

根任务取得共同独占时段后才执行导入。准备已完成时不要重复 `prepare`，它拒绝覆盖现有计划。

```powershell
python -X utf8 scratchpad/first_use_diag/private_import.py prepare
$importPlan = Get-Content -Raw scratchpad/first_use_diag/private_import_plan_entry01.json | ConvertFrom-Json
python -X utf8 scratchpad/first_use_diag/private_import.py run --accept-import-plan-sha256 $importPlan.import_plan_sha256 --godot '<本机实际非 console Godot exe>' --timeout-seconds 600
```

导入助手只接受本次一个 `entry01`，每个新导入计划只尝试一次，失败现场保留。必须使用实际 Windows Godot 程序，拒绝 `_console.exe`、`.console.exe`、`-console.exe` wrapper。取得共用 `.godot/redraw_rejection_source.lock` 后，在实际 Popen 前再次核对工具、来源及独占进程，使用 `--headless --editor --import`。只有确认持有的实际句柄退出且无 Godot 残留才解锁；超时、中断、扫描失败或无法确认退出均保留相应失败收据，不能继续启动。

来源采用 `os.walk(..., onerror=...)` 双重枚举和 raw hash，覆盖未知根文件、隐藏文件、空目录；只排除 `.godot` 与固定的本助手收据文件。拒绝重解析点、枚举错误及导入改写旧源码。只有原副本中已有 `.gd` 且缺 `.uid` 的 12 个精确路径允许生成自己的 sidecar；验证 canonical base34 UID 后记录真实 raw hash。重写的 global class cache 必须精确包含冻结的 18 条 path/class/base，核对实际私有脚本后记录引擎真正输出的新字节，不能伪造旧 hash。

导入成功后逐一验证全部非 ignored 资源的 frozen source MD5、实际目的文件 MD5 和 sidecar source/dest MD5，特别是原缺失的 icon 新 ctex/md5；冻结实际新缓存 raw bytes。通过最终复核且确认退出后，输出 `imports/<新导入计划前12位>/import_receipt.json` 与私有 `_first_use/post_import_pins.json`，连接原物化收据、新计划和完成收据。原收据不回写。`run_entry.py` 只有通过此链条及新 source/cache/class raw pins 后才允许诊断；导入、收据、类、UID 或缓存异常均不把 pending 改成通过。

```powershell
python -X utf8 scratchpad/first_use_diag/run_entry.py --mirror '<本目录内 mirror_*_entry01 的绝对路径>' --godot '<本机实际非 console Godot exe>' --mode timed
```

是否需要 clockless 控制或 3 重复，由入口是否正确、实际 miss 数量/耗时和长帧重合决定，不自动跑。需要控制时先用同一 plan `materialize --instance control01` 建全新副本，再 `--mode clockless`；每个副本只能启动一次，避免第一轮生成的 shader/派生缓存影响第二轮初始状态。

启动器只接受本目录内完整镜像；不给它原生产路径。它先检查当前 checkout 共用的 `.godot/redraw_rejection_source.lock` 和 Godot 进程，原子取得共用锁；在实际 `Popen` 紧前再次核对独占 token 和 Godot 进程。正式多窗口间隙只要共用锁仍在就拒绝，不再以本目录 `entry.lock` 代替共享独占。它创建独立 run/profile，清理从生产脚本发现的试验环境开关。每轮仅将 APPDATA、LOCALAPPDATA 指到该 profile 子树；HOME、USERPROFILE、TMP/TEMP、XDG 保持父环境值。最前 Autoload 验证 `OS.get_user_data_dir()` 在私有子树，否则立即终止，避免其余 Autoload 访问正常存档。Windows Godot 4.6 的 APPDATA 数据路径行为依据[引擎 Windows 实现](https://github.com/godotengine/godot/blob/4.6/platform/windows/os_windows.cpp#L2252-L2260)。这里没有复制原玩家偏好，因此与原生基线不是相同玩家磁盘状态。

超时/中断会 kill 并 wait 已持有的实际子进程句柄；不能确认退出、剩余 Godot 进程或扫描失败时保留锁/副本/收据，不继续启动下一轮。不杀其他任务的 Godot，不做生产恢复操作，因为从未修改生产。

## 结果读取

`runs/<UTC>_<mode>/` 保留 `report.json`（M1 字段 + first_use 事件/时点/阶段/对象 ID）、截图、`process.log`、`engine.log`、running/completion 收据及 profile。运行前后检查所有镜像源文件字节/路径集合和已复制 import artifact 摘要；任何差异都使诊断失败。启动失败同样保留现场。

事件 start/end 使用同一 `Time.get_ticks_usec`；带物理帧、process frame、fixture tick、阶段及 parent_event。按 frame_post_draw 的真实区间归并，嵌套的 cold play/build/wav 和动画/loader/region 要取**区间并集**或扣子区间后求独占，不能重复加总；跨阶段事件按时间裁剪。只有 `art_try_load_attempt` output_count=1 才是成功加载返回，0 只是查找/加载失败。load 耗时是调用者同步等待，不一概命名纯 CPU。

这里的 postdraw point 与 M1 的 `now` 位于同一信号的不同处理位置，时间戳不是同一次读取；不能仅凭数组下标宣布与某条 M1 raw 峰值精确关联。`capture_valid()` 只证明容量、嵌套和范围检查，首次读结果还须确认启动必经的 `_try_load` / `_wav` 记录确实存在，才能将窗口内零 miss 当作否定证据。

如果所有合成都在预热前，或窗口内耗时小/不与长帧重合，就保留否定结果并停止扩测。只有观察到占长帧明显比例的 miss，才考虑独立无战斗冷/热函数实验。诊断加速/减速、敌军消耗差异、原生 profiler 的一秒输出，都不能直接变成性能收益结论。

当前状态：前两次只读计划拒绝收据保留在 `plan_failure_receipt.json` 与 `plan_failure_icon_svg_receipt.json`。之后根任务明确选择保留全部冻结源、普通资源不匹配须私有重新导入的路径；已完成最后批准计划的唯一 entry01 私有复制，没有套用 marker 例外或跳过普通资源。**未真实 Godot 编译/运行**。新导入计划和收据链已准备，引擎首轮仍是必需的入口校验，不把静态检查写成实际通过。

有限复审、忽略边界与普通资源 reimport 规则后 **65 项静态/stub 检查通过**。包括同路径 class/base 漂移、派生缓存改字节/缺 pin、共享锁占用但无 PID、真正 Popen 前出现进程，以及祖先/嵌套/旁支边界、标记缺失/语义漂移、CRLF 双摘要、实际运行资源的跨界映射和未跟踪标记不能绕过缺缓存。未确认退出的 stub 保留的是自己的假工作区共用锁。静态检查内的进程/Git 调用均为内存 stub，未触碰正式共用锁；单独真实只读 plan 的状态另见最终计划收据。当前 M1 已有新改动，静态预览改读既存 `scratchpad/separation_sections_diag/frozen/tools__polish_performance_probe.gd`，仍逐字节核对原 `04a47115…` LF pin，不从 live 重锁旧基线。包装新增变量未发现 Variant 推断或驱动期 Autoload 全局解析阻断；这仍不是引擎解析通过声明。

最终只读复制计划见 `plan_review_receipt.json`：源码 471,441,406 字节 + 可复制缓存 256,218,148 字节 = 727,659,554 字节（约 693.95 MiB），派生 class cache 另 2995 字节。接受参数 SHA 为 `cb051680f879c5cbf47fd44536c127eddaa1e393ea799afff2d9692c28537ed5`。66 份追溯来源全部保留，11 条历史 remap 不复制 importer；仅 `icon.svg` 需私有重新导入。18 条类声明、116 份运行文本和排除交集已核对。随后根任务批准并已完成唯一 `entry01` 的 materialize，物化收据 raw SHA 为 `6417652d5cb63eeb6b6851f16d7b3a9561b7f7eadbbce0ebaf2c857e5934a777`，实际 source 2701 份（原 2699 + 2 个诊断脚本）。仍未运行 Godot，须先执行新导入计划。

受控导入补证见 `import_static_receipt.json`，全部是微型 Python stub，无真实引擎：覆盖 Popen 边界进程竞争、精确句柄 kill/wait、无法确认退出保留锁、严格枚举 onerror、未知源/空目录/UID、UID canonical 范围、类语义重写后的真实摘要、icon source/dest MD5、真实 `_console.exe` wrapper 拒绝及 HOME/父环境保持。原 65 项套件亦再次通过。引擎解析与真实导入仍待根任务执行。

最终冻结交接见 `materialization_handoff.json`。新导入计划接受 SHA 为 `9eb11c177d698e104b9fd4d226e9a687e89b66a8a83848d33faa21568ce38754`（计划文件 raw SHA `078dfd2710ac7ab112e28870bb1dabc1e831ff4e6847c6e7ce6b98c0123a6bff`）。`run_entry.py` 从 `8fce3951700ca2ebc6469f18ef283f31c06720ef344c7459f91dd1f15bb0cf26` 变为 `7d1ecd339c1622cc780992b43cbd7ba506f672bb3c245e22a5045e202bb4e292`；变化明确列入新计划。导入专项 33 项及原 65 项静态检查通过。私有冻结 Git 的 1198 份 `.import` 均为 LF，没有将其他副本的 CRLF 迁移许可泛化到本副本，旧 source raw gate 保持严格。
