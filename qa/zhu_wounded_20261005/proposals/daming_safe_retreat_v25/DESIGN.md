# 大名府单人安全撤离 v25 源码提案

状态：外部未 apply、未 native parse、未运行。公共源码和任何已执行 producer 不修改；v24r 的钉住输入保持原位。

## 实际缺口与不变的原流程

真实 `Level8.process` 在 rescued、gate_open、本人 alive、退出距离≤130和格 y≥45时先 `resolve_story("retreated")`，再 mark 本人 safe event。Unit 不死亡、不 free、不离开 units_root / Battle.units。退出者 hp≥1、非 dying、隐藏、passive/stance3，并保留稳定ID；命令被原 order_stop 停止。首次 native HELD 仍可保留本物理步前段建立的缓存网格引用，不能清缓存、重新编号或从 active_order 删人。

现 `run_level8_unit_contract.values` 只允许 gate 的 retreated，拒绝真实 lu/shi。现合同配置没有 Mission events；所以本提案把 Unit 层的结构资格与完整 Core 的强制事件配对分开：UnitGraph 的组件资格始终 complete_world=false，不能把它单独宣称为完整续存资格。

## 精确实施范围

只修改两个既有脚本：L8 Unit contract 和完整 Core。未增生产 helper 或 UID，不改变 Level、Unit、Mission、Map/Scenery、Codec、Store/Session writer、原停止/退出/胜利回调或公开 Continue gate。

L8 单位分支仅扩展固定 Level.references lu/shi、正确原 key、已获救非战斗身份的 retreated。要求 rescued/prison_open/gate_open、原 hp/dying/隐藏/passive/stance/selection、实际退出几何以及原 order_stop 清理过的 path/queue/mission-order/targets/pending windup。所有原身份检查继续运行；gate 分支保留原判定，其他人物或 outcome 仍拒绝。active/root membership 函数逐字节保持。

不虚构额外停止条件：原 resolve_story 不保证 is_active=false、manual_order_active=false、garrisoned=false、_path_i=0，也未禁用 Node process flags。保留这些原始数据和现有通用驻军/引用/生命周期校验。这里只校验原操作确实写过的字段。EXIT_CELL/CELL 取固定已安装脚本常量；不创建 Map 或执行 deployment/tick。

## 完整 Core 强制配对

私有 `_validate_daming_safe_pair` 只接受真实 Core 固定 L8 上下文，直接验证所给完整 UnitGraph、Level、Presentation、Mission、Root 记录；不收 caller “已验证”bool，不拿 Unit metadata 判资格。Mission token/presentation token/version 由现 World profile+installed identity 搭配，原三个 validator 强制同一 token/context。

每角色 lu↔daming_lu_safe、shi↔daming_shi_safe 双向对应；事件存在而演员不退却，退却而事件缺失，或演员引用不在真实图中，都拒绝。安全者仍同时位于 root_order 与 active_order。必须有原 daming_prisoners_freed、daming_rescue 已完成、daming_rts stage、Level三个阶段旗标。单人 safe 保持真实 FIGHT/resume_eligible；两人 safe 在原 native callback 必然 win，因此两 safe+FIGHT不接受；本提案不实现 terminal campaign resume。

capture 在所有组件完成后、最终整个 world 输出前执行；拒绝时遵循原 caller identity 归属处置。prepare 在 Map 原验证之后、首个 B/Unit/tombstone 分配之前执行。新增 proof Identity 只是 RefCounted 的抽象实体声明，执行完整 Root 原验证后立即 dispose；不会创建 Unit/tombstone 或进入树。原最终准备/绑定/激活各阶段与全部 guards 保留。

数据记录的一致性不能代替真实原生来源证明。未通过下列正负例不得 apply 为已合格交付，不开放公开继续或发布平台版本。

## 必需原生验证

