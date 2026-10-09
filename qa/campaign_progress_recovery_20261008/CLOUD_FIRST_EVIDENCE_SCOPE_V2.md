# CLOUD-CFG-GENERATION-001 有限修复

原 V1 源/225pin seal、17合成结果与独立拒绝保持不变。V2 physical helper只在strict_journal入口加exact int且native 1..2147483647，在journal_names对prepared/applied两代同时核范围，其他原物理/copy/SHA/字段/源/owner/hash链语义不变。runtime V3和首次consumer V2只更换physical helper import；原类执行正文不改。原packet replay V1不改。

27合成检查包含原17和10项实际overflow反例/范围边界：V1接受2147483649被复现，V2拒绝，single native upper bound允许，0/负值/bool/float拒绝；最大完整pair2147483645/2147483646允许，而末代或两代溢出拒绝。这些只为伪造文件/数据与fake-holder拒绝，不证明实际Popen/ConfigFile semantics/native/restart。

请仅复核这个已确认generation遗漏的有限差异、原pin保持和边界检查；不重跑大矩阵、实际phase或Godot。新原件仅修原native字段范围，stage=[]。完整native全CFGsemantics、同档案cloud restart、complete producer/成功V12前置/执行准入及全部原目标继续保留，不把中间consumer当完整云用例完成。
