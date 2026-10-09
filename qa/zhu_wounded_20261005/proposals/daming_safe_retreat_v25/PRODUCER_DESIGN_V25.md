# v25 producer 设计：当前不可运行

本次只准备设计/参数，不复制执行 producer、不启动引擎、不修改公共源码。参考 `E:/ChatGPT/daming_admit_v24o_proposal/run_daming_admit_v24r2.py`；其执行/合格状态仍须由实际收据判断，不能从 prepared header 推断。v25 runner 正在后续审查修复，runner/scene/route/negative-suite 最终 pins 暂为 null。所有必需项审查完成后生成新 sibling，旧 r/r1/r2 和任何已执行脚本保持原位。

## 严格 source/runtime 桥接

旧来源继续是原生合格 donor：raw5039rows、5035不同path、仅4对完全相同重复row；完整运行源5100，identity `source-v1:b77b36b6ef91e7cd569c4a8c49096ae1e02bf2b0f92cc68bde4f806ac146367e`；world artifact SHA `f936f08d03f26761dba247656c66047281f2155cbcaadbd05270f6d19091c8fd`。先完整验证该旧来源，不能拿当前候选预计算值替换其来源证明。

当前候选 receipt 要有恰好6行且6个distinct path。4个替换是 `run_snapshot_store.gd`、`run_slot_store.gd`、`run_level8_unit_contract.gd`、`run_battle_world_core.gd`；2个添加仍只是 `run_scenery_json_boundary.gd` 与其 `.uid`。每个替换的 before SHA 要同时匹配旧raw manifest行与旧5100真实donor；添加的before必须null且旧两张清单均没有该path。after SHA/bytes要匹配**已正式apply后的实际ROOT生产文件**；不得在冻结私有工程里贴 external proposal、替换函数或绕过生产manifest。

从旧5039 raw rows逐行替换4 paths并增加2行，所以当前仍是raw5041 / distinct5037。v25两脚本是替换，不增加文件；不能改成raw5043或runtime5104。旧4个重复path SHA、大小、行数不动。复制每个unique file一次，但保留raw row出处。

完整5100 donor逐SHA构造 expected_rows：替换上述4旧项，添加上述2新项 => 恰好5102。native依赖固定原manifest。native安装后、88 companions之前应为5014；准确恢复原清单88个源侧 `.import/.uid`，其SHA/size与donor原项相同；不能把它们当缓存漏掉，也不能将新import生成内容列成允许添加。完整 files/dirs/rules SHA必须等于expected_rows，原 `installed_identity` canonical算法不改，重新算当前content_version。所有Native Provider必须独立返回该当前digest；Python预计算不代替原生Provider。

QA runner/scene/route/negative harness/fixtures只加在运行源规则之外的tools/证据路径；添加前后完整5102 runtime身份必须完全一致。import之后每阶段 `input_integrity(True)` 的源/私有/native/88companions/工具/完整runtime guards保持全量，不允许放宽 additions 或先import后重新认领修改。

## r2 精确需改位置

`PRODUCER_CHANGE_MAP_V25.json`保存所读r2全文件SHA及各def的实际line/body SHA。以下是变更范围，line最终以该地图或重新读源码为准。

