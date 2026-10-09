# 本夜截止收尾验收清单（准备稿，2026-10-08）

本清单只定义“按计划推进到香港06:00，再同步 GitHub、供公司继续”的本夜边界任务。它没有观察当前后台，没有执行复原、提交、推送、暂停心跳或关闭 goal。组件、部分原生案例和静态工具审查均不等于全开发计划完成；所有未完成计划保留。

截止为 **2026-10-07 22:00:00 UTC＝香港2026-10-08 06:00**。Root须到该时刻、且下列收尾实证都具备后，才关闭这个有界任务。到时不启动新开发/QA批，也不改已执行工具的截止；收尾清理、真实结果归档与同步必须做完，不能仅因时间到了就宣称完成。

## 1. 时间与本线程后台真实终态

- 用实际 UTC 时间工具/系统时间核对截止，并记录最终收尾时间；先用 `get_goal` 核对所关闭的确是本夜截止任务，不能把长期“全项目完成”目标代为关闭或恢复。
- 由 FX 唯一观察者交付本线程最终状态；Root收集自己持有的 PTY/后台会话最终退出结果。不得因长时间没输出、Godot窗口消失或某个旧 PID不存在而猜完成。
- 列出本夜所有实际启动的 producer/run及其 own native child。逐个核对 `receipt.json`、每阶段收据/原日志里的真实 `exit_code`、`process_terminal`、`stop_reason`、PID/nonce、最终源/原生核验及 cleanup/release 结果。Python producer也须真正结束、收据写完；只确认 native child终止不足以解除源冻结。
- 当前入口不断有新后继，最终必须从唯一观察者取得实际完整列表，不能照抄旧PID。已知历史包括 r2a/07ad37bf、r2d/8f3d393d、5284b47e；文档所述最新 r2f/71d4275a及任何此后实际启动后继也须纳入，具体路径以实际输出为准。**本准备稿没有读取这些活跃后台文件。**
- 区分正常完成、断言/解析失败、共享引擎恢复占用中断、到点停止。保留每次原 producer、冻结工程、profile、原日志和失败收据，不覆盖、混批判绿或清掉半写事务。
- 核对自身锁最终释放/原所有者仍持有的异常状态。不能删除其它任务的锁或停止/发消息控制盲盒/其它任务。Root如需终态交叉确认，只按收据确定的 own PID/父子关系做只读 CIM核对，不凭进程名清场，也不输出可能含登录参数的 CommandLine。

需查：实际运行会话最终输出、`qa/zhu_wounded_20261005/raw/<实际run>/receipt.json`及steps/native_evidence、`retreat_explorer_shared_interruption_review_v25x4.json`、`prefix_interrupted_delivery_v25x7.json`、`second_prefix_interrupted_delivery_v25x9.json`和随后实际生成的交付收据。归档副本须同原完整 bytes/SHA；原绝对路径只保留来源链。

## 2. 最终资格判定与两候选条件复原

- 必须读取实际最新资格字段和完整用例集合。`complete=true` 若只指 import、prefix-C、实际 A探索或某组件，不能充作 full v25通过。若缺真实 C、双方 A、任一 world/component/live矩阵或双方 B/C/D，full仍false；保留已经实际通过的狭窄范围。
- 原 v24s 资格是四个 JSON边界源码及其办理半程完整ABC。新六源码候选与其部分结果单列，不将原 C342、旧四文件资格或准备的用例数量接成新六源码 full资格。
- 当**所有引用这两份 Root源的本线程冻结输入后台已真实终态、最终审计/收据写完，且 full仍false**时，才按已预审范围逐文件复原：`scripts/run_battle_world_core.gd`与`scripts/run_level8_unit_contract.gd`。若 full实际合格，则按真实资格另行收尾，不能执行此回退。
- 写前重新核对两份当前 after SHA、QA proposed、改前备份、QA original和当前 HEAD blobs。任一未知变化先核清，不能覆盖。只复制两份已验证的 before原字节，随后逐文件读回确认等于备份/HEAD，不用 reset/stash/全目录 checkout。
- 候选代码、六源码声明、所有原失败/中断证据均保留；这不是删除未完成工作。不得在尚有 source guard读 Root时提前复原，人为造成输入漂移。

