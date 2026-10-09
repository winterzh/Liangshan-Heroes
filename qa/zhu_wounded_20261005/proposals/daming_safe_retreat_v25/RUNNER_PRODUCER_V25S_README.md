# v25s 外部未执行 runner 与 producer

新 runner `daming_safe_retreat_cross_process_v25s.gd` 与同名 scene采用外部v24s的四个helper（owned/other links、summary、cleanup）及完整 `_hold`，方法LF字节完全相同。原v25其余35个方法逐字节保留，仅header诚实注明s45024仍未fullpass；原6a70 runner、scene、静态审查及实际旧_hold失败来源不改。

新 producer `run_daming_safe_retreat_v25s.py` 显式base为 `run_daming_admit_v24s.py` SHA049dcdc74fab7936d4812f71a9806cee46569163ece4c524043ac7cfdedd8626。因此继承安装、native_phase和原admitABC validator都使用s修正后的工具和hold connection审计，不再运行r2的旧坏工具。子类完整override select_candidate仍为6项，generic freeze、5039→5041/5037与5100→5102/88metadata、原JSON11/OwnedSlot/native全identity guards保留。

启动前必须独立验证actual successor成功收据：exact s producer/engine、ABC report与原完整log的SHA、每个actualPID/nonce、terminal0/error-free/序列不重叠、complete与lock_released，且新runner `_hold`与actual通过后的harness方法SHA一致。当前s45024并未fullpass，没有成功证明，所以明确blocked，不从partial A、静态review或“修复看起来正确”推断通过。`PASSED_SUCCESSOR_PROOF_TEMPLATE_V25S.json`仅模板，字段false/空receipt不会放行；新runner尚需独立新cross-review。

已为 `NEGATIVE_WORLD_INTERFACE_V25.json` 的真实source/JSON DTO报告写精确adapter：actualA五项fixture来源、132case×2route完整Cartesian set、actual controlled codes与guard层、pre-dispose Battle/identity/plan空、input typeof/IEEE/cached grids不变、两个actual unmodified fullCore positive、14项真实validator源码SHA、actual process/content/engine/完整log、所有fixtureSHA independently回读。`NEGATIVE_WORLD_CONSUMER_MAP_V25S.json` 是source-derived static期待值，不是native通过，原报告保持raw scope flags。

当前separate Unit/Pair component和actual live object capture消费者仍未实现，不被完整DTO matrix取代。模块中两个implemented常量固定false，preflight即使收到自称implemented的JSON也拒绝，直到另一个新source sibling真正实现审查后的消费者。这保留明确缺项，不会跑到A/DTO之后才把剩余阶段省略。`run_negatives`还有显式缺项拒绝，不返回假pass。

本次只有新外部source/scene/metadata写入与AST编译，无CLI、base import、Godot、公共源码apply或native through。已有release/default与Git主分支不涉及。Campaign持久/Steam奖励/公开Continue/EXE资格false。
