# 高俅继续流程：单文件 runtime 候选

本目录仅记录代码准备：**未冻结、未导入、未运行引擎、未复现高俅实际运行影响、未采用生产**。基础源是 `20261027_013339_8495b720`，身份 `source-v1:d7f2258b8be6f77e3577ff9c3b018427c805c84385e86f1daa54aaa49cc30dac`。既有连环马或其他章节的结果不转授本候选。

当前源码可证的缺口：Flow 的通用 runtime 仅装配基础定义、内容包和视觉规则；d7 Session 只为严格 `Profiles.LIAN_CONTEXT` 调用章节工厂。高俅的船坞、船只及正常造船定义来自现有 `Level5.apply_overrides` / `Naval.configure`，通用 runtime 没有完成该装配。这里仅补调用，不调整费用、人口、时间、存档数据或目标合同。

唯一候选 `scripts/run_world_session.gd` 以 d7 的完整原字节为底，只增加固定 Level5Factory preload，以及与 Lian 并列的严格 `Profiles.GAO_CONTEXT` 分支：调用 `prepare_runtime(_trusted)`；失败原样返回，沿用现有调用者回滚；成功后释放尚未 prepare 的旧 Core，并用受信 runtime 重建 Core。插入点保持在原槽身份、账号、credited/uncredited 本地 LC 检查之后、原 `_core.prepare(_packet.world)` 之前。其他 context、公共 classic30 门槛、scope/token/CAS、LC 顺序和终局逻辑均无差异。

来源和精确 SHA 在 `sources.json`；`candidate.diff` 是相对原 Session 的完整差异。静态检查确认移除这两个新增片段即可逐字还原原文件，全部其余字节不变。该检查不是 GDScript 编译或高俅自然续玩验收。后续由根线程单独决定冻结及验证，本目录不提供执行入口，不修改原候选、冻结工程或当前 classic 输入。