需查：`E:/ChatGPT/night_wrap_preparation_20261008/RESTORE_SCOPE_REVIEW.json`、已同步副本`qa/zhu_wounded_20261005/night_wrap_restore_scope_review_v25x8.json`、`E:/ChatGPT/daming_safe_retreat_v25_preapply_20261008/applied.json`及两个before文件、`safe_retreat_candidate_v25x1.json`、`proposals/daming_safe_retreat_v25/original/scripts/`和`proposed/scripts/`、最终实际 full或partial收据。

## 3. 四份已资格源码和同步范围不受影响

下面四文件不得因复原两候选而改变；核对当前 raw SHA、当前 HEAD blob、原 qualified receipt一致：

| 文件 | 已资格 SHA256 |
| --- | --- |
| `scripts/run_snapshot_store.gd` | `581e638b8f0ce7cb24d5533b03ee94b99732c5cffcbf373b1a5a69a1618d8251` |
| `scripts/run_slot_store.gd` | `d67fe7794f23fe1bda3d74c7e284ba6b90d2cb488a5d35cb1a187eea77fa3532` |
| `scripts/run_scenery_json_boundary.gd` | `476ee2ee83a513d29a0db04b5dc08eb5a3dcd6895a036697ed368b28c5d5c6ea` |
| `scripts/run_scenery_json_boundary.gd.uid` | `9f13d4502be15ab7149a43832ca61aaa0622a47e769a72f55d23a6bc29c0523d` |

需查：`daming_admission_continuation_qualified_v24s.json`、`native_ownership_json_candidate_v24q.json`、两文件复原前后收据，和 `git status --short --branch` / `git diff --name-only`。复原到原已验证源码的字节检查不等于重新跑过引擎；截止后不为收尾额外启动一批测试。

## 4. 最终 QA、文档和原计划完整

- 更新 `docs/WORKLOG.md`、`SOURCE_SETUP.md`、`DEVELOPMENT_PLAN.md`、`HANDOFF_20261007_OFFICE.md`、`OFFICE_START_20261008.md`和本次设计/QA收据。顶部用最终实证替换“刚启动/仍等待”的当前状态，历史段落和原失败保留。
- 每份 QA交付记录来源、实际终态、完整/partial资格、原文件SHA、独立 PID/nonce/slot/journal/source链和未执行项。出现partial只报实际已运行的检查，不把计划264/362/live24或旧批数字当新通过。
- 限定术语：observed effects once不等于全部 callback invocation count；local terminal不等于真实 Campaign cfg持久写盘；fixed defense/30 local journal不等于已绑定战役章节；Steam-disabled/zero run_id不证明真实 SDK奖励。普通启动不证明原生恢复。
- 原计划逐项保留：v25完整真实双角色流程及 source/JSON/component/live-cast负例、v26Slot类型守卫、真实章节日志/持久Campaign进度、付费生产/船体运输/其它章动态/自然胜败与奖励、同版九玩法EXE、美术/UI/多尺寸、正常时钟长跑性能、Android真机。组件通过可标其具体scope，不能关闭这些 whole-plan门槛。
- 原同步与已发布 Steam Build/公告状态独立，当前收尾只源码/QA/文档同步；不新发布 Steam/Android、不合并main，不借本夜任务恢复原已暂停长期目标。

需查：实际新交付收据/白名单清单、上述docs最新顶部及完整后续计划、`docs/STEAM_UPDATE_20261007.md`的既有发布边界。隔离QA fixture来源完整可作为证据提交；真实玩家存档、登录/Steam账号缓存、密钥、`.godot`、安装包不提交。

## 5. 公司入口真实可读且不包装未完成执行器

