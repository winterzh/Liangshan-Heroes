# V25 负例工具当前候选

当前只读静态交付为完整世界 DTO `daming_safe_retreat_negative_world_v25b2.gd/.tscn` 和真实对象 capture `daming_safe_retreat_capture_negative_v25c.gd/.tscn`。接口分别为 `NEGATIVE_WORLD_INTERFACE_V25B2.json`、`CAPTURE_NEGATIVE_INTERFACE_V25C.json`。来源指纹与文本守恒自检保存于 `NEGATIVE_SUCCESSOR_SELFCHECK_V25.json`。全部是外部文件，公共源码和所有旧工具/接口/审查原件均保留；没有 Godot 解析、引擎运行或原生资格。

两个独立原审查为 `NEGATIVE_WORLD_INDEPENDENT_REVIEW_V25.json` 和 `CAPTURE_REVIEW_V25.json`。Root 已静态核对本次 canonical 分支与成功 handoff 节点收尾修复。新的整个原生矩阵仍须独立 producer 实际执行，不能将静态审查当运行结果。

DTO 原 132 个命名用例的 source/json 两路均保留，共 264 个计划行。18 个 json identity_int 经过真实 Store._decode 后，JSON 将裸整数 1 解析为 Float，原 Base 精确 canonical guard 返回 NONCANONICAL_RECORD。因此这些行不创建 Core、不给 Core.prepare，也不声称执行 Core 零分配审计；Core constructor/prepare=false、instance_state=never_created、no_allocation_audited=false，initially_empty/zero_world/battle/identity/plan 观察值全部 null。实际 document hook 返回的完整 DTO 必须只比原 packet 多出目标 Int→Float 一个叶类型变化，其余字段/type/IEEE 保持完全一致，parsed 原输入也不变。

其余 246 个计划行真正调用独立 Core.prepare，保留原精确错误码、原拒绝层与 dispose 前三项零世界观察。source Int 继续由强类型 pair guard 拒绝；JSON Float 1.0 继续到 pair guard。没有绕过 canonical、修改 Store、泛化数字转换或缩减用例。接口每一条 route_expectations 都提供具体 code/layer/flag/null 规则；Producer 不能对 18 个 Slot 行误套 Core 观察断言，也不能用检查数门槛代替完整命名集合。

两个正例完整 Core.prepare 后，工具额外实际观察 Core.dispose 是否归零。计划行数只是接口集合，任何未执行过程的 report/check/case 数均不得虚构。

capture c 保留 19 个实际对象字段负例、每个角色/每行新的进程与新的 A profile。actual invocation flags 默认 false，仅在真实 negative Core.capture 调用前置 true，缺源/preflight 失败仍 false。完整 Session 安装、packet/world/时钟/回调审计和同步单字段修改→拒绝→恢复→完整再次 capture 的成功路径未改。

修复的失败收尾是：Session.commit 成功后已将 Battle 与 identity 交给调用者，后续审计仍可能 return null。c 的 _restore 在 actual installed.battle 返回后立即单独记录 owned_installed_battle；finish 只 queue_free 这个明确已交付的自有场景、等待释放，再 dispose caller-owned identity 一次。即使 run 收到 null，也保留这个指针。不会猜 current_scene、清 menu 或清其他 Node。

_hold 及四个连接清理 helper 的函数体与外部 v24s 来源相同；自检比较经过 CRLF 统一及尾部分隔空白去除，另保存原整个文件的实际字节 SHA，不声称 EOF separator 字节相同。v24s 在工具准备时的原生资格未由本工具确认，不据此宣称通过。

两类工具必须使用真实同批、成功结束的 A_single_save 世代 1；producer 独立观察 A PID 终止和日志/报告通过，再冻结 input。原五份 A 文件及 packet/world 在 A report.evidence 的 SHA 绑定不能省略。capture 还必须复制完整 SLOT_ROOT 子树（包含 LocalLifecycle 收据）和真实 handoff 原字节到隔离 profile。只有 slot 文件不足以完成实际 Session 恢复。

Producer 逐行独立核对原生退出码、日志零 ERROR/SCRIPT ERROR、实际 PID/nonce/profile/content/engine、完整来源/产物 SHA、所有 checks、完整 case×route 或 role×case 集合和对应 flags。失败保留整批，修复创建新 sibling。真实 capture 五个 cast 数组负例尚未实现，record schema/identity 的类型负例仍为 DTO 范围；独立组件负例、Identity.configure 运行后是否不漂移和整体 V25 资格均未由静态自检证明。
