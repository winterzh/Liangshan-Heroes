# 本地战役章节语义与持久进度：下一阶段外部提案

本提案仅由当前源码只读审计产生，没有修改公共源码、当前冻结工程、已执行 producer、v25s1 或任一历史 profile，没有启动引擎。当前 A 探索的资格和完整原开发计划不变。本项须在该批终止、来源重新冻结后单独审查、实现、运行；本文不是候选源码或原生通过收据。

## 现行为与准确边界

`LocalLifecycle` v1 保存 6 个字段：schema/generation/token/context/state/victory。context 固定为 defense/空 level_id/30；gen1 是 active/false，gen2 是 terminal/实际胜败。constructor 只接 token 和 slot_root，没有章节参数。

首次 Session 保存先创建或核验 gen1 日志，slot 以 uncredited/token/receipt_sha256 引用该 active 原文件 SHA。恢复先读 slot，再按 token 打开日志；日志处于 terminal 时拒绝，active 时核对 head generation 和 exact raw SHA；挂载前再次核验。原锁、canonical UTF8/payload/envelope、previous SHA、CAS、死进程恢复、原持有者 retry 都真实生效。campaign slot 的 context 为 campaign/level8/0，而日志仍是 defense/空章/30，这是当前 API 的真实行为。它没有让当前 token/hash binding 失效；已有证据只证明本地 active/terminal 生命周期，尚未证明日志的逐章节归属。

`Campaign._save()` 只有 `CAMPAIGN_QA == "1"` 会提前返回 true，未写 campaign.cfg；当前 v24/v25 QA 正是该路径。普通分支先尝试 load 旧 cfg（忽略 load 返回码），保存 progress schema/unlocked/records/owner 和既有偏好，preserve 未知 section/key；cfg.save 失败返回 false。`record_level_result()` 忽略此 bool，仍在内存修改 records 并报告 accepted=true/new_story_seal；`save_prefs()` 也不传播 bool；`apply_cloud_progress()` 传播 _save bool，但先修改内存。ContinueFlow 先提交 local terminal，随后 Battle._complete_end 才冻结 result、调用 Campaign.on_level_won→record_level_result→_save；之后无条件报告 terminal_completed=true。故不能从 terminal 已落盘推导 campaign 进度已落盘。

两个真实失败窗口需区分：同进程 cfg 写失败被忽略；进程在 terminal gen2 后、cfg 成功前终止。现有 6 字段 terminal 日志不保存同局结果，旧 slot 又被正确拒绝，无法据它重放丢失的 progress。这是需新增的恢复语义，并非已证明 hash 链损坏。正常 Campaign 胜利如果从未保存，receipt 为 null，Battle 当前直接走 _complete_end，也不获得本地可恢复进度 intent。

## 最小连续步骤

先做章节语义合同，再做真实普通写盘收据，最后补进度失败/重启恢复。三者分别记资格，不能让第一项或 QA=0 单次成功写盘替代最后一项。不得先改现批冻结输入，也不得从旧失败 profile 改 schema/context/SHA 来制造通过。

### 1. 明确 expected context，并保留经典 v1

为 LocalLifecycle 增加来自安装代码的 immutable expected context；constructor 第三个参数 default 为 Profiles.CLASSIC_CONTEXT，使旧 classic caller 和旧 journal 原字节、magic/app/owner/path、active1→terminal2 合同保持。参数先按 Variant 受控类型检查，再使用 Profiles.normalize_context + Profiles._installed；不信任保存路径、caller bool 或 journal 自报章节。

v1 仍只接受原 classic schema 和 exact defense/空章/30。新 campaign journal 使用明确新 document schema（建议 local_campaign_continue_lifecycle_v2），绑定固定 installed campaign context。旧 v1 journal 若被 campaign slot 引用，返回明确 legacy-context-unbound/context-mismatch；保留原文件，不默认把 defense/30 重新解释成 campaign，也不伪造迁移。旧 classic v1 的 read/binding/terminal 和故障 suite 必须 byte-compatible。

Session.save_held 在现有实际 Battle/classify/context 守卫后，用 source._official_context 新建 receipt；已有 receipt 除 script/token/directory 外必须 exact context 匹配。Session.prepare_restore 从已完整 Slot 校验的 context 选择安装 profile，将 expected context 固定在新的 LocalLifecycle；prepare_resume 和 stage_mount 的二次 read 均核对它。context mismatch 必须发生在 Core.prepare / Battle / Unit allocation 前。

ContinueFlow 的 terminal 入口在 END 后、非 physics 的原主循环位置再次核对 actual classify、Battle official context 和 receipt expected context。context 失败维持原暂停/error/pending 协调，不进入 Campaign/Steam/UI。classic 不变；public campaign save/continue gate 仍关闭。不得通过 journal 的默认 context 推导 actual Battle 章节。

