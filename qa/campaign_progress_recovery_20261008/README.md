## 2026-10-09：回调原包严格消费者及 Unicode 拒绝修复

新增纯 packet 消费者 campaign_callback_packets_v1/v2.py 与逐字节 snapshot/source spec。只接受一次 ready 与固定 PID/nonce/case/线程的递增1..8 snapshot，核对原 instance ID、提供的 installed identity/user、精确字段和正常时钟；拒绝重复JSON键、非有限数、过深结构、类型变化、重放及任何通过资格声明。返回保留 original packet bytes/size/SHA；provided PID/identity只是绑定输入，ownership_proven/native_qualified始终false。此JSON只为观察投影，不替代Godot Variant/CFG/lifecycle严格语义，也不保存实际socket收发或生产栈。

V1封存10pins，58项可复现synthetic host通过；独立审查确认 CALLBACK-UNICODE-001：JSON转义孤立surrogate可被接受并推进序号，后续ensure_ascii=False UTF8保存失败。V1和其原封存不修改，保留为拒绝候选。V2只加JSON所有key/string的strict UTF8可编码核验，合法转义NUL保留；12pins含旧来源、60项synthetic通过，独立差异复审结果另见有限收据。所有检查只用原包/JSON夹具，没有真实socket/Popen/Godot、实际回调或原19资格，执行批准仍为空。

独立V1拒绝收据SHA `8aade94cf2a92236489e24cdd0d09200a07e570fae3d73525e0da2635a5a147f`；V2有限通过收据SHA `12127a04cf7a49ed216e6c078ff3151062b1772afde94b21f8f258a85625e6bb`，static=true/stages=[]、12pins/全10本地导入边闭合，完整CallbackPackets class AST与V1一致。独立12项差异检查及我方3项完整snapshot Unicode回归只属synthetic；未连接socket/Popen/Godot，不授实际回调资格。

新增 CONTROLLER_INTEGRATION_CONTRACT_V1.md，规定未来真实Popen持有关系、精确生产栈、首次原包收发全序与闭合证据，以及三类真实回调/云端路径；文件是设计，controller和三case driver/完整结果producer尚未实现。回读实际生产调用点无漂移；当前外部Godot PID41732占用、水浒来源锁不存在，第五完整批未启动。完整V12、原19、正式恢复接入、玩家入口/SDK和内容/性能/Android原目标仍待真实验证，无main/Steam发布。

## 2026-10-09：实际回调只读快照入口的有限源码预审

新增 QA-only campaign_callback_snapshot_v1.gd 与独立 campaign_callback_snapshot_wire_v1.py。候选只读取实际 Campaign/SteamCloud 节点，核对生产脚本路径、原 instance ID、私有环境和固定 PID/nonce/case/递增序号；只修改观察器自有注册与序号。新命令限定 lsh_callback19:read，原 debugger 命令白名单不变，没有 evaluate、set_variable 或生产节点替换。

独立收据 CALLBACK_OBSERVER_PRELIMINARY_REVIEW_V1.json SHA e5dfdd91bfc45731c952ba00bec11b4f652f009dcd9ffa44425947031aed18f3，static_api_closure_passed=true、approved_stages=[]、无确定有限源码阻断；10份来源 pin 与 wire snapshot 原字节一致。我方21项及独立24个固定包/10个拒绝检查均为纯内存 socket stub，没有建立连接、Popen 或 Godot。当前引擎提交源码获取返回404，保存的 Godot 4.4-stable 三份官方源码只是协议参考；当前引擎 GD 解析、暂停捕获/回复兼容性和注册生命周期尚未验证。

ACTUAL_CALLBACK_SOURCE_MAP_V1.json 绑定三个真实生产路径：确认 CFG 后内存发布再回调；真实 Cloud._apply_profile 内的 applying 回调；真实云端应用写盘失败。R12 正常云端路径在确认 writer 后才加载进度，未来故障验收须证明旧 Campaign 进度/公开 CFG 保留及真实 pending writer，不沿用旧矩阵的提前替换内存预期。设置/语言可先写入，不能宣称整个 profile 原子性；未来本地数字账号夹具须明确为 SDK-disabled 合成输入，不能证明实际账号、上传或奖励。

三个用例的完整 driver、owned debugger controller、有序证据消费者及 producer 尚未实现；观察器输入 identity 也不能独立证明安装身份。后续须绑定真实自有进程、精确进入的生产调用栈、首次原始数据包和来源后另审完整集成。原19、完整V12、玩家入口/SDK及原定内容/性能/Android真机目标仍未完成，正式恢复候选未晋升，无 main/Steam 发布。本次只收尾此有限源码部件。

## 2026-10-09：首次／重复终局完整五进程执行器源码接入

新增 run_campaign_first_repeat_v1.py：原完整V12 base5132/CoreContract/原26覆盖保持，增加已审GD共27覆盖；接入NaturalSerialBatch/publisher、完整74/21/80/21有序消费者V3。运行顺序为冷导入一次和同一真实隔离profile的first/restart_first/repeat/restart_repeat四次，完整五独立PID/nonce及四报告全部成功才授该两类终局/重启的有限资格。继承已审EvidenceSuite的first-byte ledger、persist和全源/原件/native/installed identity完整性；消费者在仍持有实际终态Popen时调用，未知child保留原lease与finalization规则，不替换生产节点。

--write-recipe仅生成无运行来源配方，不检查成功prior、不授执行资格；--write-spec/--run在任何新mkdir/profile/Popen前都必须真实核验成功且关闭的完整V12 all61与首次原receipt bytes，运行另要求精确新seal及独立阶段准入。当前 SOURCE_RECIPE logical `95bc3c36739a2a524f1e5f83e4a2ecfdd5bb49e30a1d703bfb497ea7e3222523` / raw `6cb31e3bfa46c087fd1f291b58383b68f14e219bd87165d8f79a780e95843417`，99pins/51Python/全178本地导入边闭合，只有recipe，没有成功prior绑定的source seal。

独立有限预备收据 SHA `28f0dd614f4b9cb1b4d54b784426209d21b806434b0a0f36948bfc11f3c9661b`，static=true、stages=[]、execution_blocked=true。source_recipe独立重建exact，五phase/ledger/callback/cleanup源码集成未见确定阻断。我方可复现四真实failed receipts分别source_spec和constructor共8次拒绝，独立方另核失败6409两gate；原receipt不漂移、workroot未创建。无新Suite成功、seal/profile/Popen/Godot结果，不能当五原生流程通过。

后续仍须取得成功全61前置，再封存当前完整执行器来源并独立准入、执行真实首次/重复及重启。当前四V12均终态失败，第五批未启动，共享引擎整批串行窗口与跨聊天协调许可仍未取得；继续其余回调/云端边界等源码工作。正式恢复源、完整原19/基线/UI/SDK、八章/九玩法/导出/性能/Android真机仍未完成，无main/Steam发布。

## 2026-10-09：首次／重复完整证据验证器；CFG复制拒绝与修复

新增完整报告消费者，固定 first/restart_first/repeat/restart_repeat 四个真实独立Popen、同private profile/user、74/21/80/21全部有序检查及唯一stdout标记、3/2原stage/public首次bytes、真实Mission/HUD/记录、原first handoff与新token、两token各生命周期gen1/2/3/ACK。真实CFG prepared/applied1/2→3/4全部14字段、source/request/previousSHA/原candidate与各次publicCFG/ACK绑定；首次会被正常prune的CFG原件和各次可改写publicCFG先复制到本步骤输出再ledgerfreeze，不把原可变路径错误当作永久不可变证据。完整producer仍未实现。

V1 SOURCE_SPEC 17pins/24根导入边；独立拒绝 SHA `fe0da0e38bdf8f53ed6cdff02467dfddc61ac65b9e1acfd484ce293be402ee49`，唯一确定 FIRSTREPEAT-COPY-001：capture把真实CFG文本交给JSON-validating publisher，会JSONDecodeError；原件不变且无目标/临时文件。旧源码、snapshot、封存和拒绝原字节保留。

曾按未成立的typed IDs推断创建V2草稿并去掉跨次semSHA比较。独立审查回读实际R12 Intent.validate_result的untyped ids与Coordinator规范化后撤回该疑虑；V2没有SOURCE_SPEC/准入，原18项primitive记录仅历史，不能支持生产类型或原生判断。后继V3恢复严格跨次semSHA条件，整个validate AST与V1逐字结构相同，只改capture/cfg_pair：CFG用新bounded binary no-replace/exclusive/fsync publisher，journal仍旧JSON路径。既有JSON publisher未修改。

V3 SOURCE_SPEC固定30pins/27根导入边（所有已pin源码/历史比较/脚本74条本地边均闭合）。独立预备 SHA `ef36f7695fa17153b8272e375ece98d58a02294bcdce966e1140936411a718bb`，static=true/stages=[]、COPY-001闭合。可复现20项我方与9项独立primitive host检查通过：CFG/非UTF8原bytes、禁止覆盖、JSON拒非JSON、原CFG两代复制与模拟合法prune、档案原copy漂移及fake terminal metadata拒绝等；均无实际Popen/Godot/完整consumer pipeline资格。每个CFG pair的primitive decoder检查不替代完整validate的跨次摘要约束。

下一步把已审GD/完整标签、runtime/publisher与V3消费者接入完整producer，再做精确来源封存和独立执行准入。此前四完整V12均真实失败（第四Lu A305项单场通过仍仅单场），当前无活跃水浒原生批；成功全61前置与共享引擎整批串行窗口仍未取得，跨聊天协调许可仍待回复。正式恢复源、原19/UI/SDK/内容/持续性能/Android真机未完成，无main/Steam发布。

## 2026-10-09：第四完整批真实中断；首次／重复终局发布组件预审通过

完整第四 V12 run8fe7b18b/session14695 已实际退出1，complete=false、lock_released=true。冷导入及 Lu A 原305项通过结果保留；Lu_world PID7688 运行约380秒时遇外部盲盒引擎，实际未完成，失败为 `Foreign engine after owned child start`。原 receipt/checkpoint/identity 和三份日志六文件逐字节归档到 `actual_foreign_interrupted_durable_chain_v12_r4/`，索引为 `ACTUAL_FOREIGN_INTERRUPTION_FULL_V12_R4.json`。之前START/Lu A记录只为历史观察，不能证明全链通过或当前存活。本轮没有活跃水浒原生批，第五批未启动。

真实第四终态 receipt 已通过后继 V3 source_spec 只读调用验证为拒绝，见 `FOURTH_FAILED_PRIOR_SUCCESSOR_GATE_REJECTION_V1.json`。单独 A 通过不满足成功完整61前置，未创建新 seal/profile/原生批。原工程与测试档案保留；完整原生验收仍须整批共享引擎串行窗口，跨聊天协调许可仍待回复，没有向其他聊天发送消息或控制他项。

新增 natural_terminal_exports_v1 与 natural_terminal_runtime_v1 部件及 exact snapshot。仅允许 first/repeat 三份原始JSON和两次restart各两份；原nonce-stage PID/nonce/SHA marker首次字节冻结、Windows no-replace发布逻辑保持。固定四mode/GD命令和1800秒上限，Popen前精确校验output/profile/nonce、原post-cold完整identity、Windows环境别名和已发布first/repeat原handoff token；实际poll发布，最终集合/log原pin；原清理handler逐AST相同，cold直接继承原phase，没有CLI或自行准入。

SOURCE_SPEC_V1固定17 pins/21根导入边（所有已pin Python连旧publisher比较共25条闭合）。独立部件预审收据 SHA `bf15305276c459193516c14f6ea61f7fbfee60ad37f952f7e14cd7c9c1ac91c4`，static_api_closure_passed=true/stages=[]，无新增确定阻断。可复现29项我方与6项独立纯host检查仅为synthetic，未构造真实Popen/Godot或证明活nativePID所有权，不能计为原生通过。

新增完整有序标签 builder/contract/snapshot：first74、repeat80、两restart各21，ready52/57，六identity字段、八演员和11→19普通订单全部保留。独立审查仅对源码重建合同，不称这些为实际通过数量。仍须完整有序host消费者、原CFG/两token三代原件持续核对、完整producer及成功61 prior后的精确执行准入；正式恢复源、原19/UI/SDK/内容/持续性能/Android真机仍未完成，无 main 合并或 Steam 发布。

## 2026-10-09：Lu A 实际305项通过与首次／重复终局源码候选

完整第四 V12 原 run8fe7b18b/session14695 已完成 cold_import 和 lu_a_single_save。Lu A PID5224/nonce846a793172b54059aed2a14ef974ef1c 实际退出0、错误0、complete=true；原报告305项全 passed，SHA `35b1421448a64f72c7a2133e82bd333168429cfb243d813aad75858e505c8107`，原日志实际标记 `DAMING_RETREAT_V25_COMPLETE A_single_save 305 true`。报告与日志逐字节归档到 `actual_durable_chain_v12_r4_lu_a/`，索引为 `DURABLE_CHAIN_V12_FOURTH_RUN_LU_A_OBSERVATION_V1.json`。仅证明原 A 单安全磁盘场景；全61仍未完成，不能转授原19/回归/UI/SDK资格。原会话已进入 lu_world，继续观察实际进程和终态。

新增 `original19_first_repeat_candidate_v1/`，候选 SHA `53e4e3a10ef6107f095ae1df9be355308200a99fee444dc68f912418ac6803ab`。真实普通黄泥岗路线，四进程 first/restart_first/repeat/restart_repeat 共用本批真实私有 profile；repeat 从真实首次终局原 raw handoff SHA/token/完整identity/context/原CFG/三代生命周期读回，重复自然通关新token且首次三代文件原件不变；真实 HUD 首次／已收录文本与四目标、印记/unlock 验证。不生成进度seed、调用伪造on_level_won、替换Campaign/Cloud/Battle/Mission或加速时钟。

独立有限源码预审 SHA `0bbd25b61f0e828a854dba663f3a6522c829d87187084c263d838ea8ef525b8a`，static_api_closure_passed=true、approved_stages=[]；9来源pin、五原route/helper函数及GDv6关闭nonce-stage发布函数逐字一致，真实Localize/HUD/lifecycle接口闭合。本机17项检查仅为源码字节/原函数文本，不是Godot解析或原生通过。仍缺新producer、fresh三文件/restart两文件完整发布集合、完整有序host消费和持续两token原件校验，须集成后另做精确执行准入；现故障版publisher的fresh五文件合同不能直接套用。SOURCE文件保留创建时状态，以独立收据描述当前预审范围。