1. module `CANDIDATE_CHANGED_PATHS` 增两个已存在production路径；`CANDIDATE_ADDED_PATHS`不变；CURRENT_CANDIDATE_INSTALLED_FILE_COUNT仍5102。将SCOPE/receipt schema写成v25分项资格。保留原deadline≤授权UTC22:00，不能重新给15分钟路线扩展夜间授权。
2. `Runner.select_candidate`：len(rows)==4改6，exact whitelist变为4changed+2added；before/after/donor/ROOT核对和5039→5041/5037逻辑原样。scope不再写two changed/four qualified paths（候选尚未qualified）。新的六项receipt与原四项receipt分别pin，检验前4项完全同值，后2项对应公开ROOT已apply的candidate。
3. `Runner.preflight`：原5039 manifest、cached receipt/source equality、full5100 native artifact、original88 companions、engine/native anchor、helper当前commit SHA、原失败ancestry、OwnedSlot原工具保护全保留。增加runner审查、final manifest pins、negative实现门禁，**门禁失败发生在wait/cache复制/engine启动之前**。追加的新harness来自单独explicit args，不能依赖 `Path(__file__).with_name(...)`找到旧v24o，因为新producer放在v25目录。原admit GD/scene改成显式原目录路径，仍pin原实际bytes；新producer自身正确pin，不错误要求它与旧r2同目录。
4. `Runner.prepare`：runtime expected_rows循环本身已支持任意candidate_rows，不减弱；保持5014/88/5100/5102，更新scope及6paths来源。tools添加白名单增加审核后的v25 runner/scene/route及negative bundle；最终完整runtime身份不变。profile从一套拆为regression/original_admit/lu_first/shi_first/negative子profile，每套4个APPDATA/LOCALAPPDATA/TEMP/TMP，完全隔离。允许同一冻结project按序运行所有profile，不能两进程并发。
5. `Runner.prepare_regression_inputs`与`execute_regressions`：保留JSON11正case集合、完整负例checks与wrong-kind来源、`.0` canonical拒绝、source/fixture/content/engine零factory/diskwrite guards；保留原OwnedSlot≥76完整故障分支和4源码SHA。原JSON boundary依赖的旧fixture级Component资格无需更换为v25world。两个existingproduction替换已额外纳入当前runtime身份，但不得更改原fixture原始SHA来凑资格。
6. `Runner.execute`：继续natural idle和同锁流程、native import/profile_guard、JSON/OwnedSlot、原admit完整ABC回归。再跑v25两变体和负例依赖；不能把旧 `CASES`整表换成4case而丢原ABC。使用两个固定case组 `ADMIT_CASES` 和 `RETREAT_CASES`、显式group/variant-aware reports字典，不重复case key覆盖前变体。
7. `Runner.verify_slot`：保留原admit路径/chain验证；新独立 `verify_retreat_slot`定位 `daming_safe_retreat_v25/continue/v1/5088120/1/record_%010d.json`，引用对应variant的A世代1SHA作B世代2previous；retained_slots必须按group/variant子目录，防止同generation文件互相覆盖。C/D不会再保存，核对原世代2头SHA不变。
8. `Runner.validate_case`保留原admit mandatory labels及orders A2/B/C0原契约。新增 `validate_retreat_case(variant, case, ...)`：核验新schema/first_role/actualPID/nonce/installedcontent/engine、全部checks真实pass、阶段不可互代。B/C原完整22section、packet/flags/options/settings/root-node、Mission/Root时钟重基、完整refs/grids、单一新bindings必须逐label具备；不能仅看passed或新增qualified字段。C普通新订单被允许，但orders必须来自真实route_commands SHA；D没有route订单。
9. `Runner.validate_retreat_case` C/D需要producer独立读取actual slot bytes / local生命周期chain / terminal文件 SHA（owner1、App5088120、local magic LH_LOCAL_CONTINUE_LIFECYCLE、revision1→2、previousSHA、canonical payloadbytes/hash）；terminal必须local-victorytrue/固定token/原固定CONTEXT，C的frozenMission结果与报告/内存Campaign一致。D实际Session code LOCAL_RUN_TERMINAL、未分配Battle/Unit、old menu保留。Campaign持久资格false，producer验证campaign.cfg未新增/未改而不是宣称内存结果已保存。
10. final audit不能继续硬编码3process/最后CASES[2]/单profile树。统计原admit3+两变体8=11个主要原生进程，另外import/guard/regression/negative单列；每个实际PID与nonce不能重复，前一进程CIM确认terminal且时间不重叠。收集每套独立profile完整owned slot/lifecycle/known campaign证据manifest，不上传玩家存档/cache。只在全部必须阶段真实pass、所有guard零drift、own锁成功释放后 `complete=true`；任一not_run/缺负例保持false。

## 必需负例缺失必须前置拒绝

当前5项负例只设计，尚未有native harness/scene/实际source捕获和JSON入口实现。参数明确 `negative_suite.implemented=false`、pins=null。未来producer不能接收skip flag，也不能用空checks/all([])、component-only false schema或此前别批阳性替代。预检返回 `V25_NEGATIVE_SUITE_NOT_IMPLEMENTED`，保留前置失败收据，没有engine调用。

完成实现后negative manifest必须列出真实路径/变异标签/source DTO、真实capture、JSON document+完整Core等route区分、每种first_role和报告最低集合；至少覆盖refs._queue、原stop字段、other live/root/active、selection/caster、五records所有identity畸形leaf（不能用5计数代替所有path）。外部审查需证明目标代码真的执行该validator，不靠只坏hash/坏Codec壳制造拒绝。negative报告须逐项source+JSON实际PID/source身份/fixtureSHA/controlled code和零SCRIPT ERROR，无跳过。

可用variant A实际单人撤离后的原完整saved world为阳性fixture。每种variant先A退出并保留world/packet原SHA，随后专门negative子profile完成该variant的组件/JSON/真实capture负例，合格后才允许B→C→D。这保留A真实来源且不会先凭空造单人safe记录。负例不回写A profile或slot；需要安装其完整world的negative进程只在新隔离profile中复制明确QA slot/lifecycle字节、核对来源与hash，不改token/record、source路径或runtime脚本。若负例阶段只做到source DTO，就必须实际capture负例仍not_run、整批不qualified，不能改口当全部source通过。

## 发布与工作结束边界

本批只源码/QA，公开campaign continue不打开，Steam奖励/平台上传/releaseEXE/Android/performance资格均false。C可能真实natural victory，必须等durable local terminal与真实frozenMission/报告一致；D只终结回读，不能声称其推进了玩法。正常私人profile的Campaign持久写盘另排专门flags审查批。共享Godot连续自然空闲60秒再开始，运行中外任务引擎恢复只终止自己child并保留失败；不控制、发消息或停止其他任务。不得重复执行工程失败的producer，修复只能新 sibling/fresh profile。