新 v2 若需要增加字段，只对自己的 exact schema/fieldset 合同增加。所有 identity leaf 类型先 guard，finite integral JSON 数值仅在已定义 generation/waves 字段规范化；不泛化数字或 drop unknown 字段。canonical raw check、完整 original input snapshot 和原 source-type 拒绝必须保留。Base store 不需要放宽或替换。

### 2. 真实 campaign.cfg 写盘结果可观察

将本地进度 pure projection 与落盘分开，保留原 best single-run / story_complete OR / 不 union 跨局 goal IDs 的规则。on_level_won/record_level_result 返回明确 accepted（逻辑是否接受）、persisted（真实写盘+回读）、persistence_suppressed（仅 QA==1），以及失败 code；不能用 QA _save 的 true 宣称 persisted。保存失败不得向调用者报告 durable progress，也不得提前 cloud mark_dirty 或新 progress-completed 信号。

Battle/ContinueFlow 根据 persisted 结果区别 local_terminal_committed 与 campaign_progress_committed。terminal_completed 现有含义不能悄悄当成二者；补精确字段，只有两者实际完成才对本项报合格。正常 fresh campaign 胜利未曾保存的路径也应有同样失败策略；否则只能称“已保存并恢复之 campaign”范围。

普通 cfg load 的非 OK 且非明确文件不存在时必须保留旧文件并拒绝写，不能重建后丢掉未知 section/key。写入采用 owned temporary candidate + ConfigFile 回读 + original cfg SHA/CAS 验证 + 受控替换；原 _load/public path 不变。失败和成功后的全 cfg 原 bytes/SHA 与 semantic progress 均保留证据。替换的实际原生/平台细节须另审，不能凭 rename 宣称断电原子性；本阶段只证明正常进程退出/重启持久性。

相应 prefs/cloud 三类 caller 必须逐一处理返回契约。cloud_owner、未知 sections/keys 和其它玩法偏好不能被进度重放覆盖；回读只比较真正保存的字段，不能要求 current/skirmish 等未写入 cfg 的启动旗标随文件恢复。

### 3. terminal→cfg 的失败窗口需要持久 frozen intent

只传播 _save bool 或把 cfg 写入提前到 terminal 前，均不能完整解决现有窗口；保持“本地终局先闭合，再露出结算”的原顺序。推荐在新 campaign v2 的 gen2 terminal 内记录严格验证的原同局 frozen result intent（或其固定最小 progress 投影），由 actual Mission.result_snapshot 取得，含固定 context/token/result schema/contract/source identity 和需要的 progress fields。完整 result/packet/world 原证据仍由 QA 保存，runtime 不嵌整套 world、不双层 Codec 压缩、不运行 Mission/level factory 来解释 intent。

新 v2 精确状态为 gen1 active → gen2 terminal(progress_pending) → gen3 terminal(progress_applied)。gen2/gen3 均拒绝旧 active slot；gen3 是 cfg 成功写盘/回读后的确认，preserve token/context/victory/frozen intent，previous_sha 精确链接 gen2。它是新 schema 的严格扩展，旧 v1 active1→terminal2 不变，不能让 v1 接受 generation3。MAX_RETAINED=4 已能容纳 3 条；仍拒绝跳代、跨 token/context、更改 victory/intent、缺 predecessor、canonical/byte/SHA 变化及 live lock 偷取。

cfg 已成功但 ack3 尚未完成时，保留同一事务只重试 ack；进程中断后，独立 recovery API 从已验证 gen2 的冻结 intent 确定性重放 non-additive Campaign projection 并回读，再提交 ack3。恢复只能应用进度，不重新构造 Battle、tick、Mission callback、胜利画面、new_story_seal 提示或 Steam.settle。原 terminal() 的跨对象拒绝和“仅本对象或原锁 retry 可确认本对象结算”规则不得因恢复而放宽。

恢复需检查本地 profile / cloud_owner 仍属于原 intent 的作用域。新 token 不继承旧失败 intent；固定 contract/profile/version 未被安装时明确拒绝并保留。若需要 UI 的 first-story-seal bool，记录最初 pure projection 的决定供同一次结算用，不用重放后的内存状态新发提示。gen3 仅是历史成功 receipt：后来合法偏好/关卡进度可改 campaign.cfg，不能把历史 full cfg SHA 当成永恒不变条件。

有 slot 的 continuation 可先按其 token 找 pending intent。无首次 save 的普通胜利必须在 terminal 阶段创建同样 scoped local receipt，且 startup 有受控发现 pending intent 的入口（有界、纯读取、仅本 profile/local_runs/合法 token/固定 magic owner；不跟链接，不读任意脚本路径）。若这部分未实现，整体 normal-fresh-campaign durability 字段必须 false，不能借 continuation route 代替。首次实施可只启用已独立验证的 Daming intent 合同；其它七章继续在原计划，不能从 normalize_context 支持八章推定八章 progress recovery 已通过。

## 影响范围与调用审计