正式恢复源未晋升；六故障 V3仍等成功全61 prior，剩余三类真实回调/Cloud边界及其余UI/SDK、八章/九玩法/导出/持续性能/Android真机均未完成，无 main 合并或 Steam 发布。

## 2026-10-09：六故障 V3 显式绑定成功前置收据

新增执行器 V3，移除 V2 固定失败6409批的源码常量。`--prior-durable` 必须为工程外的绝对 `receipt.json` 路径；创建 source seal 前真实核验成功且关闭的 V12 全61阶段及来源、原日志/报告/生命周期证据，封存首次原始 receipt pin。Suite 在创建新目录/档案/原生进程前再次完整核验，并要求 receipt pin 与 seal 完全一致；旧版本及原封存不改写。

V3 producer/snapshot SHA `243791416a34d6f4680b584f1c107b1d9897fa4c9ceebe1dc9b1cfa3d6db10eb`。独立有限源码预备收据 SHA `f79472ed9cf2f3c727c5d9163b09b64194e59d74014831272e1d18552f110600`：无新增确定阻断，只有 source_spec/main/__init__ 和新增路径检查变化，execute/validator/integrity/cleanup 与 V2 AST 一致，批准阶段为空。本机8项有限只读主机检查拒绝三失败 prior、新批未闭合 receipt 及四不合规路径；审查方另核实际失败/人工未终态和路径负例。均无成功 prior、无新 seal、无 Suite/main/Popen，不能计为13进程或原19原生通过。

完整第四 V12 仍接续原 session14695/run8fe7b18b；冷导入已通过，Lu A 仍等待引擎串行窗口。接续必须回读实际 handle/进程/终态，启动记录不是未来存活证明。只有取得新成功全61结果后，才能为 V3 生成精确新 seal 并审查执行准入。正式恢复源码未晋升，其余原19/UI/SDK、内容/性能/真机保持未完成，无 main 合并或 Steam 发布。

## 2026-10-09：完整 V12 第四新批已进入冷导入

复核当前无引擎占用及共享锁后，原已审 V12 无运行预检退出0，逻辑 SHA `867bd2d1b78339f357200e4dca344d14fb38a05c39f3e7906fe3f11507b60209` 不变。启动全新 `durable_chain_8fe7b18b`，session14695/host PID38692，未复用前三失败批的工程或档案。串行 idle60 后实际 cold_import PID45856 已退出0/错误0且 complete=true，原日志SHA已核对；主进程仍在运行等待Lu A，尚无终态/完整61资格。

历史观察见 `DURABLE_CHAIN_V12_FOURTH_RUN_START_V1.json`。接续必须回读原 session14695 和实际进程/终态 receipt，不能用本条或锁证明未来存活，不能因观察超时重复启动。原六故障 V2 仍绑定失败6409且批准阶段为空，不因第四批启动获得准入；须等新的完整成功结果后另建封存。跨聊天协调未发送，正式游戏源码和发布平台未变，完整后续范围保持。

## 2026-10-09：六文件故障执行器源码审查完成，第三完整批实际中断

后继 GDv6/controllerV5/consumerV2 已接入执行器 V2，设计为冷导入1次、六真实故障 fresh 和六同 profile restart，共13个原生进程；保留27个覆盖文件、完整标签和原件校验。V1 独立拒绝收据 SHA `fe7726a2a449324813c4d3a05c3b07edd5f53bf009880f36198a3f1f154faf46` 保留：前置 receipt 先 pin 后另读解析可接受 ABA 替换，journal 比较存在 bool/int 别名。

V2 将首次 raw 同时用于 pin 和解析，basis/interface 绑定原 pin，Suite 直接使用已核验的同一 prior 对象；完整 journal 使用递归严格类型比较。独立收据 SHA `051c4c59e547b89dd5b6f267dd6cd05dbe719066869935634d1f6cb22df77ee9`：静态接口闭合通过，106 pins / 50 Python / 139 imports；5项有限主机核验通过，只含人工边界检查与失败 prior 只读拒绝，不是原生通过。SOURCE_SPEC_V2 逻辑 SHA `c68c2bb6fd7fcff26f5656e88dfc9c3bf9c25de40d8d9c739c87502b8e2cfa2f`，原文件 SHA `96b8cf7d08db110f969ea724b24af4af482c2dd99e0573e8e50838d2efc25ea3`。批准阶段为空，execution_blocked=true。

第三完整 V12 批 `durable_chain_6409dde9` / session32145 已实际退出1，complete=false、lock_released=true。冷导入 PID44236 退出0/错误0；Lu A PID27128 在外部 Godot 启动后退出1/未完成，错误0不代表通过。失败为 `Foreign engine after owned child start`，原 receipt SHA `57398e21aa160f694424b53e46d35d59d0c40304d3d6b69aabe80cc9c6e3a607`。五份原始 receipt/checkpoint/identity/log 已逐字节归档到 `actual_foreign_interrupted_durable_chain_v12_r3/`，索引 `ACTUAL_FOREIGN_INTERRUPTION_FULL_V12_R3.json`；旧启动观察只为历史，不再作为当前存活证明。原私有工程与测试档案保留，未上传测试 profile。

第四完整批与六故障批均未启动。当前执行器绑定的失败 prior 不得复用，须在取得新的成功完整61进程结果后另建来源封存和准入。跨聊天协调许可仍待用户回复，未发送协调消息或控制他项。十四份正式恢复源码未晋升；完整19/UI/SDK、八章/九玩法/Windows导出、连续性能/Android真机仍按原计划继续，无 main 合并或 Steam 发布。后续顺序见 `docs/NEXT_DEVELOPMENT_20261009.md`。

## 2026-10-09：完整六故障 consumer / seed来源 / 标签合同

新增 `ORIGINAL19_FILE_FAULT_FULL_LABEL_CONTRACT_V1/V2/V3.json` 和生成器各代：完整95/98 fresh、20 restart、56 ready prefix、19最终普通订单全部有序，实际Bai父关卡八演员和6identity字段固定。Source/check/标签不降格为少数关键assertion。

`ORIGINAL19_FILE_FAULT_EVIDENCE_SOURCE_SPEC_V1/V2.json` 固定 consumer/严格9-string envelope和14-field CFG decoder、故障前实际seed原件归档controller、完整标签及各代源码。V1 review SHA `1e33bef5ce5e77be900e10827c64321d254b1259218e0c8669993b9fd0911474` 拒 CODE-001（实际outer CFG_STAGE_READBACK）和SEMANTICS-002（原提案未绑定final语义SHA）。原件不改。

V2 spec `faa50f…` / review `99f6890c21986d859c4689f4bce6dfe0cf3aabaf7dd7b6c0ad1ce4d6f17e9014`，42pin/13tools/26edge，source-only/stages=[]。GDv6输出实际原生proposal.sections摘要，pending16字段；controllerV5/consumerV2绑定四candidate final g3/g4语义，prior保持无原proposal范围。Seed原CFG/两代档先复制并固定SHA，再结合真实最终两代/生命期三代、原packet栈、target原backup、repair、重启验证；不freeze正常会prune的旧生产seed路径。

我方32项primitive和审查方9项host检查均synthetic/noNative/非整pipeline。真正launcher还须接入新GD/16字段controller与consumer并独立审核，不授六故障/全19/玩家继续。完整V12现原会话32145/host32920仍等待外部引擎，0原生阶段，原总体计划与正式源不变。

## 2026-10-09：六故障 runtime 与闭合 JSON 发布后继

`ORIGINAL19_FAULT_RUNTIME_SOURCE_SPEC_V1/V2.json` 固定 runtime、controller v3、host atomic/raw-byte publisher、GD v3/v4、原件 snapshot 和导入闭合。V1收据 `75192e…` 拒绝 ENV-001/PUBLISH-002/DIAG-003：未提前绑定实际环境、Godot不同名rename会删除目标、诊断栈可被无关前文decoy满足。全部原字节保留。

V2 spec SHA `774cefb368faa74059f8c7b5c1987e04a93d3f03bed8e370ddabec0e0d79e489`，39pin/11tools/26edge；review SHA `cbb744e1815b9814d78277b93d19ee2f4132397b31033524dfc26527dc2337e2` 静态部件通过、stages=[]。GDv4没有rename，关闭nonce-stage后输出actual PID/nonce/fixed-name/SHA；host冻结首次closed bytes再no-replace发布，要求fresh5/restart2原件、公有JSON最终SHA一致。启动前精确step/identity原pin环境；预算只能该ERROR紧随的parser/backtrace/R12 frame，其他native ERROR/SCRIPT/Parse零容忍，不猜候选写失败额外允许。原自然路线/check/report v2 exact。

SYNTHETIC_HOST_CHECKS_V2.py/.json可复现20项纯host（环境/alias/identity、同块/decoy诊断、半UTF8/半marker、完整原字节发布、PID/nonce/重复/缺项/漂移），V1十二项原记录保留；审查方另做十二项有限host检查。没有真实Popen/debugger/新GD解析、完整producer或原19资格。

完整 V12 第三批 session32145/Python32920/run6409dde9 已准备，当前仍等外部引擎39900自然空闲，0个原生阶段。DURABLE_CHAIN_V12_THIRD_RUN_START_V1.json只保存历史live启动观察，不证明当前存活/退出；须回读相同handle，不能因此重启。正式源和平台未变。

## 2026-10-09：无启动入口的实际文件故障控制器候选

PRELIMINARY_REVIEW_V1 SHA `6a9c9eb0c1b4197ec79f4f4922dcb3ccd00c5fe1b2d7cffc0f89fa96d2df9bfe` 拒绝 `DEBUGFAULT-PENDING-001`；V2 SHA `c6bbfb60b07b8142266b22295523e5ca639affb0af0bcc5c3255cde2e0ba2cb4` 解决该项，静态部件预审通过，均 `approved_stages=[]`。真正 proposal/对象、监听栈、Popen 所有权、错误预算和完整聚合仍需后续执行器独立准入及真实结果。

独立 `ORIGINAL19_DEBUG_FAULTS_SYNTHETIC_HOST_REPRO_V1_V2_R2.json` SHA `160d7a5b6904a48f75a757f16de324c610dcca7f95830a4b8fec221da5d481dd` 为纯主机人工夹具：V1 七种漂移均错误修复，V2 同七种均在首个文件变更前拒绝，负 RefCounted ID 正例恢复原字节。跳过真正 Popen、debugger 和构造器，不构成六实际自然故障资格；R1 长路径失败脚本保留，R2 新短私有路径未触碰玩家档案。

`ORIGINAL19_DEBUG_FAULTS_SOURCE_SPEC_V1/V2.json` 固定两版 tools helper、源码 snapshot、真实自然故障 GD/SOURCE、R12 相关源及完整本地 Python 导入；V1 19 pins/6 Python/6 edges，V2 23/7/9。HOST_SOURCE_PREFLIGHT 仅 SHA/AST/原源码断点检查，HOST_GUARD_CHECKS_V1 六项仅私有临时文件字节边界，不验证 Popen/debugger/native。

独立审查指出 V1 在核完整 pending/gen1/gen2 前就修复文件。V2 保存原 ready/生命周期，修复前必须重读其首次原始 SHA、当前 exact gen1/gen2 且无 gen3、完整 intent/旧 memory/cloud、原 CFG SHA 与实际 proposal/stage；typed 比较拒绝 bool/int 别名，RefCounted ID 按非零整数允许负值。旧 V1/spec/snapshot 不改写，后继独立收据分别保存，approved_stages 均应为空。

当前仍只有部件源码，无新原生批、无整个六故障/full19/SDK/玩家恢复资格。完整 V12 预检退出 0 且原逻辑 SHA 未变，但此前两次原生中断仍为失败，不能复用其 A/profile。真正 producer 的监听/串行流程、精确预期诊断预算、完整报告及独立执行准入还须完成。

## 2026-10-09：六真实自然文件故障V2源码预备通过

original19_natural_file_faults_candidate_v2/ORIGINAL19_NATURAL_FILE_FAULT_PRELIMINARY_REVIEW_V2.json SHA d27dc6005b1cd7d140b968b438ab64340c101263d53604a2fd28528e83d3089d 已实际回读：first原UTF8 bytes SHA/pending原SHA/current+repair声明双等原SHA闭合，static_api_closure_passed=true/approved_stages=[]。candidate664749…/SOURCEca0399…匹配，原六断点/路线/实际对象和gen2-gen3/restart声明保留。

本轮只源码候选及独立预备审查，没有Godot解析、debugger controller、expected-native-diagnostic预算运行实现或实际六case结果；未来完整producer必须另审并固定所有原raw pin，不把这里当全19/玩家恢复功能交付。正常full61与其余5原ID/额外UI/SDK/性能/设备计划继续，协调授权仍待用户回复，没有新Native批或正式源码晋升。

## 2026-10-09：六故障V1原注入custody拒绝，V2first-raw修订

V1独立预备拒绝收据SHA cf109c7e7104fee2155bbf982a0ef679461e2c9cb4bd10f3f0f2915b7e789bc6：唯一FAULTGD-CUSTODY-001，repair原声明只比较当前injection SHA，可接受pending之后文件替换，未绑定pending原SHA。旧GD/SOURCE/14source-preflight/拒绝收据原字节保留，stages空/没有Native或controller。

后继original19_natural_file_faults_candidate_v2/源码SHA6647491fd2ae38e20bbce89351f0e7ba6e59763f52578827dbadb22d99797df9，SOURCE SHAca039915860cde53fc06681e59c6318a5185dc8cd1391062d0439061e7d9984e。只修first raw UTF8 bytes/1MiB bound/当次SHA定义→核currentfileSHA→parse；pending保存这个firstSHA，repair只能在currentSHA==pending.firstSHA且其声明==pending.firstSHA时通过。六实际source窗口/原普通naturalroute/同实际对象/gen2-gen3/restart其余不变；预备集中复审中，无Godot解析/controller/Native。

