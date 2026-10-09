# 首次云回调报告、原包与物理 CFG 中间消费者

完整云用例依然需要 native 全 CFG semantics、普通同档案 restart 和完整 producer，本轮不删减这些要求。新增中间 consumer 只接 actual first-report、全部原 arm/callback/tail bytes 与 before/after 物理 CFG/十四字段保留日志；它始终返回 full semantics/restart/whole qualification=false。

新 packet replay 由已审 V2 原尾流重放派生，保留全部 event size/path/SHA/index、adapter/controller重复frame、send_attempt/真实send_complete、EOF与拒绝prefix顺序/全部原尾流解码。新增 ready→唯一完成arm→原ack→真实matched production stack→read→snapshot→disable/continue；独立解码原 ack/snapshot 必须同元数据、同原apply-ready节点和原cloud状态。helper永远不能证明 Popen、SDK、断点安装或整个用例。

新物理 helper 在实际 held/live Popen、处理ready/发arm前捕获原public CFG及当前保留的prepared/applied pair到私有 immutable copies。新 phase V2 只在原 controller构造后、receiver创建前增加这次调用。原public可被真实write更换，故不以freeze原可变路径阻止正常写入。完成后独立复制当前public CFG和两个实际新generation原日志，要求14 typed fields、源/owner/cloud operation、exact before/candidate SHA及previous-byte chain。当前被裁剪的更早ancestor若无原bytes，显式记录不可用，不发明完整历史链。

首次 consumer 要求 actual retained terminal Popen/同phase object/PID/nonce/exit0/errors0/privateenv、原三closed exports/完整33有序labels/唯一marker、full15 Provider identity、original apply-ready及report/arm一致，然后调用原包和实际物理验证。constructor/source-only/synthetic输入都不能授此资格。没有完整producer调用它，实际完整validate尚未运行。

17项合成检查使用伪造private packet/journal/binary文件，仅涵盖握手/metadata/EOF、完整14-field physical copy与wrong hash/owner拒绝、duplicate JSON拒绝、fake-owner拒绝。不运行 Godot ConfigFile parser或任何owned native phase，不计原19。请有限审查source/API与确定阻断，不扩模拟矩阵；approved_stages=[]。实际current engine兼容、native full semantics、restart/完整producer/成功V12前置/运行准入及全部原目标继续保留。