1. 用原救出、夺门、普通玩家移动和自然 native tick，分别达到 Lu safe/Shi未到、Shi safe/Lu未到。每种都完整 Session 保存、退出、独立进程 install，逐项完整 world/packet/时钟回读，继续 ticks再存；事件、报告及退休者身份位置不重放或复活，另一个人仍可护送。
2. 保存紧接真实安全回调的首次 HELD，以及至少一个后续原生 physics tick后的 HELD。保持完整缓存和 ID；重复调用原 resolve_story 返回false且不新增报告，不调用它来构造本项自然路线。
3. 字段分离负例：safe event缺失/交换/演员未retreated/角色引用别名或缺失；rescue/gate/prison状态、退出位置、身份/art/speed、hp/dying、visible/selected/passive/stance、queue/path/mission-order/targets/pending动作；从root/active删除、重复、ID别名；两safe却FIGHT、daming_victory或terminal Mission。
4. 改 Mission/profile token、content/engine身份，验证每次完整 Core.prepare 在新 Unit/tombstone 数量0时拒绝并保留原已安装场景。畸形 DTO leaf须返回受控code，不能 SCRIPT ERROR。
5. 回归原 gate退却、bound初态、admit半进度、已获救未撤离、死亡普通兵/工人/矿点/支援、其他七章与classic；gate/其他角色规则不能被白名单扩展。
6. 两名均原生安全导致原 win 的最终结果和奖励一次需另行原生证明，不能借本提案结果称已完成。

## 审查与来源

`original/`保存读取时两文件完整原始字节；`proposed/`为候选；`proposal.diff`为唯一 apply 范围；`RAW_LINE_SHA.json`保存原文件SHA、每原行字节SHA、候选SHA及所有改动区间。原源码再次比对须一致，任何钉住执行结束前不得 apply。该提案尚无 Godot parse/行为资格；新 Script 依赖只有原项目 Daming/Map 两个固定文件，需要原生 import 检查类型/循环引用。

## 第二轮 API/原生语义交叉审查修正（仍未执行）

- 已修正初稿的确定 API 错误：`_queue` 不在 values，来自 run_unit_state 的 references._queue（1950–1974）；空队列断言在 L8.parts 中读取已原验证的 refs._queue，values 只读原 _path。
- 单 safe 才新增两名 required actor约束：Lu/Shi引用均非空、在完整记录/root_order/active_order、hp>0且非 dying；没有safe事件的另一人 story_outcome 必为空。身份仍由固定角色原 UnitGraph合同完整检查，不能用同 key但非角色的普通单位替代。原 Level8.on_unit_died:482–484 对二人死亡立即 lose，所以此前单 safe + null/dead/dying另一人不能再误收。
- 原 order_stop:493–510、_clear_hua_lock:3250–3252 确实写过 `_chase_intent=CHASE_AUTO(0)`、`_group_cap=0.0`、`_home=position`、`_has_home=true`、`_hua_lock_shots=0`；已加入仅退却获救者的精确合同，所用字段均在 run_unit_state.RULES / _read_values 中。
- Battle._on_unit_story_resolved:17525–17530 明确从 selection 删除本人、清其 ability/item caster、pending_cast/item_cast、walk_cast/item_cast 和 channels。Root现 validate仅验引用known-id；Casts/ItemCasts validate只验完整shape/tag，不验story outcome，所以新增单safe跨记录约束。先用原两个完整validator取得 `arrays`（不是value），再拒绝safe ID充任c/caster。不清缓存/grid/groups，不删除其他角色或残留target/effects。
- 在五记录（units/level/root/mission/presentation）调用旧validator之前，先要求身份schema/version等固定scalar为String、Mission/Presentation上下文为精确四String字段；无类型转换。Malformed null/bool/int/Array/Dictionary叶子必须受控返回code，未运行负例之前不宣称无 SCRIPT ERROR。

新增必需负例：required actor null/缺记录/不在root或active/hp≤0/dying/非safe却其他outcome；每个新stop字段单独篡改；Root.selection与ability/item caster指向safe ID；五个cast arrays分别保留safe caster；五记录各身份/context叶类型矩阵。每次负例后源 packet和值/顺序应严格未变，Core.prepare 新 Unit/tombstone 数量须为0。原初态和零safe情形不套用新增两 required actors条件；旧 gate与membership函数不改变。