水浒没有active第三完整批；其余完整19/正常full61/SDK/八章/UI/玩法/性能/真机全部原计划不变。跨聊天协调消息仍等待用户授权，未向其他聊天发送。

## 2026-10-09：原19六真实文件故障自然终局源码候选

新增original19_natural_file_faults_candidate_v1/ GD与SOURCE。它继承原真实黄泥岗普通玩家订单/四目标/15guards无击杀/八survivors路线，先用实际Campaign.save_prefs真实正常private priorCFG，再等待本批自然terminal与actual coordinator gen2。六原ID保留：bad_existing_cfg_load/existing_vanished_prior/write_failure/save_OK_fresh_load_failure/readback_semantic_mismatch/readback_SHA_changed；SOURCE逐SHA/函数/精确源码行绑定真实R12 CFG读写断点及caller约束，实际host只能操作这批的已观测原SHA/private文件。semantic-mismatch在当前更早expectedSHA守卫拒绝，明确不声称后来semantic比较已到达。

GD记录actual pending ERROR/code、未gen3/未展示、原Campaign+真正Cloud状态不变、同coordinator/writer/lifecycle/intent/可用frozen proposal；host repair需原mutationSHA与pid/nonce/case绑定，之后GD通过真实可见RetryTerminal压信号并检查同对象完成、原gen1/2不变/gen3确认，继续原natural postterminal/restart门禁。pre-staging prior-load失败不捏造frozen CFG，onlyprepared release与staging retention按实际API分开。

当前只有source prototype、独立预备审查中；没有debugger controller/source admission/error预算运行实现、没有Godot解析/Native结果，不把它称六实际故障通过/完整19或UI/SDK资格。正式源未修改；水浒全61仍两个foreign中断失败、无active第三批，跨聊天协调许可请求仍待用户回复。其余2自然first/repeat及3真实回调/Cloud边界source尚需适配，原完整计划保持。

## 2026-10-09：GDv5/helperV3源码预备复审通过，仍无Native批

两独立预备收据已按原SHA回读：original19_data_layers_candidate_v5/ORIGINAL19_DATA_LAYERS_PRELIMINARY_REVIEW_V5.json SHA fbf67c77d77d9911707732f19faab6688da4863515b60e8fabeed5b21d1bb274；ORIGINAL19_DATA_EVIDENCE_PRELIMINARY_REVIEW_V3.json SHA c1233f270dc194977149f59e8f9c1bf7848ea386871758366a5daa6dffeda0b2。两者static_api_closure_passed=true/approved_stages=[]，原4纯host反例与cleanup/doc/metadata同类alias均拒绝、正常exact pure进度正例通过；21pin/14Python36edge、原45check/109顺序/七commit/14历史/final两代源码闭合。没有Godot解析/Native/实际新109结果，不授尚未实现的新producer或完整19。

本轮Git只提交两次foreign中断原档、各代候选/拒绝与预备收据、强typed证据helper/完整标签合同及交接。水浒Native两批仍实际失败、无active第三批；跨聊天协调请求待用户回复，尚未发送其他聊天消息。后续继续新全61实际验收、新来源绑定的原回归/UI/数据四进程与剩余11原机制/SDK，再完成八章/美术UI/九玩法/性能/Android原计划，不缩范围。正式恢复源未晋升，不合并main/Steam发布。

## 2026-10-09：原19证据helper拒绝与type-exact后继V3/GDv5

旧helperV2的独立拒绝收据 ORIGINAL19_DATA_EVIDENCE_PRELIMINARY_REVIEW_V2.json SHA803c65fe400981854c9bbd7bdfaeb77abb46a3ce38cab4021f0d532003dacc2f 已保存、stages[]：DATAEVID-TYPE-001，Python宽松相等可接受unknown blob int1→True、其他原record False→0/0→False等类型漂移，whole记录顶层type无法证明子树保留；DATAEVID-REVISION-002，copy名13/14未绑定entry实际g，可把11/12原件放入13/14名且借已知head14SHA放行。四个纯host反例独立复现，未Native；旧源/spec原字节保留，不使用为执行准入。

GDv5仅加每个原progress unknown key/level8 unknown field/完整other record的真正ConfigFile单值canonical+native Variant/container metadata，所有snapshot与真正保存前原expected都导出；fresh native CFG原SHA与copy57完整绑定保持，原45check表达式/109以及7commit/14历史链/final13-14不变。ORIGINAL19_COMPLETE_LABEL_CONTRACT_V3.json绑定新源，其余109/QA20合同不变。新helperV3只读验证recursive typed_equal用于未知blob/wholeotherrecord/progress/原expectation/document/cleanup/trusted_scope/flatchecks，逐键集与exact builtin int/class string/script bool核metadata，每entry实际g必须expected g且filename==record_%g，headSHA必须来自真正末条原件。新原unknown subtree probes与实际seed/fullprogress/最终refusal阶段全部逐比，不以JSON宽松相等替代ConfigFile值语义。

ORIGINAL19_DATA_EVIDENCE_SOURCE_SPEC_V3.json rawSHA676bc571caead5946fbb3c0b2348bd4b7bc62d15223ac074ed4e42dfbdb348da：21pins/14Python36imports完整闭合（历史比较源也闭合）；helperSHA02f36d889fa77841703908f33ef445648969ea1c90dc76729011f65200d323d4，GDv5SHA7ce9db7fb774a6d1cd591574561cb443bdc2ea4c38d15757fc3e33da0348611b。ORIGINAL19_HOST_SOURCE_PREFLIGHT_V3.json重新核所有pin/AST和原check表达式；仅源码，Godot解析与Native false。当前集中独立预备复审中，无newproducer/Native准入。

完整V12两个旧批均已foreign中断关闭、无full资格，仍没有waterNative第三批；跨聊天串行协调问题仍等待用户授权，未发消息。正式源未晋升、原剩余11机制/UI/SDK/八章/性能/真机等全部计划保留。

## 2026-10-09：完整V12两批受外部引擎中断，原19数据证据候选继续

V12 fb1da6e0/session53980在cold30492期间外部Godot进入而自有终态1，errors0/lock_released=true、A未启动；原项目/profile保留，三raw及索引在actual_foreign_interrupted_durable_chain_v12/和ACTUAL_FOREIGN_INTERRUPTION_FULL_V12.json。确认原自有句柄/PID均退出后，使用同一未改已准入producer/spec/review全新retry6b31df47/session17670；cold45348实际0，LuA10036再次受盲盒Godot进入中断，终态1/errors0/lock_released=true，未获A证据/全链资格。五raw（receipt/checkpoint/postcoldidentity/两log）及索引在actual_foreign_interrupted_durable_chain_v12_r2/和ACTUAL_FOREIGN_INTERRUPTION_FULL_V12_R2.json。当前无水浒Native批，未开第三重试，未控制外部引擎；已请求用户授权联系盲盒聊天“检查 GitHub 同步状态”协调串行，尚未发送跨聊天消息。

原19六数据层GD V3与V4新增原生证据声明：每case before/after CFG原bytes、fresh ConfigFile全semantics/type_metadata/progress，七实际原成功commit的request/intent/originalSHA/receipt/physicalSHA和即时真实retained二record pair；每对在下一次生产prune前复制，生产仍只留两代，未来host可核全部14历史原链/final13-14，不覆写存储策略。V4另实际seed progress未知pref、target record未知flag/blob及合法level2未通关原record，原14合法Variant仍完整；原45处check表达式与109顺序均保持。两完整label contracts V1/V2封存data11+7/20/10/14/30/16+1=109、两QA每mode20全部3branch。

两GD源码预备独立收据都已落盘且stage[]：V3 SHA8e8108a5dd4eab45073b06467c1a455e11630d4f07c84a8cef7cc98dc8bcf917；V4 SHA2d073695be7aa06bff385c7d9eb53ee6f83d889564afa0acd174dc9d7cc3bbe8。131GD/实际R12/父store/API与标签已核，均非Native/producer准入。

新增standalone helper campaign_original19_data_evidence_v2.py及ORIGINAL19_DATA_EVIDENCE_SOURCE_SPEC_V2.json，正在独立预备审查。helper要求原完整label有序/typedcase、原copySHA/固定57文件路径、14全九stringenvelope/CFG14字段/previous原SHA/immutable prepared-applied/request/intent/source-account/real receipt、最终physCFG/native semSHA/fullprogress/14未知类型及progress未知/targetblob/其他level2保留、四invalid实际payload/code与原CFG绑定。此helper尚未接producer/运行，不把它或GD预备通过称8项Native/完整19；旧V1执行器仍因原两finding拒绝，其他11原ID/UI/SDK和全开发计划保留。

## 2026-10-09：完整V12限定审查准入，新61批已启动

DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json SHA 0dd6fcaff8773a185872747332b7376b36c72649db312deb072bcf3c9044fc92 已按第一raw字节回读，唯一approved_stages=[durable_chain_and_matrices]；producer/spec三SHA精确匹配。独立实际核验InputsV7及SpecV12与封存完全相同，116联合pin/29Python72edges/26overlays、基准5原档/219项31组和成本汇总闭合。6000只审计预算，不授矩阵速度/游戏性能/full19/UI/SDK/整体资格。

已启动唯一新自有完整批 D:/CodexTemp/lsh-durable-chain-20261009/durable_chain_fb1da6e0，session53980/ownPython30988；全新UUID/project/profile与本批actual A，从完整源码冷导入开始，每phase自然空闲60秒，全部8+52加cold61进程必须同批实际闭合。当前只是完整工程冻结准备，尚未任何全链终态资格；固定源/spec/review不更改，只观察此原session，不重复启动。旧所有失败profile/A与benchmark只读A不作为新fixture。原回归V4/UI V5/原19数据V1仍绑定失败V9，待新批实际complete后另建精确后继。

本轮收尾白名单同步实际benchmark通过原件及已审查候选来源/交接；正式恢复源未晋升，八章/美术UI/九玩法/性能/Android完整开发计划保持未完成，不合并main/不Steam发布。

## 2026-10-09：完整候选V12有界组件审计预算，等待限定准入

V11源/spec/proof原样保留、未Native。考虑V9在3600秒仅完成230/362行，按旧速度完整矩阵约5666秒；新CPU编码基准减少21.46%并不证明矩阵在原3600秒内足够快。V12只将组件审计deadline改6000秒，并更新schema/历史来源pins；world/capture1200、ABCD1800、整批21600、全部264/362/24原判据与Codec/Slot限制保持，不扩大任何游戏性能阈值、不宣称矩阵加速或通过。

V12 producer SHA 6309ed4976199a0afc058b0cf3a0bc78f0ba3dcc1bb01193958a19751eb3d7c5，SourceSpec逻辑SHA 867bd2d1b78339f357200e4dca344d14fb38a05c39f3e7906fe3f11507b60209/raw4bba2b87b74afe93be6e5bd52cc693debe1af505962eecb91709964d5534369e。durable_chain_executor_v12/三源及proof：116pins/29Python/importmissing=[]/26overlays，V11除source_spec/schema constructor/phase budget外全部ASTexact；R6/InputV7与实际benchmark原件相同。独立复审针对V12，未Native；准入后只开全新完整61批，自有原生串行/自然idle60，actual A从本批生成。

## 2026-10-09：R6实际等价基准通过，新完整候选V11独立复审

新隔离基准cccd1b29/session73354实际host终态0，complete/equivalence=true、lock_released=true；cold45580与bench13392实际exit0/errors0。219检查/31组完整旧新typed JSON/IEEE fingerprint全部相同，actual_passed_audit_benchmark_v4/保留5原始receipt/checkpoint/日志/report，ACTUAL_COMPONENT_AUDIT_BENCHMARK_PASS_V4.json逐SHA索引。31组本批汇总旧编码2629418us、R6cold2065047us（减少21.46%）、warm1889315us（减少28.15%）；pretty86572761bytes/compact21660974bytes（减少74.98%）。仅这一次实际CPU/序列化语料观察，未测物理写盘，不证明全矩阵加速或游戏FPS；full/SDK/whole全部false。V3仍是保留的实际失败，未转移资格；旧A只读数据不作未来全链fixture。

prepare_durable_campaign_full_inputs_v7.py 只将完整26overlay中的组件R5映射到R6，逐核本批实际原件/收据/准入；输入逻辑SHA 9ae0b50ccc99c261a3f9273ba2b18e7beda297d7a8457b05957c7134de41c987，所有原8+52合同保留。source-only V10遗漏metadata benchmark producer的间接UI helper，被完整import图检查拒绝、未Native，源/spec/失败proof在durable_chain_executor_v10/原样保留。

后继run_durable_campaign_chain_v11.py和SourceSpecV11逻辑SHA a19939818312caf8b50eb5f2752162b44210c375af8d9630993710bc1d74568f 完整113pins/28Python/importmissing=[]/26overlays。durable_chain_executor_v11/三源/proof显示V9全部函数AST除source_spec/constructor/integrity/main均exact，原矩阵/ABCD/61 distinct processes/timeouts3600及批21600/owned handle/unknown-child retention/idle60都保持；额外固定第一raw seal/review，全部terminal原log SHA复核。host原SHA漂移、malformed、优化Python拒绝均已检查；初次验证助手预期异常类写成AssertionError但真实require正确抛RuntimeError，仅修复临时验证catch，无候选/source seal变更。

当前独立复审中，尚未启动新完整批；若准入必须全新UUID/project/profile、双角色本批实际A，不复制任何失败V9或benchmark旧profile。原回归V4/UI V5/原19数据V1仍固定失败V9不能运行；待新全61实际闭合再准备新的精确后继绑定。正式恢复源尚未晋升，八章/美术/九玩法/性能/Android完整计划仍未完成，无main合并/Steam发布。

## 2026-10-09：V4限定准入与全新隔离批

COMPONENT_AUDIT_BENCHMARK_INDEPENDENT_REVIEW_V4.json SHA 526ca1f3c5890f19280dc838810fcf7a442e38d305a4c9217a8a38c7d6207a01 按实际字节回读；唯一批准read_only_component_audit_equivalence_and_cost_benchmark。原V3失败证据不转移资格。新批 D:/CodexTemp/lsh-component-audit-benchmark-20261009/audit_benchmark_cccd1b29 /session73354/ownPython32448已启动完整工程冻结准备。另一盲盒Godot曾出现，控制器仍要求自然空闲60秒再每阶段运行，不控制外部进程；当前尚无本批等价/成本终态报告。