必须变更候选：LocalLifecycle 的 expected context / exact v2 状态；WorldSession receipt 创建与两次恢复检查；Campaign pure projection、真实 commit 返回/读取失败控制；ContinueFlow terminal/recovery 协调；Battle._end/_complete_end 的结果冻结和 durable result 分流。新增纯 validator/commit helper 如有，应单独 .gd/.uid，固定 API 和 source SHA。Base store/Slot/world/Core/Cast/Unit 不需要为该语义放宽；当前 six-source 冻结不动。

现有生产 _save callers：record_level_result（上游仅 Battle._complete_end→on_level_won）；save_prefs（menu 随机波开战、settings_panel.close）；apply_cloud_progress（SteamCloud._apply_profile）。on_level_won 和 record_level_result 另有 QA 工具直调，须保持 source-only 回归语义。SteamCloud 会校验完整 account profile，再 apply；Steam-disabled private route不得走此调用。Settings.save 是另一文件，QA=0 会开放写盘，仅能在自己的 isolated profile 验证。

ContinueFlow._restore 当前同步 commit_restore；campaign 真正布局常须 commit_restore_async。新持久进度测试可用实际 Session 的完整 async 安装并明确不证明 normal Continue button；若要同时验正常 private ContinueFlow入口，须新 sibling 候选修 async 分支及 retained identity/menu/Battle cleanup，并独立回归 classic，不能用现同步入口的静态声明替代。

## 真正普通写盘的私有原生路线

新批使用正常时钟1.0/60Hz，fresh owned profile 重定向 APPDATA/LOCALAPPDATA/TEMP/TMP，Steam-disabled guard 保持。环境是 CAMPAIGN_QA="0"、STEAM_DISABLED="1"（源码认字符串1为启用；自然语言 true 不能写成 literal "true"）。ContinueFlow私有入口如被使用，还需原 LSH_CONTINUE_FLOW_QA="1"/PROFILE exact guard。去掉 LEVEL/SMOKE_TEST/SCENARIO/AUTO_MICRO 等会额外改进度或战斗的启动变量；只通过 installed flags选择实际章节。CAMPAIGN_QA="0" 对 SteamRunPolicy 仍是 nonempty test 环境，进一步关闭 SDK，但对 Campaign._save 不再 suppress。

沿既有 A/B/C/D 顺序另建 QA=0 immutable successor，不能改已执行 QA=1 批：A 真实普通任务/单 Lu 或 Shi safe，全 HELD Session gen1 save 后原 PID 退出；B 独立进程 full packet/world/clocks/bindings安装、普通 tick、resave gen2；C 再独立安装，另一伤员自然撤离到真实胜利，只从 actual Mission 冻结同局 result，actual ContinueFlow 提交正确章节 terminal intent、Campaign 写盘/原生回读、ack；D 完全新进程先由实际 Campaign._ready/_load 读 cfg，比较 unlocked、完整 normalized records（含 unrelated baseline）、owner、实际保存prefs和未知 sentinel，逐文件SHA。然后验证旧 slot LOCAL_RUN_TERMINAL 且零 Battle/Unit/Core plan 创建、journal exact chain/context/frozen intent和 cfg 在读后不变。Lu-first/Shi-first使用彼此 fresh profiles，不能复用半写 A。

每进程不同 PID/nonce，实际 terminated 前不能下一进程；原 report checks全真、日志零错误、完整冻结 input/native/source/engine/resources pre/post不变，slot SHA/gen链、local journal raw envelope/payload/previous/hash 及 cfg raw bytes/semantic读回均保留。正常写成功只证明该自然 route 的磁盘持久；不宣称 Steam奖励/回调总次数/完整战役或其它玩法通过。

另建可复核的 schema/context/fault suite：旧classic v1原 raw byte/source与JSON读回；新campaign v2正确章节；跨L8/L5/classic、非法mode/id/waves及 identity各类型受控拒绝、原packet不变、拒绝前不创建世界；gen1/2/3严格链；写盘失败不发progress success；gen2后process退出 / cfg写后ack前退出的原新测试profiles跨进程恢复；原owner换掉拒绝；duplicate重放不会union跨局goal或发新提示。文件故障是明确 isolated fixture，不能叫自然胜利证据；故障只能持有者恢复原事务，不以新对象或半写profile伪造通过。

已存在 v24o/r/s failed/success profiles 是不可修改的历史来源。新测试如需旧classic raw receipts，逐文件SHA复制到全新 owned fixture profile，仅测试兼容读取，不在原处迁移/重写。当前 A探索仍按原 source/QA=1执行，不借本设计变更它。

## 未关闭的完整开发计划

本项不替代 v25单Lu/Shi真实A/B/C/D及source/JSON/component/live-cast负例，不替代v26 Slot identity type guards。付费生产、船体/运输、其它章真实动态、八章自然胜败、真实SDK奖励、同版九玩法EXE、完整美术/UI/多尺寸、正常时钟长跑尾帧与Android真机继续保留。现行 DEVELOPMENT_PLAN.md 与办公室交接原文不改，文中历史资格按其原scope理解；本提案不承诺 Steam发布或奖励。
