# V25 真实对象 capture 负例候选

外部未执行 GD/scene；公共源码和已交 QA 原文件均未修改。没有 Godot 解析或原生资格。精确接口、命名用例和 future producer 谓词见 `CAPTURE_NEGATIVE_INTERFACE_V25.json`，当前静态 API 闭环见 `CAPTURE_NEGATIVE_STATIC_V25.json`。

每个角色、每个命名用例必须启动新的独立进程和新的私有 profile。输入来自同批真正成功退出的 A_single_save 世代 1。缺真实成功 A，工具受控 preflight 失败；不得以 DTO 正例、旧世界或失败存档替代。A 结束后、B 开始前，应冻结五份 A 文件和整个 `user://daming_safe_retreat_v25/continue/v1` 子树，包括对应 `local_runs` 收据。仅 slot 文件不足以完成 LocalLifecycle.prepare_resume。

输入 manifest schema 为 `daming_safe_retreat_capture_inputs_v25`，包含 first_role、content_version、engine_sha256、a_report/a_handoff/a_packet/a_world/a_slot 的绝对 path+sha256，以及 profile_files 精确清单。profile_files 每行是 `{path, sha256, relative}`，relative 为 SLOT_ROOT 下的规范相对路径，用 `/` 分隔。Producer 在新 profile 中复制这些原字节，并将 a_handoff 的完整原字节复制到 `user://daming_safe_retreat_v25/handoff_A.json`。工具回读完整 slot/journal 文件集合和 SHA，且实际 read_slot/Session 自身继续校验 canonical/chain/binding。相关原始证据可以使用不可变 owned copies；SHA 必须与 A 原报告、原 handoff 和原 slot 一致。

GD 继承原 `daming_safe_retreat_cross_process_v25.gd` QA 模块，只复用完整 `_restore`、packet/world/时钟/bindings 审计。原模块 SHA `6a70e00e6a7786bdf8791b84e3fdfdbe85159bf5398ec8ab385f2e34a3242940` 必须随子工具复制到私有工程 tools。子工具重写 entry、run、脚本加载、报告、证据写入、观察方法和 _hold；不调用父自然路径、B tick driver、save 或旧 _hold，也不加载 route 模块。

_hold 的清理和连接检查完整取自外部 v24s QA GD，SHA `76ed6f114de755b398112778ddabf5af820a30237b75070a5a2aaaea188b87db`。仅清除本工具完全相同的两个 unbound callbacks，前后核对其他监听器未变，连接和等待每条路径均显式清理。v24s 在本候选准备时尚未取得原生资格，不据此宣称 HELD 方案运行通过。

实际流程为完整 Session.prepare_restore → stage_mount → commit_restore_async → 真实 barrier HELD，完整回读 packet/options/settings/root/flags/context/binding、世界全部 section/wrapper、时钟边界和信号。随后建立完整 live capture 基线，保存真实对象字段的原 typed reference 与深副本，仅临时改一处 live 属性，实际 Core.capture 必须返回固定错误码，立即同步恢复原字段，再完整实际 capture。没有 await、手动 tick、信号、免死、位置搬移、grid 清空或 runtime patch 插在临时修改和恢复之间。

19 个已实现固定用例覆盖 queue、五个停止字段、另一角色 hp/_dying/active membership/outcome/Level reference、Root selection 和两个 caster、safe/outcome/freed/rescue 配对。真实 Unit.capture 的原错误码没有 Graph.validate 使用的 `UNIT_` 前缀；两条证据路径不得混用预期码。这里单 hp=0 或 _dying=true 是独立的旧 lifetime 守卫用例，不声称它直接覆盖后续 paired lifetime 分支。

恢复回验保留完整 before/after 世界原始 JSON。仅允许独立验证范围内的 Mission.stage_age_ms 和 Root.clocks.msec 前进：记录真实调用前后毫秒及同一个 stage 起点；物理/进程帧、逻辑 next_tick、simulation/cache phase、clock_values、所有其他字段/类型/IEEE 字节必须一致。完整节点顺序/ID、current_scene、canvas、HELD health、caller-owned identity 全部登记字段和原 typed 属性也必须一致。所有 cached grids/identities/blockers 通过完整世界精确比较保留，不予清空。

Session.commit 返回的 installed.identity 已经通过 Core.handoff_world 交给调用者。整个用例所有 capture 均借用同一仍有效的 identity，不能中途 dispose 后复用。最终先释放安装的 Battle，再释放 caller-owned identity 一次；installed Session.dispose 不再拥有它。每次审计写入新的序号 artifact，避免第二次 packet 审计覆盖第一次证据。

环境使用 DAMING_CAPTURE_PROFILE/OUT/CASE/MANIFEST/MANIFEST_SHA256/NONCE/EXPECT_CONTENT/EXPECT_ENGINE，加上四个 profile 子目录 APPDATA/LOCALAPPDATA/TEMP/TMP、STEAM_DISABLED=1、CAMPAIGN_QA=1。OUT 必须为尚不存在的外部目录。scene 为 `res://tools/daming_safe_retreat_capture_negative_v25.tscn`，报告为 OUT/report.json，schema `daming_safe_retreat_capture_report_v25`。

Producer 必须逐角色、逐用例核对实际不同 PID/nonce、新 profile、原生退出码与日志零 ERROR/SCRIPT ERROR、完整真实 A 来源链、所有 raw artifacts SHA 和每条实际 check。使用 exact role×case 集合，不用最低检查数替代覆盖。report.passed 只表示该单行实际流程；whole_live_capture_matrix_qualified 和 overall_v25_qualified 保持 false，待独立 producer 聚合真实完整结果。

五个 live cast 数组负例尚未实现；record schema/identity 类型没有可随意修改的 live leaf，目前只由独立 DTO 负例覆盖。组件负例和整体 V25 资格仍未完成。任何原生失败均保存原批次和收据；修复须新 sibling，禁止覆盖已执行工具或把未执行项标为通过。