所有R6数据字段/原指纹/边界/完整mandatory不变；仅审计表示比较测试修订。只观察此自有批，不重复启动，不修改封存源，日志与原始结果稍后另行保存/同步。正式源、完整61/原19/UI/SDK/八章/性能/真机资格未完成，未合并main或发布Steam。

## 2026-10-09：V3基准实际失败关闭，V4修订等价比较复审

唯一新批audit_benchmark_8279f4e8/session84569已exit1、锁释放；cold38336实际exit0，benchmark37704实际terminal/exit1。GD第41行直接比较完整嵌套审计Dictionary触发Godot native Max recursion reached，host按原Native error规则终止；无等价/成本/矩阵资格。actual_failed_audit_benchmark_v3/保存四原始receipt/checkpoint/两日志，ACTUAL_COMPONENT_AUDIT_BENCHMARK_FAILURE_V3.json索引；旧profile与整个工程原处保留，不重用、不删证据。

V4只将pretty/compact解析后的Dictionary递归==改为完整JSON.stringify canonical字节相等，且要求等于原完整full_audit；不删除字段或放宽typed/fingerprint/边界/全部mandatory。GD campaign_component_audit_benchmark_v3.gd，producer run_component_audit_benchmark_v4.py只更新probe/schema/历史来源pins。SourceSpec逻辑SHA be100fc167020c0ccc54db40e0f1ebc0d69811af46fe7fde4f8db08ba7918b56；68pins/26Python/importmissing[]/29overlays，快照/proof在component_audit_benchmark_executor_v4/。限定复审中，尚未新Native；后继若准入必须全新工程/profile与idle60两阶段。正式源/旧V9失败全61边界均不变。

## 2026-10-09：V3限定审查通过，隔离基准已启动

独立收据 COMPONENT_AUDIT_BENCHMARK_INDEPENDENT_REVIEW_V3.json SHA d4cfc5b3732e21a1f96cbd213df6f2554812db62696afb3a1cddf0fdf600336e 已按原字节回读；仅批准read_only_component_audit_equivalence_and_cost_benchmark。两项V2阻断闭合，源码准入不等于native通过。

已启动唯一新自有批 D:/CodexTemp/lsh-component-audit-benchmark-20261009/audit_benchmark_8279f4e8，session84569/ownPython23372，原producer/spec/review保持封存。控制器复制完整新工程并安装固定native依赖，每阶段自然空闲60秒。只观察这一批；未获得终态benchmark report、未确认等价/成本改善，不开其他Godot。旧V9全61仍失败，正式源未晋升；本轮Git仅同步候选来源、审查与明确边界，不Steam发布。

## 2026-10-09：R6审计等价基准V3，限定审查中

R6源码预备收据 COMPONENT_AUDIT_PRELIMINARY_REVIEW_R6.json 已完成静态/API闭合，approved_stages仍空。新增独立只读old/new基准：V1封存后发现工具import来源未闭合；V2补齐后独立审查仍拒绝cold缓存继承与边界/容量/共享别名缺测。旧producer/spec/拒绝收据保持原字节，不覆盖、不运行。

V3 producer run_component_audit_benchmark_v3.py 与GD campaign_component_audit_benchmark_v2.gd 每项先清空缓存，再测完整typed representation/原IEEE fingerprint；追加256/257字符、9000唯一整数饱和8192/未缓存miss、共享container实际变更。22个原packet完整section和54unit decode完整数据均保留；pretty/compact全字段解析相等并分别计时。SourceSpec逻辑SHA 6c0bf9f446bd916462b7a4cd57581c36991c11e59524fb737c1aac8c9b1d1c10；63pins/25Python/import missing=[]/29overlays，两个source快照及proof在component_audit_benchmark_executor_v3/。

仅CPU/序列化表示等价与成本观察；不测物理写盘耗时、不证明完整矩阵加速、不移交旧A或失败profile资格。若限定审查通过，执行全新UUID工程/profile的cold+benchmark两原生阶段，均先自然空闲60秒，只控制自有Popen；SDK禁用、CAMPAIGN_QA空、正常1.0/60Hz。当前未启动此新批，正式游戏源未晋升。完整61、原19与真实pending UI/SDK once、八章/美术/九玩法/性能/Android原计划保持未完成；固定失败V9的后继仍不得运行。

## 2026-10-09：V9实际组件3600秒超时关闭，完整原始审计保留与R6候选

V9 4eeadd45/session28289已host终态1，lock_released true，自有Python44560与component28096均退出。冷43800/A37128（303）/world37936（264行1540）原生及host通过；component28096达到既定3600秒、错误0、未终态report，后续live/B/C/D/shi未启动，全61失败。actual_timed_out_durable_chain_v9/保存16关键原始收据/日志/报告/受控槽及journal共29587808字节；ACTUAL_COMPONENT_EXECUTION_TIMEOUT_V9.json含全部461原组件审计文件逐SHA索引。约10059690114字节大型审计完整保留在精确原私有run，不是缓存、不删除、不Git上传；已完成230结果行全部passed但不能算完整362通过、不能复用旧A/profile给后续全链资格。没有裸CFG/cache/export复制。

full typed审计每文件最高86649894字节，计算/JSON重复扩张是新的具体成本线索，尚未基准证明性能因果。final_durable_component_audit_v1_r6/候选仅加exact typeof/IEEE64/exact text不可变scalar audit leaf缓存（不缓存container或validator、256字符/8192项有界）和去每份JSON pretty indent；原_typed完整body、_fingerprint/all fields/IEEE、181x2+8positive、原code/layer/NoNode/NoTick、生产Codec/Slot限制保留。仅source preliminary review中，未运行/采用；必须fresh隔离old/new审计representation和fingerprint一致及耗时基准后再考虑全链，不能以节省审计代替字段。

八原ID新四进程候选run_campaign_original19_data_cases_v1.py与campaign_original19_data_runtime_v1.py已完成source preflight，逻辑SHA d915b8d456d42e1f20cde7f3d6cabcfd3b526caf4252d7ad25d525d4fa18d853，111pin/32Python/95边与四源快照在 original19_data_executor_v1/。独立审查拒绝 ORIGINAL19_DATA_CASES_INDEPENDENT_REVIEW_V1.json SHA894ad4caf8bf60f1abc156dc9a9da81ded22d670f76c8992ff8fe9d2d73c462a，stages空：data/QA完整mandatory标签漏验、完整CFG/typed journal/实际request与原物理SHA未闭合。全部旧源/spec/拒绝保留，不运行；GD preliminary不是executor准入，剩余11原ID/UI/SDK与完整计划仍需完成。

当前无active Godot批。原回归V4/UI V5/八原机制V1均固定失败V9为前置，不能沿用或运行；后继需要新的审计基准/源码准入、全新实际全61闭合及精确新来源绑定。正式游戏源未晋升，不合并main/不Steam发布。
## 2026-10-09：原19八项源预备核验完成，尚无运行准入

六数据层V2独立预备收据 `original19_data_layers_candidate_v2/ORIGINAL19_DATA_LAYERS_PRELIMINARY_REVIEW_V2.json` SHA `197cbb4fc1847831d01cd393b882bf0873e7032015fe92c609d9869ffb3efc7d` 已回读：三项对点修复已核，5currentR12/131GD/2CoreContract和原Source回读无差异，stages仍空。与已预备核准的两QA源一致，只有源码静态/API闭合通过，没有执行器/原生/full19资格。下一步为这八项构建源封存、受控四进程cold+data+两独立QA profile执行器并另做精确独立审查；剩余11原ID与全部额外门禁仍必须实现/验证。唯一V9 native批保持同session28289，不同时打开任何Godot。
## 2026-10-09：原19六数据层与两QA兼容源码适配

原19全部ID与当前机制仍以 ORIGINAL19_R12_ADAPTATION_REQUIREMENTS_V1.json 为完整要求，未缩减为以下八项。新增 original19_data_layers_candidate_v1/ 六GD数据案例及来源，独立预备拒绝收据SHA `1e87b791832fd5a3cf22830ecb586162739f625d163a1a8eecc12192513ec2a1`：内置Projection被loader变量遮蔽；first missing和unknown-preservation只有prefs而非progress更新路径。旧V1全部保留，stages空、不运行。

后继 original19_data_layers_candidate_v2/ 源GD SHA `78b5496a2e1166902cc192ba85addcf2484529fefa2ed7172160a344c9568726`：改ProgressProjection变量保留内置Projection.IDENTITY；真正missing CFG先验证partial intent并通过当前progress projection/真实事务写入；14原unknown值先实际物理保存，再用另一个valid pure full intent的progress事务更新既有CFG并逐比unknown语义。四invalid请求精确CONTEXT/CONTEXT/OUTCOME_MISMATCH/IDS与实际before-after SHA已记录。best/tied/worse/noUnion、7原unsupported类别、root0/128允许/129拒绝及alias环保留。纯数据fixture不提供Battle/Mission/settlement能力，不发布Campaign memory。当前仅源码候选、独立预备复审，尚无producer/运行准入/Native结果。

original19_QA_compatibility_candidate_v1/ 两原QA ID GD SHA `3bab991f9347f2a5383f200be1a520c93440176ddb4555de58c6161b8de38ebe` 已预备源码核准，review SHA `b9f14c2d0f3b0431991a5b3379eb68751aaf5b6f4ee97c7f6c220712ef988014`、stages空。每case必须不同fresh QA1进程/profile、SDK disabled；实际Campaign/Cloud节点不替换，sentinel campaign.cfg原SHA/读回与dirty/pending/revision保持。现接口legacy_save bool与QA record/cloud memory replacement按实际R12字段验证，不伪造已移除receipt。Cloud自己的private settings/language apply可能写，明确不宣称全盘无写。尚无producer、不能跑Native，不能扩为normal/UI/SDK或全19。

其余11原ID（自然first/repeat、6真实文件故障、3真实回调/Cloud边界）仍需完整适配与原生运行；额外实际UI/同对象重试/source-account drift/exclusion/SDK once亦保持要求。全新V9 4eeadd45/session28289/Python44560/component28096仍同一live批，不另开Godot；尚未component或完整61终态，原回归V4与UI V5继续等待前置门禁。
## 2026-10-09：实际pending UI V5限定审查准入，等待同批V9全61闭合

V4唯一cold日志custody遗漏已保存在 `PENDING_TERMINAL_UI_INDEPENDENT_REVIEW_V4.json`（SHA `59d11a92ea60c0b259059038f9fb6fd17928fd4d987a412f3d6874fe45d4b130`，stages空），旧源/spec/快照保持不变。V5仅在已绑定batch.integrity中遍历所有已terminal且有log_sha256的步骤，以原step.log_sha256固定登记并末次复核，补齐cold/fresh/restart全部三阶段原日志。

新V5 SourceSpec逻辑SHA `714a2b8307f94e119562241ea5a94bc5a37c6a1417399c3e193682c883010156`，100pin/30Python/87边闭合。`pending_terminal_ui_executor_v5/`两源快照与单点差异proof已核；GD `59be03c34cc6154551786bb3670961d245465b54d9f059e5f21ae9048d60fa79`、105/20完整检查多重集与其余原值/完整CFG/intent/ACK/PNG/对象/所有权/优化/native安装判据都保持V4 exact。

独立限定收据 `PENDING_TERMINAL_UI_INDEPENDENT_REVIEW_V5.json` SHA `dac37f2450b2eb7343a1caf992adc7bd97b6ec18eff0dc90e543862e9f3f8eab` 已实际回读，只准 `actual_pending_terminal_UI_same_object_retry_and_restart`。尚未运行UI。执行必须固定freshV9 `4eeadd45` 实际全61complete、所有原日志/evidence/三代journal回读门禁通过，再使用新的UI run/profile；不能并发，不能继承旧fixture资格。下一步原回归V4六进程与UI V5依此串行运行。当前V9同session28289/Python44560/component28096仍live，已越过旧1200秒但未超过本批审查的3600上限；尚未该矩阵或全链终态，原19/SDK/完整计划未通过。
## 2026-10-09：UI V3原值custody拒绝，V4固定字节候选复审

V3独立拒绝 `PENDING_TERMINAL_UI_INDEPENDENT_REVIEW_V3.json` SHA `204109aa871bd43530ef9a022e829785ce36bd6d4fefba964f1f6321064bbe69` 已保存，stages空。唯一剩余PUI-CUSTODY-001：重新file_pin可能把验证中变化的文件当作新基准。此前其余修复、94pins/28Python/77边、105fresh/20restart原检查多重集及GD实际API均已核；V3不运行，旧源/spec/快照保留。

新 `run_campaign_pending_terminal_ui_v4.py` 只补原值固定：首次raw bytes解析report/handoff/seal/review，固定路径原pin不可替换；日志持续用step原log_sha256，PNG持续用native声明SHA且从同一BytesIO原字节实际解码；envelope原row立即固定，CFG绑定原ACK声明SHA；阶段前后及末次都复核原值。GD/原105/20/类型/完整scope/intent/ACK/Objects/native安装与优化保护不变。source-spec逻辑SHA `7a6fda19adc320e866e9d8bf83aeef28b43e70808ac1d84de5b66aad71f7cbef`，97pins/import图与双源字节快照在 `pending_terminal_ui_executor_v4/`。当前仅预检及独立复审，未UI原生运行、未获资格。

`PENDING_UI_FIXED_EVIDENCE_HOST_CHECKS_V4.json` 记录4项宿主验证：原文件及稳定重读、修改report不得重基准、原native声明SHA必须匹配、两次拒绝后原pin仍保留。仅自有临时JSON测试，无游戏profile写/无Godot；保留测试输入与原SHA，可复查，不转移native资格。

全新V9 `4eeadd45` 同session28289：冷43800/Lu A37128（303项）/world37936（264行1540项）均原生与host通过、exit0/error0。component28096已开始，尚未终态。继续同一自有批次；完整61/原回归六进程/UI/19/SDK/八章九玩法/导出/性能/真机及整个目标均未完成，不发布或晋升正式源。
## 2026-10-09：真实pending UI V2拒绝封存，V3五项修复候选复审