- README顶部、SOURCE_SETUP顶部、办公室交接均链接实际已提交的`docs/OFFICE_START_20261008.md`，命令必须为字面路径，无TAB/CR误转义；`tools/run_local.ps1`实际存在并支持 `-Mode import`。
- 明确 stable已资格四文件、QA两候选的具体路径/来源，以及最终是否已回原。普通源工程用Godot4.6.3可先 import/play，不要求先编 reader；SteamService无steam/test环境提前return，native依赖安装只由隔离QA producer调用。
- reader/vendor的只读依赖检查仅是新原生恢复QA基线门槛，缺它不把普通开发说成被阻塞。setup脚本只写vendor，不自动给普通Root安装addons。
- 公司fresh新机不能接今夜后台、旧物理cache、同机四小时/monotonic/PID来源复用或硬截止。已授权按计划续做，公司继续时建立新office sibling/当次截止、本机bootstrap+import+新baseline/私有profile/独立门禁；不改旧已执行工具，不把尚未提供的fresh适配入口写成已可运行。
- 最新 full参考实际继承链，缺真实 A来源时仍blocked；A-only gate不解锁 full。办公室先完整新基线原回归，再真实双方A/三矩阵/BCD，不跳过当前缺口。

需查：`OFFICE_START_NEXT_R1.md`与`OFFICE_START_CORRECTION_R1.json`的原保留证据、`OFFICE_NATIVE_SCOPE_CORRECTION.json/.md`、最新已提交office文档、`tools/run_local.ps1`、`docs/STEAM_INTEGRATION_20260907.md:42`、当前 producer独立审查及 deadline/source/cache门禁。只需核对命令和技术前置，此清单不要求本夜启动公司验证。

## 6. 白名单提交、推送及远端独立回读

- 确认仓库`https://github.com/winterzh/Liangshan-Heroes.git`、分支`codex/sync-20260905-stable`和远端变化。逐文件列白名单，检查大小、敏感内容及staged diff；未资格两候选不得混入生产提交，只保存QA proposed/original和状态文档。
- 不全盘 `git add`、不复用其它任务临时 index、不force、不rewrite、不自动stash/reset。工作区存在来源不明变化时先核清，不能把别的工作一起推送。
- 相关只读检查包括 `git remote -v`、`git status --short --branch`、`git diff --cached --name-only`、`git diff --cached --stat`、`git diff --cached --check`。按实际文件提交，然后 `git push origin HEAD:codex/sync-20260905-stable`；保留最终commit及白名单/检查/推送收据。
- 推送返回成功后还必须独立执行 `git ls-remote origin refs/heads/codex/sync-20260905-stable`（或可信连接器readback）并与预期commit SHA exact匹配；不能只看本地origin ref。最终交接文档/候选/QA必须确在该提交里，不能仅存在本机目录。
- 最后 `git status --short --branch`明确区分本地修改、本地提交、远端同步；留出的未完成变化必须说明，不为凑干净而删证据。新机器正常开发用已回读stable，历史PR1已合并关闭不操作。

需查：最终提交SHA、推送stdout/exit、独立remote readback、逐文件manifest、最终status、文件大小/敏感排除记录。此前任何中途stable SHA都是历史，不代替最终回读。

## 7. 暂停一次性心跳6，再关闭本夜目标

- 已只读核对`C:/Users/Administrator/.codex/automations/6/automation.toml`，id为`6`、名称“水浒明早6点收尾交接”，其prompt要求同步完成后暂停，避免后续日期重复运行。实际停用须用automation工具，保留原name/prompt/notification和其它字段，不能手改TOML或误停其它心跳。
- 到点、全部收尾和远端SHA确认完成后，Root调用 `automation_update`把id6设为PAUSED，并再view确认；这一步的实际返回状态作为收据。若暂停失败，记录错误、继续处理，不假称已暂停。
- 上述终态、源码/证据保全、实际文档、stable远端、office入口、id6暂停都确认后，Root才 `update_goal(status=complete)`关闭本夜有界任务。读回实际goal状态；若实际目标仍是全项目完成，不得用本清单代为标complete。
- 最终回复给出：本夜实际交付范围、真实后台终态/缺口、生产四文件与两候选状态、最终stable提交SHA、office入口及仍开放的计划、心跳6已暂停。任何未完成必需收尾项明确保留为未完成；不能因钟到、token预算或部分 native通过自报整体完成。

本清单只是外部准备稿。以上每一项都须由Root在最终时点查真实证据；本稿没有填充任何最终“已完成/已暂停/已复原/已推送”的结论。