`PENDING_TERMINAL_UI_INDEPENDENT_REVIEW_V2.json` SHA `24845cf4e3a54cd220a0b868cd5e54689bb2a80f69ce66eedc388745d30880e4` 已独立拒绝（stages空），完整保留原V2源/spec/快照。五项为逐阶段与全部前置证据custody、Python优化关闭assert、实际native安装组合遗漏、完整宿主断言/PNG来源闭合，以及遗留admission范围字段。V2不运行。

新 `run_campaign_pending_terminal_ui_v3.py` / `pending_terminal_ui_candidate_v2/` 绑定原shared batch.integrity作每阶段source/spec/review/原61日志与evidence完整复核；安装actual native并重新封before/postcold全身份；显式拒绝-O；清理当前admission count/QA字段。原fresh72项多重集（含普通移动重复标签）及restart20项保持，新增33项UI/冻结语义检查，因此预期105/20。host核十字段journal/typed scope/gen1→2→3/同完整四目标intent/CFG-bound五字段ACK/两份完整handoff与所有原SHA；GD记录2轮同对象ID与完整ConfigFile语义/文本不变；原生截图SHA/尺寸由host实际PNG解码及hash复核。来源spec逻辑SHA `e7e0751063795a72eb7856121f1c0436de31b4412d07123e85529eaf34cf5b35`，94pin与依赖图/双源字节快照在 `pending_terminal_ui_executor_v3/`。正在独立复审，未准入、未运行，不授予UI/19/SDK/整体资格。

`PENDING_UI_TYPED_INTENT_HOST_CHECKS_V3.json` 记录13项只读宿主验证：历史实际自然intent一个正例，仅测试类型校验；12项布尔/浮点/字符串计数、重复/缺目标、整数胜利、token/profile/source变化均拒绝，原始输入SHA不变、无profile写、无Godot。实际python -B -O V3在main明确拒绝，未启动native。历史72/20与该正例只作为原标签/数据约束，不转移旧native资格。

当前唯一native仍V9 `4eeadd45` / session28289 / Python44560。冷43800与Lu A37128已退出0/error0且host通过；本批A原报告303checks全部passed。world37936仍执行，完整61未通过；按同一句柄串行观察，后续原JSON/Owned/半程及UI需固定实际V9完整门禁先通过。
## 2026-10-09：原回归V4限定审查通过，真实pending UI候选准备

原回归后继 `run_campaign_admission_regressions_v4.py` / `ADMISSION_REGRESSION_SOURCE_SPEC_V4.json` 只将前置失败V8改为全新V9 `4eeadd45`。仅source_spec与verify_closed_prior两函数改变；共享runtime、三原validator body及execute/CFG等不变。80pins/25Python/64依赖边闭合，30覆盖/11原fixture及三工具快照回读一致。独立收据 `ADMISSION_REGRESSION_INDEPENDENT_REVIEW_V4.json` SHA `bf4959221d411c31f0a92ee6f2428697e8db42ff7dee869b99277c2532de5c2a` 仅准原JSON533/OwnedSlot76/半程ABC六进程。当前未运行，须固定V9实际完整61退出0/全部日志证据与三代journal门禁先通过；旧V3不可沿用。

新的 `pending_terminal_ui_candidate_v1/` 保留原正常黄泥冈完整玩家路线与重启判据，只在自有userdata制造nonce绑定stage-parent文件故障，检查真实CFG_STAGE_PARENT、实际可见RetryTerminal按钮及原pressed连接。故障未清时重试需保持同coordinator/writer/frozenCFG/intent/lifecycle对象、旧进度、CFG与gen2；仅清自己原SHA文件后再按按钮，确认原gen1/gen2不改而附gen3，并正常重启。`run_campaign_pending_terminal_ui_v2.py` 与 `PENDING_TERMINAL_UI_SOURCE_SPEC_V2.json` 预检逻辑SHA `d32c0d51c0b3a7fae0e87b02b6c0af5afc5d40324b19a86bf35697bf3207c9a6`；87来源pin、完整Python import闭合与两源字节快照在 `pending_terminal_ui_executor_v2/`。V1仅初准备、V2增加原生PNG来源回读；旧V1源/spec保留。尚未独立准入或运行，不给UI、19、SDK或整体通过资格；无改正式游戏源。

唯一原生批仍V9/session28289，冷导入已完成，Lu A正在执行；保持同一句柄串行等待。
## 2026-10-09：V8组件执行超时已关闭，V9审查通过并启动新批

V8 `durable_chain_9a2419c2` / session53244 已终态退出1、锁释放。冷导入、Lu A（311项）与world（264行/1540项）原生及主机通过；component在1200秒执行上限停止、引擎错误0、未写终态报告，不能认定组件或整批通过。17份原始受控记录共30089560字节保存在 `actual_timed_out_durable_chain_v8/`，边界见 `ACTUAL_COMPONENT_EXECUTION_TIMEOUT_V8.json`；旧档保留且不复用。

V9只将component单阶段上限改为3600秒，world/live仍1200、ABCD1800、全批21600。原Codec、全部输入/检查/矩阵数量、源码封存和进程所有权规则不变。43个来源pin及18个Python/31条依赖边独立审查闭合；收据 `DURABLE_CHAIN_INDEPENDENT_REVIEW_V9.json` SHA `a87a9d61600b260ca74bc4fe684d595c0fd79753311d399174491f083a63535d` 只准 `durable_chain_and_matrices`。spec逻辑SHA `edcb416a41c25b658e13b23eaa99c1cb4eb4dda9fa29947b386114456b9bc278`，源码字节快照与差异在 `durable_chain_executor_v9/`。

全新 `durable_chain_4eeadd45` / session28289 / 自有Python44560已启动，准确绑定在 `ACTUAL_DURABLE_CHAIN_LAUNCH_V9.json`。每阶段自然空闲60秒串行，继续观察同一句柄；尚未整批终态。admission V3固定失败V8，不可运行；后继必须另封来源、审查，并等V9实际61阶段全部通过后再运行。原19场景、错误UI/同对象重试/SDK一次奖励、八章九玩法、导出、性能与Android真机仍未完成。正式游戏源码未晋升；仅同步既定stable分支，无main合并或Steam发布。
## 2026-10-09：原回归V3源码准入完成，等待V8实际61终态

`ADMISSION_REGRESSION_INDEPENDENT_REVIEW_V3.json`SHA`67339b16f0c5ecf689f806cf6326c561aff62b0f2191362bccc82e20ed569a37`已回读，仅准原JSON533/OwnedSlot76与半程ABC六进程。73pin/30overlay/11fixture/三工具快照与三原validator body exact；旧V1/V2拒绝保留。当前不能运行：固定V8新批9a2419c2尚未完成，必须先通过真实61关闭/全部原日志与证据回读门禁。

V8同一session53244冷导入10696已经退出0/无引擎错误，Lu A已按自然idle60开始；继续观察同一句柄，不重开。新批尚未A/整批终态，原19/UI/SDK/设备性能/完整目标不因源码准入升级。正式游戏源码不晋升。

## 2026-10-09：V8限定准入与全新批实际启动

V8独立收据SHA`fb2e4859d62797b5ae8b0731e181d1dcc5d91f879559f66ff81f90e2c6e0ef2f`已回读，39pins/27metadata/26overlays/5132 base原路径验证、两处producer AST差异和唯一R5 component映射均闭合。只准`durable_chain_and_matrices`，8+52+cold=61仍不减。

全新`durable_chain_9a2419c2`/session53244/自有Python27780实际启动，绑定见`ACTUAL_DURABLE_CHAIN_LAUNCH_V8.json`。每阶段自然idle60串行运行；旧V7失败profile/frozenA均未复用，尚未新整批终态，不重复启动或转移资格。

原回归6进程后继V3已封来源预检，`ADMISSION_REGRESSION_SOURCE_SPEC_V3.json`逻辑SHA`47476a711fae22e40527a98a2c8756afbc1921a19aa2a4b6048b7fb35df08d7e`；当前仅复审、未运行。V1/V2空stage拒绝与旧源保留。V3修实际六个角色键/两组三代journal回读和原fixture manifest/frozen路径分离，保留三原validator函数body与共享runtime；完整静态import无漏pin。运行门槛精确绑定V8必须先真实完整61关闭/qualified、全部原证据/日志再次回读，当前不满足。源码/三工具快照与图见`admission_regression_executor_v3/`。19/UI/SDK/八章九玩法/导出/性能/真机及整个目标保持未完成；正式源码未晋升，仅同步stable。

## 2026-10-09：V7已终态失败，R5逐记录测试传输及V8来源封存

`durable_chain_3cbf11be`/session14402已主机终态1、锁释放，自有Python23092/全部Godot已退出。冷15256、Lu A45604/313、world20888/264rows/1540checks都原生及主机通过；component23700退出1/引擎错误0、5563checks唯一失败membership full installed wire JSON route：BYTE_LIMIT，73行已执行。后续live24/B/C/D/shi未启动，不能称8+52/整批/整体通过。18份原始收据/日志/报告/受控槽和active journal共31022127字节在`actual_failed_durable_chain_v7/`，边界见`ACTUAL_COMPONENT_MEMBERSHIP_CODEC_FAILURE_V7.json`，未复制裸CFG/缓存，旧档保留不复用。

原component测试把完整所有Unit states聚合交给单值Codec 1MiB限制；生产Unit payload逐记录编码、Slot整体64MiB。新`final_durable_component_transport_v1_r5/`只修membership JSON测试wire：每个完整state/id/outer key与值按原Codec编码/解码，所有字段/类型保留，整体两侧使用实际Slot64MiB。生产Codec/每条1MiB/depth32/nodes32768、全部181×2/8positive/54labels/原code和layer/type/IEEE/noNodes/noTick断言不改。R5独立静态收据SHA`2d4e8e346d2857addbbe50425a5dd3004544b220fe6228324692bfd3f0bb3daf`通过、stages空，无新native资格。

InputsV6预检逻辑SHA`7de143442eac3cce6154d4d5d730b7d1587a54582d50a54dec6fed7bd0c4d108`；SourceSpecV8逻辑SHA`6d4fb8ab8eb3bd1ea36f47a59da6be17082be436ce47eb0aab165d287339c10b`，只换26中一个componentGD map。V8 producer只改来源及schema，全部运行/validator/CFG/fixture/lease函数保持V7 exact；十二工具字节快照与diff/import图在`durable_chain_executor_v8/`。当前限定源码复审收尾，尚未启动新批；须fresh全新profile和完整61终态，不转移旧V7失败或fixture资格。

新6进程JSON533/Owned76/半程ABC入口V1五项及V2两项独立拒绝均保留，源码/spec/快照不可变。后继V3只准备源（尚未封/准入/运行），改正实际V7/V8六个role keys与两组三代journal、原fixture manifest/frozen路径分离，并将prior精确绑定将来的V8整批闭合结果。`ORIGINAL19_R12_ADAPTATION_REQUIREMENTS_V1.json`保留全部19原ID/历史期待并逐项指定当前事务机制，尚无新19执行器或运行；尤其旧cloud预写内存bug期待明确改为R12失败保留旧内存。错误UI/同对象重试/SDK/八章九玩法/导出/性能/Android完整目标仍未完成，正式源码未晋升。

## 2026-10-08：V7实际A与world阶段通过，后继回归入口准备

同一批`durable_chain_3cbf11be`/session14402仍在执行：冷导入15256终态0；Lu A45604终态0、313全过，主机证据校验与gen1槽/active日志/实际handoff封存通过；Lu world20888终态0、264行与1540检查全过，主机来源/谓词回读通过。仍需component362、live24、B/C/D以及史进整组；不能记整批或整体资格。

半程consumer后继R3只准备固定两handoff父目录，82原标签保留+4，当前R12/API兼容独立静态收据SHA`0b5ce15c7a8a3e172bad1e212ac42ca034723fbc258dc156d231634a10df0cc3`，approved_stages空。`final_executor_candidate_v1_r3/`及新`ADMISSION_REGRESSION_SOURCE_SPEC_V1.json`、`admission_regression_executor_v1/`三工具快照/原谓词AST证明均仅准备。

新6进程回归入口保留JSON533、原OwnedSlot76、半程ABC最低39/351/342与完整mandatory/hold谓词，明确两pure测试使用QA1，正常ABC为空；仅换半程R3映射，保留全部当前运行来源与11原fixture SHA。运行必须先有V7实际61进程整批关闭/合格收据和新独立准入。V1正在集中独立审查，已发现host envelope返回形状、阶段小写label和Windows profile规范化接入错误；源码/spec/快照保留、未启动该批，修正后另建后继。原19故障、错误UI/同对象重试、SDK/性能/真机等仍未通过；正式源码不晋升。

## 2026-10-08：URI后继V7独立准入，新批实际启动

V5拒绝DUR-CHAIN-LEGACY-PIN-001（旧evidence host/preparation叶子未pin），V6拒绝DUR-CHAIN-LEGACY-CFG-PIN-002（旧v2 producer仅供CFG host API测试的叶子未pin）。两版源/spec/快照及拒绝原样保留。V7集中补齐后独立审查通过：5132基础/26覆盖/36pins全部回读，14活跃local modules及24 import边闭合，身份当前调用链无动态import；URI/CFG/原生与所有矩阵谓词保持，AST仅source_spec/__init__来源与schema变化。

`DURABLE_CHAIN_SOURCE_SPEC_V7.json`逻辑SHA`96eaca0f946601e66aa44d171b627b6a9f3355e40c7d4ccba41c7402085e65cc`，限定审查收据SHA`7814aca21ccfdf1463973ce952b87ba8dc701cb5504ce138ab5ca067ed223f6a`，只准`durable_chain_and_matrices`。`durable_chain_executor_v7/`保存十一工具快照、静态import图及旧/当前CFG host API AST相等证明，21 URI host测试原日志见V5快照。

全新`durable_chain_3cbf11be`/exec session14402/自有Python23092已实际启动，启动绑定见`ACTUAL_DURABLE_CHAIN_LAUNCH_V7.json`；每阶段连续自然idle60、61原生进程串行，继续观察同一exec句柄。旧失败profile与offline A manifest不复用，旧收据不补complete；新批未取得整批终态，ABCD/52/19/JSON/Owned/半程/UI/SDK/性能/设备及整体目标未通过。正式源码未晋升，只白名单同步stable，不合并main或Steam发布。

## 2026-10-08：V5来源叶子拒绝保留，V6补齐直接绑定

独立V5收据`DURABLE_CHAIN_INDEPENDENT_REVIEW_V5.json`拒绝执行（stages空），唯一阻断DUR-CHAIN-LEGACY-PIN-001：准备工具和host测试仍导入旧`durable_campaign_full_evidence.py`，V5没有直接pin该叶子。URI API兼容审查通过，313原生A通过与旧整批主机失败保持区分；offline freeze证明仅host验证，不能供后续native复用。

后继`run_durable_campaign_chain_v6.py`只追加该legacy host/preparation叶子的直接pin和spec/batch版本6，原生/矩阵/CFG执行不变；AST差异仅source_spec与__init__。新`DURABLE_CHAIN_SOURCE_SPEC_V6.json`逻辑SHA`ee6c153d173e0419056634cf105ce908268e40e71617a90b6015efa150ef31dc`已通过来源预检，十源快照与差异证明在`durable_chain_executor_v6/`。当前复审中、尚未启动新批。V5原源/spec/快照与拒绝收据均保留，旧profile/failed receipt不改、不复用；8+52及整体资格尚未成立。

## 2026-10-08：原生A313实际全过，主机证据URI校验停止

V4批`durable_chain_8eeef1ab`/session2330主机终态1/锁释放；Lu A PID43840原生退出0、错误0、313检查全过、handoff已写，完整A的原生证据成立。主机把user:// URI当Windows Path，is_file失败被合并断言误报Duplicate evidence；后续矩阵未启动，不记整批或整体绿。12原始记录在`actual_host_failed_durable_chain_v4/`，仅对应本批scope，边界见`ACTUAL_NATIVE_A_HOST_URI_FAILURE_V4.json`。

新EvidenceV2只解析三个固定handoff user URI并仍验证当前userdata/noLinks/containment/SHA/重复，producerV5登记实际路径，其余验证/执行不变。21host方法与实际报告offline校验通过（不启动Godot、不称原19），九源/原日志在`durable_chain_executor_v5/`。SourceSpecV5已封等待新独立准入，新批未启动；旧profile不复用、旧收据不补complete，原ABCD/52/19/UI/SDK/性能/设备等仍未通过。

## 2026-10-08：V3营救/第一人撤离及实际保存通过，A因handoff目录失败

`durable_chain_38024dd3`/session96977已终态1/锁释放。冷导入PID23640通过/错误0；Lu A PID43076的302检查仅`evidence writable handoff_A.json`失败/错误0。真实普通地面行军、营救、第一人安全撤离、完整Session保存/实际槽gen1＋active journal gen1读回均观察到。默认continue根不创建旧handoff父目录，未显式mkdir导致最后证据写入失败。11份原日志/报告/收据/受控partial槽/日志在`actual_failed_durable_chain_v3/`，边界见`ACTUAL_SINGLE_SAFE_SAVE_CHECKPOINT_V3.json`，不复制裸CFG/缓存、不补为成功A或供负例fixture。

consumer R3只补固定private handoff目录：精确userdata sibling、祖先link检查与只建目录，105标签和不可变证据写入/完整保存安装/终局gen3/CFG保持。新InputsV5/SourceSpecV4与ProducerV4来源预检、目录/继承及整体限定独立审查均通过，原共享validator不动。新八源快照在durable_chain_executor_v4/，独立收据与ACTUAL_DURABLE_CHAIN_LAUNCH_V4.json绑定全新8eeef1ab/session2330/自有Python26396实际启动。原profile保留不复用；新批未整批终态，ABCD/52/19/UI/SDK/整体验收仍未通过。

## 2026-10-08：V2终态失败，未取得A来源资格

实际批`durable_chain_65cae0c9`/session93131已退出1/锁释放。冷导入PID43800通过且引擎错误0；Lu A PID27632的133检查只有牢前清敌期限失败，引擎错误0。五原始记录在`actual_failed_durable_chain_v2/`；旧档不改、不复用、不给任何后续矩阵作成功A。v33观察显示牢前A点击被实际enemy91命中转为explicit attack，20单位旧amove目标保留、随后链结束并退营；`PRISON_FOCUS_ROUTE_DIAGNOSIS_V1.json`绑定原报告/日志和精确采样。

`qa/office_campaign_route_20261008/v34/`只改该牢前普通指令：原点附近开放/无实际点击敌人的地面，保留同一minimap_order及全部成本/敌军/期限/27标签，另核完整selection和formation目标/ST_AMOVE。v34静态审查/InputsV4/ProducerV3预检及新限定源码准入均通过，实际全新批`durable_chain_38024dd3`/session96977/自有Python45548已启动；新来源与启动绑定在同目录V4/V3 spec/review/launch，八源快照在`durable_chain_executor_v3/`。效果未取得完整实测结果，不复用旧失败profile，不重复启动。后续ABCD/52、原19/UI、SDK、八章/九玩法/导出、性能/设备目标全部保持未完成。

## 2026-10-08：durable链执行器候选与20项host测试

V1 seal/六源快照/20项host日志及独立拒绝原样保留：DUR-CHAIN-CFG-001/ACK-002拒绝非固定CFG路径与整数布尔别名。不可变后继`DURABLE_CHAIN_SOURCE_SPEC_V2.json`逻辑SHA`653ebc6f7661574c28362edc1f6cdf99debcb6f271d47550fa2a86bec13fa965`，只修`campaign.cfg`三字段和ACK五字段严格类型。`durable_chain_executor_v2/`保存七工具快照及20＋3项host原日志/收据。V2源码预检和独立复核通过，仅准入8+52与cold import；实际批`durable_chain_65cae0c9`/session93131/自有Python10628已启动，启动绑定见`ACTUAL_DURABLE_CHAIN_LAUNCH_V2.json`。未取得整批终态或实际A资格，不重复启动。

校验器由固定旧r2b2/parent源码AST保留world264/component362/live24、nullable/type/原code/layer、完整install/自然终局mandatory与hold清理谓词，单独新schema接gen3/真实CFG。来源、每阶段实际PID/nonce/日志与封存A归属均要求完整终态。实际19持久故障、JSON/OwnedSlot/半程、SDK/公开入口、导出/性能/Android保持未完成，不因20项host测试或8+52范围而缩小原目标。审查期间没有原生运行。

## 2026-10-08：264/362/24持久化矩阵后继R4静态闭合，完整输入26覆盖封存

`final_durable_negative_adapters_v1/` 独立拒绝NEG-ADAPT-001/002：capture自己override守卫仍要求QA1，且override loader未初始化继承安装校验所用Lifecycle。R2修守卫并加入world264，但loader缺口保留，准确拒绝。不可变R3修两处，后继R4 `final_durable_negative_adapters_v1_r4/` 保留修复并显式固定load campaign-v2 Lifecycle/Intent；不加载或调用父natural route/drivers。

R4保留world33原unique labels、component52、capture50，world132×source/json=264和component181×source/json=362每角色合同、24live字典与5caster、全部mutation/IEEE/HELD/noTick/noNode/实际Core及原层/code/类型不变，只接正常startup/default root/v2五参数与完整scope、实际新A schema及32源pins。独立V4已核135 literal图、R12Bai110组合与两CoreContract/继承durable R2 exact，仅静态兼容，approved_stages=[]；尚无新实际A冻结或full producer，不能称矩阵运行通过。

`tools/prepare_durable_campaign_full_inputs_v3.py` 实际无native预检成功，封存 `DURABLE_FULL_SOURCE_INPUTS_V3.json`：完整base5132逐文件与两CoreContract、15运行源+11测试gd/scene/route共26唯一runtime覆盖，逻辑SHA `c00aafd462a4c6a2a96f88a085c6297e4e3a6bb6fc67b75b4e571bb4e9cab869`。V1独立拒绝PREP-LINK-001：pin先resolve再查链接，且base子文件没有逐个检查原路径；保留原V1/spec/快照。V2在resolve前、每次read/sha前和110/base5132每项stat/hash前检查原路径及所有父链。输入映射复核追加NEG-ADAPT-003：R3 capture report读取旧absent基类SHA；保留V3初审与明确覆盖它的资源addendum、V1/V2 inputs拒绝。R4只把该证据读取改成实际继承的durable基类，矩阵正文不变；Inputs V3选用R4并保留V2逐原路径检查。来源准备工具无--run，仅不可变JSON输入封存；独立prepare-only复核不授Native/full，R4审查仍须绑定至最终执行器的新seal。八ABCD进程/264/362/24/52负例阶段/19故障/默认continue根与三代生命期合同全部列明。

普通黄泥冈三组actual complete的旧绿保留其scope：不扩展角色、19/52、真实故障UI/同对象重试、Steam奖励、导出/性能/真机。下一步实现最终producer的严格durable consumer/来源冻结/完整矩阵聚合及新19/UI cases，再做独立完整准入；大名府牢前推进尚待v33实际诊断。正式游戏源码未晋升，原完整目标不缩小，本轮只白名单同步stable。

## 2026-10-08：R12＋白胜候选普通终局与三组恢复实际通过，完整双角色后继继续

实际批 `natural_terminal_645e69a6` / session85300已完整终态退出0、锁释放。七个独立PID：import43784退出0；normal_fresh32384退出0/72checks、normal_restart43736退出0/20checks；gen2_fresh36640在真实第二代已落盘/CFG未写的源码断点被只终止自有进程，gen2_restart23320退出0/20checks；cfg_ack_fresh27544在真实CFG已确认/ACK前断点被只终止自有进程，cfg_ack_restart8056退出0/20checks。两次预期终止退出1不是失败重开；所有过程引擎错误0，三个唯一token、两个中断前后原gen1/gen2字节与同意图保留。三组均恢复第三代applied，CFG确认后的重启SHA不变，启动不重放Battle/Mission/展示/结算。完整36份原收据/identity/log/handshake/journal证据在 `actual_scoped_recovery_r12_bai_v1/`，正常fresh9份独立阶段checkpoint在 `actual_normal_fresh_r12_bai_v1/`，不复制裸CFG或私有profile。

白胜南侧普通排队行走、八人自然撤离、真实CFG fresh-load、gen3确认与重复完成拒绝已在当前110来源组合下实测通过。此资格仅普通黄泥冈三组，不能替代双角色ABCD、原19故障、52负例、故障UI/同对象重试、实际Steam奖励、导出/性能/Android真机；正式源码仍未晋升。

`qa/office_campaign_route_20261008/v33/` 只增加牢前部队path/target/state/manual/serial/queue/root/stun/stuck及guard/segment只读观测，原命令、成本、期限、27route标签和runner/scene均不变，独立route审查仅静态，空approved_stages；旧V12牢前失败原因仍未定位，不新开旧QA1全量来冒充R12。

完整ABCD consumer后继 `final_durable_retreat_consumer_v1/` 保留旧100唯一标签中96项，4个旧QA抑制写盘标签明确替换为更严格的真实持久化断言，使用新schema，旧validator不改不绕过。R1独立拒绝DUR-CONS-001：安装校验仍inline v1 Script/两参数；不可变R2 `final_durable_retreat_consumer_v1_r2/` 修成固定v2/five args、原token/script/directory断言及完整matches_scope。R2新增startup/default root/真实barrier归属、三代journal/CFG-ACK SHA、一次completion能力和data-only D读回；独立源码复核通过，但新full producer、半程、362component/24live适配及最终矩阵仍未整合，不授Native/full资格。R1拒绝和源原样保留。

下一步继续最终执行器完整来源组合与矩阵接入、双角色自然路线和错误重试，原八章、九玩法/EXE、性能内存、Android真机目标保持。本轮白名单同步stable，不合并main或发布。

## 2026-10-08：R12＋白胜南侧路线候选实际启动

新独立收据SHA `705bfca072700a5b141e03ed912fedb2cb31942b6531ff84f8e8e69d8bd0f758` 已回读、110来源一致。全新 `natural_terminal_645e69a6` / session85300已串行启动并进入实际导入，旧V5失败档不复用；实际argv及spec见 `ACTUAL_LAUNCH_R12_BAI_V1.json`。本批检验原自然终局/真CFG/gen3和三组重启窗口，尚未终态，不能声明路线修复或恢复通过。继续完整开发目标。

## 2026-10-08：白胜实际身体阻挡定位，R12组合南侧普通路线候选

旧V5实际批 `natural_terminal_1577d6e0` / session42979已终态失败并释放锁：import PID25388退出0/错误0；normal_fresh PID7880退出1/错误0，22检查唯一失败仍为原60秒自动卸酒。实际白胜位置911.29565,741.92834停滞，hp70/root0/stun0/manualfalse/auto/serial1均正常；next60Hz步map_open=true、body_open=false，两轴body也false。原军汉entity20位于891.7191,752，下一步与其距离20.9854，小于身体允许22。结合真实Unit._follow_path和static-only watchdog，此次停滞已定位到押队身体阻挡；不把诊断当终局、CFG或修复通过。五份原receipt/identity/log/report封存 `actual_failed_natural_terminal_v5/`，原失败档保留不复用，诊断来源及实际数值在 `BAI_BODY_STALL_DIAGNOSIS_V1.json`。

父关卡候选 `huangnigang_bai_arrival_candidate_v1/` 只将白胜自动初始命令改为普通队列经过南侧(40,30)/(23,30)，再到原WINE_UNLOAD。没有修改身体碰撞、坐标/生命/敌军/时钟，玩家接管、同演员、serial门禁及1.5秒正常idle卸酒保持。两次queued=true不会改变替代命令serial，内部执行队列也不增加serial。

新 `tools/run_campaign_natural_terminal_r12_bai_candidate.py` 明确绑定14份R12恢复源、该父关卡、原两份Core/Contract候选及110来源/81引用；runtime安装路径固定。原完整冷导入/identity、共享idle60、owned-process串行、正常无QA环境、实际自然终局/真CFG/gen3和三组重启/真实中断窗口全部保留。spec逻辑SHA `017d01e338cece864018c9e57e7002347089864393f9c3815e90f1a5e8c38b86`，独立准入见 `NATURAL_TERMINAL_INDEPENDENT_REVIEW_R12_BAI_V1.json`，仅natural_terminal_scoped。候选实际启动/结果以当轮独立收据为准，当前不宣称修复或完整恢复通过。

双角色ABCD/19故障/52负例/实际失败UI重试/Steam奖励一次性仍待最终执行器；大名府牢前推进也仍待定位。八章、九玩法/导出、性能内存、Android真机原目标保持。正式游戏源码未晋升；本轮只同步stable，不发布。

## 2026-10-08：白胜身体判定V5已启动，终态待回读

独立V5 scoped收据SHA `7ed18ebc8a24c17d3d27e2b4337ea6e8b724b28bbac6cb076eb7d6c934bc0c8e` 已回读，107来源一致。随后串行启动全新 `natural_terminal_1577d6e0`，观察session42979；实际argv/spec在 `qa/campaign_progress_recovery_20261008/ACTUAL_DIAGNOSTIC_LAUNCH_V5.json`。只验证R9原组合下的白胜实际阻挡读数与原自然终局条件，当前无通过结果，不替代R12/full验收。

## 2026-10-08：真实启动屏障上下文及空屏障防线修正，R12静态候选

最终恢复的办理半程后继 `final_executor_candidate_v1_r2/` 保留原79项标签，新增正常startup门禁、真实Battle屏障归属与完整五参数v2生命周期检查。独立审查初步拒绝 FINAL-ADM-001：R9实际新游戏入口用缺省classic上下文创建保存屏障，原测试额外configure掩盖该问题。没有删除断言或恢复测试注入。

R10将Battle屏障创建/configure/add移到实际SteamRunPolicy.classify之后，显式传入本次实际上下文，prepared restore分支不变。独立复核确认上下文问题已解决，同时拒绝FINAL-ADM-002：失败启动可能没有屏障，而ContinueFlow保存入口直接调用空对象。R11在request_save_exit设置source前、confirm的_begin_save修改UI/连接信号前和_disconnect_capture读取屏障后检查实际有效性，返回既有RUN_BARRIER_UNAVAILABLE或安全结束disconnect。相对R9仅Battle/ContinueFlow变化，另12源字节不变。R11的第二层guard进入_fail后仍会空对象访问，因此独立拒绝；R12继续保护_fail、retry_release、has_capture_request与cancel-for-terminal路径，保留原错误及确认前pause意图，不伪装已解除持有。十四候选/80固定引用/13正式来源及新快照封存在 `SOURCE_AUDIT_V14.json`、`integrated_source_snapshot_v14/`；正式源码零修改。独立复核见 `INTEGRATION_SOURCE_REVIEW_V5_R12.json`，仅静态源/API范围，未授予任何native/full阶段。R10/R11及其拒绝收据原样保留。

旧完整续玩 `office_full_3eb4617b` / session27770已实际终态退出1，Lu A PID45692、131项检查唯一失败“prison approach clear natural deadline”。真实受验、内应、举火、开南门事件已发生，部队仍有存活，但失败报告不足以定位移动/攻击原因；43份原始记录85,208,161字节在 `qa/office_campaign_full_20261008/actual_failed_v12/`，原档不改不复用。普通终局V4_R2诊断 `natural_terminal_e75e0f96` / session9861也已终态失败、锁释放：normal_fresh PID42496、22checks唯一白胜60秒内自动卸酒失败；五份原记录在 `actual_failed_natural_terminal_v4_r2/`。从tick2697至5397白胜位置911.29565,741.92834完全不变，ST_MOVE/path仍指向752,784，静态segment畅通，hp70、无手动接管、serial1/auto保留。只能确认正常自动走路停滞，不能仅凭静态路线穿过押队站位认定动态身体阻挡。V5仅补充实际128范围敌对移动body半径/距离及下一60Hz步/轴步的map与can_unit_step结果，所有命令/60秒边界/断言不变；107来源封存spec及快照、独立静态scoped准入收据同目录，未转移R12全链资格。最终R12完整producer及双角色/19故障/52负例/真实CFG重启/错误UI/奖励一次性继续待实现和验收。八章、九玩法/导出、性能内存和Android真机仍在计划内。

本轮仅同步候选、独立审查和交接到既定stable；不晋升正式源码，不合并main或发布。

## 2026-10-08：普通终局V3实际白胜失败；V4_R2只读诊断准入

`natural_terminal_a30fe00d`已终态失败、锁释放，session2937退出1：导入26860退出0/零错误；normal_fresh13248退出1/引擎错误0，22项检查唯一失败为白胜在原60秒内自动卸酒。真实菜单、六项完整identity、普通时钟、押队到场与一次玩家刘唐应答均通过；没有进入自然终局或写CFG确认，白胜精确状态未采集，不能认定具体路径/控制原因。五份原收据/identity/日志/report在`actual_failed_natural_terminal_v3/`，原profile不改不复用。

V4_R2只添加每15秒白胜原对象的hp/位置/state/path/queue/serial/manual/unload/near/segment只读观测及失败详情，PackedVector2Array使用for遍历；原玩家命令、60秒/正常tick/墙钟上限、终局/CFG/gen3和所有重启/debugger断言不变。只读preflight成功，spec SHA`8fcdcc13c90610aeee88867683dd0c6360f9e6896bf18297f03997c31fbbf85f`；独立收据`NATURAL_TERMINAL_INDEPENDENT_REVIEW_V4_R2.json` SHA`86b438174e8ae5507a98688cd7512a44d245dee70f506684a286b36ff9b6687f`已回读，107固定来源一致，仅scoped静态准入、尚未native，失败资格不转移为绿色。

当前唯一新自有原生批是已准入v32旧完整续玩`office_full_3eb4617b`，session27770，单独全新profile；实际导入已退出0，前置JSON/store/半程ABC及双角色流程继续，不能按日志滚动认定whole通过。等它实际终态后才能串行执行V4_R2诊断。不缩短或改自然条件，不用玩家接管代替自动卸酒检查。

最终R9双角色/19故障/52负例/真实CFG重启/错误UI/奖励一次性仍未完成；八章、九玩法/导出、性能内存和Android真机目标继续。正式源码未晋升，Git只同步stable，不合并main或发布。

以下此前“V3运行中”等段落保留历史，以本段和实际终态为准。

## 2026-10-08：v32旧full静态准入与普通终局V3实际导入

v32独立V12收据`qa/office_campaign_route_20261008/OFFICE_FULL_INDEPENDENT_REVIEW_V12.json` SHA`032312d7f03b80760194a607923ddd3227379eb57dc28369b3b6a5343d0db5f0`已回读：原旧full范围静态准入，native_started=false；仅调整admission/扩军时序并补诊断，原Core/Contract候选与全部原矩阵不变。该批准不覆盖R9完整恢复consumer，旧V11实际失败不能升级，v32尚未启动。待普通终局批实际终态后再串行安排。

普通终局新批`natural_terminal_a30fe00d`导入PID26860已真实退出0、零引擎错误；session2937仍运行，后续normal fresh/restart与两个中断窗口待实际结果。无自然终局或重启通过可宣称。

## 2026-10-08：普通终局scoped V3独立准入，新档实际运行

V3独立审查收据`qa/campaign_progress_recovery_20261008/NATURAL_TERMINAL_INDEPENDENT_REVIEW_V3.json` SHA`392f11d5e8c317b2383aa0b3fd94bfb2729e364a9340995288d0927b42957160`已实际回读，spec3e3a3d…、producer不变、probe固定autoload后load、十四R9/80引用/两项CoreContract组合一致；仅natural_terminal_scoped准入。V2真实导入22748/启动43612的成功/编译失败和保留原档均纳入审查，不转移原生资格。

全新`natural_terminal_a30fe00d`已实际启动，观察session2937，原V2失败profile不复用；必须逐阶段实际终态检查，当前尚未完成三组。最终双角色/原19/52/SDK/故障UI仍未通过。正式游戏源码未改。

## 2026-10-08：普通终局V2实际解析失败保留，固定延后加载V3待复审

`natural_terminal_b58fec06`已实际终态失败、锁释放（session35059退出1）：import PID22748退出0、引擎错误0，前后完整源/冷导入派生元数据及postcold identity核验完成；normal_fresh PID43612退出1、一个Compile Error：SceneTree primary probe过早预载Intent→Profiles→Campaign，autoload名称SteamService尚未注册。未进入自然玩法、没有终局/CFG/重启结果。原receipt/postcold identity/两日志保留`actual_failed_natural_terminal_v2/`，原profile不改不复用。

修正仅在V3探针：Provider/Intent/Lifecycle为固定Script变量，实际autoload/菜单180帧后才加载固定路径，生命周期变量显式RefCounted；producer/R9十四源不改，V1/V2源与spec保持。V3只读preflight成功，spec SHA`3e3a3d94f22d4778e68187e35c48f9fe47a3d5596f4824eaa41d45356c209f2a`，冻结`natural_terminal_executor_v3/`。新独立复审待终态，尚未新native；V2旧独立准入不能覆盖改后probe或代替运行通过。

当前没有自有Godot运行。最终双角色/19/52及SDK完整目标继续；正式生产源码未改，旧V11完整失败和v32后继仍保留。此前“新批运行中”等是历史，以本段及实际收据为准。

## 2026-10-08：普通自然终局三组执行器独立准入并实际启动

scoped V2独立收据`qa/campaign_progress_recovery_20261008/NATURAL_TERMINAL_INDEPENDENT_REVIEW_V2.json` SHA`e52b0b657ede0bbc70f4bd2ada17fc8531e479f3e1fcb8fc95ceb5437ead25e4`已实际回读。11 helpers、14 R9、80依赖、选用的两项Core/Contract及冻结副本一致，三类V1阻断修复；仅`natural_terminal_scoped`准入，不授予双角色/19/52/SDK/错误UI或full资格。

实际新批`natural_terminal_b58fec06`已启动（session35059），仅在连续idle60后按单进程隔离执行。三组：normal fresh/restart；真实gen2源码点中断/restart；真实CFG后ACK前源码点中断/restart。必须实际PID/nonce/stack、完整冷导入identity、普通时钟/CFG/gen3/无重放与原链不变全部通过才计此范围；正在准备/运行，当前没有结果可升级。失败保留全批，不重开或复用档案。

最终完整恢复consumer仍未实现，详见`FINAL_EXECUTOR_ADAPTATION.md`；V11旧full实际失败已保留，v32另待独立静态准入。正式生产源码未改，平台未发布。

## 2026-10-08：V11完整续玩实际失败，新普通终局检查准备

完整批`office_full_e85e9994`已终态退出1、锁释放，不能继续视为运行。导入11016、JSON5456、OwnedSlot16496及半程ABC27944/45552/34464均终态0；档案保护38872/41692按预期拒绝。Lu-first A PID37260、119检查，在real admission complete natural deadline失败；军队19仍存活、营1500血、吴用186血、没有牢门/火号/营救事件。六原工人及付费第二house/workshop/2投石车/12步兵均已实际走过，入牢失败具体原因未观察到。42份原收据/日志/报告保留`qa/office_campaign_full_20261008/actual_failed_v11/`，原profile保持，未上传CFG/玩家档。

旧full无法直接安装R9后验收：原producer要求Core/Contract两项变化、QA=1、v1构造器及两代生命周期；新普通恢复要求R9六替换八新增、正常QA空、固定root、active1→pending2→applied3，并真实写CFG。ABC/组件/live继承base和consumer必须有更严格后继，保留原检查/矩阵，不豁免或转移历史green。详细约束见`qa/campaign_progress_recovery_20261008/FINAL_EXECUTOR_ADAPTATION.md`。

新增普通终局工具`tools/run_campaign_natural_terminal_recovery.py`与`campaign_natural_terminal_probe.gd`：实际菜单首关、原生时钟1、普通玩家酒计/挑担/撤离，自然END后真实CFG/gen3与新菜单不重放；两处真正Coordinator源码断点经实际PID/stack确认后只结束自有Popen，再新进程恢复。三组各fresh/restart、四用户目录隔离、来源/native/冷导入/完整identity/nonce/ERROR/foreign闸绑定。V1静态发现revision字符串和来源/进程闸缺口，原V1源/spec保留；V2修复并真实只读preflight成功，spec SHA`1390dfbcf3b29d05dd665086d9027fc647d2e839bbc9511d3ff478f06b840dd9`。仍待独立具体准入，尚未native；只承担首关自然终局与两个恢复窗口，不是最终双角色+19+52/故障UI/Steam完整consumer。

v32旧路线候选仅将同样的付费扩军移到真实admission/入内院后、火号前，新增实际spy hp/invis/位置/命令诊断；六工人、军队规模/成本、所有原检查/ABCD/52仍保持。bundle/seal_v12（SHA`5dda50a489695c34a9bfeeec4ef8ee6ce3678976ac6a0db4d7dcde962bcc9f55`）已封，独立审查待完成、未native、不保证解决入牢失败。

完整开发目标继续：最终组合双角色自然ABCD+负例；普通fresh/续玩与最终19故障/配置确认重启/真实错误重试/奖励一次性；八章动态、美术动画UI/多尺寸；九玩法与导出EXE；正常时钟性能/内存及Android真机/平板。正式游戏源码未改，只白名单同步stable、不合并main或发布。

以下“V11运行中”等较早段落为历史，以本段及原终态为准。

## 2026-10-08：R9独立静态源码准入完成

独立审查收据`qa/campaign_progress_recovery_20261008/INTEGRATION_SOURCE_REVIEW_V2.json` SHA`6c558b6e5279972819c0ea90789e1e183ee86f00f045d4fc28e52f0ae63f47ec`已实际回读：R9十四源、80固定引用、十三正式来源、十四快照完全一致，12个历史阻断逐项静态解决。`approved_static_sources_only=true`，但`approved_stages=[]`、`full_executor_not_ready=true`、`native_started=false`。后继恢复全链执行器尚未完成，未扩展成原生/终局/重启/UI/奖励资格。

完整旧续玩v31批`office_full_e85e9994`继续串行运行；本轮生产源码没有变更。下一步在该批实际终态后串行解析并验证R9接入，再完成与独立审查最终全链执行器，核验自然终局、真实CFG和第三代确认/重启/故障UI及奖励一次性。更早“待审”描述为历史记录，以本段与实际收据为准。

## 2026-10-08：当前恢复接入源R9，来源与规范化同时保留

R8独立复审发现合法旧云记录的缺省字段/旧best_total与Campaign规范化结果不同，会导致严格确认无法完成。R9先验证原来源并单独保留原payload，再按既有固定记录规则形成唯一写入目标；初次attach和普通apply均在实际共享写入前冻结规范目标，不放宽最终SHA/目标owner/配置语义的漂移拒绝。十四源、80固定引用、十三生产来源零差异封存在`qa/campaign_progress_recovery_20261008/SOURCE_AUDIT_V11.json`与`integrated_source_snapshot_v11/`；R8及以前不变。R9目前仅通过来源预检，独立审查待终态、尚未运行原生解析，不称完整恢复通过。

当前完整旧续玩批仍为`office_full_e85e9994`（session53649），串行等待各阶段自然闲置60秒，不并发新恢复原生批。后继恢复全链执行器尚待实现和独立审查；完整目标仍继续。

## 2026-10-08：R5解析终态与R8确认保护，完整V11运行中

R5真实解析批`integration_parse_fc392cb9`已终态成功：导入PID1712、正常菜单180帧PID6124均退出0、引擎错误0、锁释放。原收据和两个日志完整保留`qa/campaign_progress_recovery_20261008/actual_integration_parse_v4_r5/`；仅证明这份R5源能导入/启动菜单，不能证明终局恢复。

独立复审发现R5首次binding失败前没有完整提案冻结，R6修复后又发现首次写入可覆盖未知tmp及close重试缺少共享CFG重读。R6/R7原源保留；最新R8十四源、80引用及十三生产来源冻结在`SOURCE_AUDIT_V10.json`和`integrated_source_snapshot_v10/`。R8共同binding入口拒绝已有tmp文件/目录；进入close前冻结实际campaign/settings/language三个文件的稳定SHA和目标owner/进度/设置语义，首次及每次close重试都重新核对、漂移拒绝不重置基线；shared未确认期间设置请求保留，确认后重新调度。R8未原生解析、独立复审待结论；新恢复全链执行器尚未完成，原生产未安装。

旧完整续玩路线v31经独立V11静态准入（SHA`4a770182fb38ee0afe8765cbdd243f87d0d421cfabfc3e8eb46c79917fc4c070`），全新批`office_full_e85e9994`已串行启动，观察session53649。完整原validator、双角色ABCD与52负例保留；当前运行中，不能写成通过。东侧金矿只有一个、正常单工人机制可能让后来的工人转去其他矿，静态准入只保证初始命令目标，持续存活必须以实际检查为准。此V11批准不覆盖新恢复十四源。

后续依次完成：双角色完整自然续玩；最终恢复源normal fresh/续玩终局→第二代日志→实际CFG→第三代确认及跨进程重启、19故障、错误界面/安全重试/奖励只一次；八章动态、美术动画UI/多尺寸；最终九玩法与导出EXE；正常时钟性能/内存及Android真手机和平板。Git只同步已记录范围到stable，不合并main或发布Steam。

以下段落记录较早状态，最新范围以本段和实际终态为准。

## 2026-10-08：十四源接入、真实16检查与独立拒绝后继

候选`integrated_v4_r2/scripts/`已把恢复模型接到Campaign/ContinueFlow/Battle/Menu/SteamCloud，含固定目录最多256合法token只读扫描、当前pending与已确认历史区分、三代确认、真实Steam token侧日志及Core分配前旧槽拒绝、one-use完成展示、延后设置写入和错误重试。正式13来源（含原Core/Contract、classic）SHA/提交字节零差异，未安装生产。

R2真实解析批`integration_parse_7cb75b98`：导入23272/正常菜单180帧40996终态0、错误0。真实启动/设置批`integration_startup_8f93ba0c`：导入42372/探针45576终态0、错误0、16检查全过。根Flow确实startup_checked=true，Gate开放；正常save_prefs延后写实际CFG，fresh ConfigFile读回hard/regicide，同内容重存SHA不变，无运行日志或Steam活跃run。原收据/日志/报告在`actual_integration_parse_v4_r2/`、`actual_integration_startup_v4_r2/`，原第一轮Projection内置名称冲突失败保留`failed_integration_parse_v4/`。只覆盖空档案和正常prefs，不证明pending/UI/终局/重启/奖励。

用户明确授权扩展独立审查至十四源及后继全链执行器。R2独立审查拒绝8项P1：源身份重试不复核、设置队列不唤醒、云错误无重试、A→B误拒绝、mirror/exit绕过gate、空active自有锁释放无重试、startup非progress CFG对象丢失、零代/恢复锁误判无pending。收据`INTEGRATION_SOURCE_REVIEW_V1.json` SHA`8fbcd0b708dbff0a18816e4c91139d3c2dd19c432f160ed6aa518fa6beee1d83`；14源/77引用/13生产和原真实证据回读一致。R3/R4中间修复不升级为资格，所有源保留。

最新不可变`integrated_v4_r5/scripts/`与`SOURCE_AUDIT_V8.json`、`integrated_source_snapshot_v8/`封存14源/80引用。新增实时完整身份复核及门禁后设置调度，Cloud保留原owner/目标owner/bindingSHA/初始完整身份并可见同对象重试，最底层mirror拒绝shared pending；CFG/lifecycle保留已成功移除原owner后的空目录释放阶段，仅核同实例/原nonce/路径/head/SHA及空目录后重试，不删除staged/pending/data；无proposal自有锁失败状态保留，零代/恢复锁阻挡启动，startup保留非progress CFG对象/原提案。新批`integration_parse_fc392cb9`只做隔离解析/菜单，观察session58153，实际结果待终态；独立R5复审进行中，不给full批准。

完整normal fresh/续玩终局→gen2→真实CFG→gen3、跨进程故障、19案最终源、玩家pending/安全重试、多章节和真实Steam奖励仍待后继完整执行器及实际证明。旧V2 CFG四案八PID36检查/v27b19案194检查只属原组件，不能扩展给这些新接入源。

## 2026-10-08：V3候选保护；旧组件通过范围保持

新增`proposed_v3/scripts/`八文件候选，原V2及其真实四案/八PID/36检查CFG证据保持不可变。V3协调器在访问Battle属性前先核验固定缓存脚本及当前真实scene；纯进度投影拒绝时，只能释放本对象持有且仍处于building阶段、无冻结/暂存/待写记录的CFG锁。释放失败保留原状态供再次核验；未知/丢失所有权继续拒绝，不承诺所有故障都可原位重试。真实已暂存提案/原文件/日志不丢弃。生产9来源SHA不变。

`SOURCE_AUDIT_V6.json`和`combined_source_snapshot_v6/`封存全部八源；本轮核对23个固定脚本引用及未限定本地方法名称闭合。这只是源码核对，V3未Godot解析、未独立审查、未原生、未接入游戏。旧V2组件和v27b19案均不扩展为V3资格。正常fresh/续玩terminal→cfg→ack、startup有界扫描、玩家失败UI、prefs/cloud排他写入及奖励一次性仍需集成和实际验证。

完整续玩V8-R3实际rally检查失败后已保留，独立V9批准的新完整批`office_full_b0f1d997`启动；本轮不同时开启V3/CFG native批。

## 当前：CFG四案例实际组件通过，完整续玩V8-R3启动

CFG新批 `cfg_component_40939c93`已完整终态退出0，锁释放：四案例、八个实际不同PID，36检查全部通过。正常替换/同内容重存、真实backup窗口中断并新进程恢复、真实install窗口中断并恢复、控制器实际外部CFG变更后的拒绝覆盖及新进程再次拒绝全部完成。真实断点源/函数/行/thread和文件SHA已由控制器绑定，偏好/未知字段/无关record保持。

原收据SHA `c555249e35c509b12655ed5c9f23bb4dcd26f639e646840a10ee4fc03604c09f`；原收据/日志/报告存`actual_cfg_component_v6/`，资格明细见ACTUAL_CFG_COMPONENT_PASS_V6。原V5初轮首案失败、原profile及源全部保留；V6只等待真实process frame进入非physics阶段并补失败code观察，生产磁盘守卫/原检查数不放宽。

新增progress gate和保留式terminal→cfg→ack协调器候选，冻结同局意图、每次重试再核对实际Battle/owner/context/安装身份，完成展示仅可消费一次；恢复只能进度，不重新构造战斗/Mission/结算。八GD来源见SOURCE_AUDIT_V5/combined_source_snapshot_v5。除CFG组件涉及的存储/语义两文件外，其余新候选仍未解析/native；新协调器未接Campaign/ContinueFlow/Battle/startup/UI/prefs/cloud，不宣称玩家恢复功能、gen2→cfg→gen3实际全链或奖励通过。

完整续玩用同一V8批准producer/seal_v8/v28三源、新UUID/profile再开V8-R3；目前真实结果须读本批，不能继承旧ABC作为全链。当前只运行这一自有完整批，不同时重开CFG组件。完整八关/生产运输/美术UI/九玩法/性能/Android原计划继续。

## 当前六份GD候选与完整批终态

新增WorldSession候选：campaign用严格v2、classic用原v1；在Core.prepare前和mount前核对真实脚本/token/root/context/安装身份/owner。旧不绑定章节的campaign v1明确拒绝，不迁移、不修改原记录。新增纯同局投影保留偏好/未知CFG及record数据，不union跨局目标；无文件/回调/战斗/奖励操作。六候选原字节与9生产来源核对记录在SOURCE_AUDIT_V4/combined_source_snapshot_v4，未解析/未native/未接入正式游戏。

完整V8-R2已在Lu-first A期间因外部Godot进入终止，完整双角色仍无资格。当前唯一新自有批为CFG组件cfg_component_c5212404/session41902，使用源封存V5；控制器等待自然空闲，尚无Godot结果。没有同时新开完整续玩批。旧19案只属v27b，不能延伸为本轮候选或玩家恢复通过。

## 当前v2后继与受控CFG组件候选

`proposed/`原v1与SOURCE_AUDIT_V1原样保留；其三代模型会受到父存储默认只留两代的影响，不可作为native准入。`proposed_v2/`四文件候选修正三代保留、只有本对象实际提交/持有原锁才取得结算能力，新增v27b原数据Variant/语义helper和受控CFG替换。

Windows官方tag的不同名rename会先删目的文件，候选先将旧CFG移入自有固定备份、再向空目的安装；全流程固定元数据/SHA、深拷贝ConfigFile、真实save/fresh load/完整语义回读。旧文件未知字段、偏好及无关record保留，backup/install窗口可由新进程按同事务恢复。备份前重新读SHA，拒绝外部改动时保留公开CFG。全文件encode_to_text缺少章节名转义，仅用于大小估计，不再作为恢复序列化。

当前仅Python解析/固定依赖与源检查，全部9份生产源码SHA未变；没有安装正式工程、没有Godot解析/native资格、没有独立审查。当前源为`CFG_COMPONENT_SOURCE_PREFLIGHT_V5.json`与`SOURCE_AUDIT_V3.json`，完整案例和执行约束见[组件计划](CFG_COMPONENT_PLAN.md)。v27b旧19案通过不延伸到这些新候选。完整协调器、入口/扫描、pending/UI/prefs/cloud、自然终局及gen2→cfg→gen3 ack仍未集成。

# 战役终局进度恢复：v2 日志基础候选

当前只有两份新GD候选，放在本目录`proposed/scripts/`，没有安装到正式工程或任何正在运行的QA。尚未经过独立审查、Godot解析或原生测试；不是玩家恢复功能交付。

原`run_local_lifecycle.gd`经典v1和`run_snapshot_store.gd`保持原字节，分别SHA e68cb817…/581e638b…。新campaign sibling沿用原存储层的canonical UTF8/envelope/payload、previous SHA/CAS、持有者原锁重试与死进程恢复，不放宽v1。新版精确gen1 active→gen2 terminal/pending（原同局冻结结果）→gen3 terminal/applied（真实cfg确认）；3代全部保留，缺genesis、跨context/token/owner/installed identity、gen2→gen3结果/胜败改变均拒绝。

Intent从真实当前END Battle、安装章节分类、原Mission对象和实际result_snapshot取得，仅记录原同局6个进度字段。八章固定version/goal IDs已与当前叶脚本/继承父脚本逐值核对；这只是目录/源码闭合，不证明八章自然结果。恢复验证只读数据，不重新创建Battle、Mission或章节工厂，不重复tick/胜利画面/Steam结算。

ack只能接受真实非QA写盘回读收据；另外独立读取固定`user://campaign.cfg`，核验稳定原SHA、owner、解锁和单局非叠加结果。QA suppression不能作为ack；败局只能确认“不需要写进度”，不声称写盘。历史gen3的cfg SHA只作为当时收据，后来合法偏好/其他关进度更新不要求永远保持同一SHA。

原存储层原锁重试会对任何terminal record标记终态，因此新版另持结算能力：progress-only recovery的ack重试不会获得新Battle/Steam结算授权。所有cfg/ack不确定写入仍待完整协调器接入。

仍需实现和验证：Campaign纯投影及受控临时文件/CAS替换，prefs/cloud与进度pending写入锁；WorldSession按actual/slot context选择v1或v2并在Core分配前二次核对；ContinueFlow的普通fresh无save胜利与terminal→cfg→ack协调、startup有界发现/恢复与async安装；Battle结果只冻结一次、玩家失败UI/安全重试/一次性展示。然后独立源码审查、正常QA=0双角色ABCD、gen2后退出/cfg后ack前退出的跨进程故障、旧classic原字节/完整故障回归。完整原计划与平台/性能/真机资格保留。

`SOURCE_AUDIT_V1.json`为当前候选及实际生产来源/八章目标表的源码核对，所有runtime资格仍false。设计依据为`qa/zhu_wounded_20261005/proposals/campaign_local_context_progress_20261008/DESIGN.md`，当前运行批及旧失败profile均未修改。
