# 续玩基础：真实Unit值字段适配（2026-09-06）

Unit值适配器已在当前生产Unit类的真实实例上通过77条检查，仍是隔离草稿，没有赋值恢复或生产Battle调用方。它把明确字段交给已测值codec；本轮证明字段采集与验证，不证明整个战斗可以保存后继续。

## 已实现范围

离线索引覆盖当前Unit的272个顶层var；运行时显式读取241个值字段，再读取继承的position/modulate，共243个值。其余26个引用/身份/关系/队列字段明确延期，5个仅绘制缓存排除。完整字段表及实测源在 [QA归档](../qa/run_unit_values_20260906/ARCHIVE.md)。

`capture_values(unit, content_fingerprint)`产生带来源/内容合同的标签记录，`validate_record(record, expected_content_fingerprint)`完整解码并返回原生值字典；失败不返回部分值。没有运行时property list遍历，也不调用setup、下令、伤害、重算或物理步来重造状态。每个Unit整棵值树只调用一次codec，不能逐字段绕过总预算。

保留血量、护盾、成长、计时器、施法/挥击进度、已付费训练、路径及光标、技能槽的精确int64序号、变身备份和廉价视觉连续性。只有三个明确字段允许各自的正INF哨兵；普通字段仍拒绝非有限值。`_path`显式转换并重建PackedVector2Array，保留负剩余冷却。`_weapon`会影响下一击节奏，不能当作可丢弃的绘制缓存。

来源合同锁定当前Unit及codec。调用方内容指纹仅被传入/比对，本模块没有计算或完整验证有效Defs与业务内容；setup_def仅受有限值树与顶层键类型约束。因此它不能单独作为不可信完整战斗快照的validator。

## 实际QA

运行 `20260906T150602925243Z` 使用当前已导入工程与正常Autoload，独立APPDATA/LOCALAPPDATA/TEMP/TMP和新输出目录。实际非console Godot 4.6.3 PID39904，exit=0；77条检查包含12条来源检查和65条其余检查。原始日志无Unicode/Parse Error等诊断，真实玩家设置及2713份来源前后不变，共同锁已释放。没有复制工程资源，也没有接触真实玩家存档。

QA在Autoload就绪后加载真实Unit，创建未setup且未入模拟树的实例，验证默认和复杂状态经过真实JSON中转。检查类型、大于2^53的序号、路径、技能槽、变身、负计时保留；采集不额外消耗RNG，采集/验证不发Unit信号、不改变源值，解码容器不与源共享。错误来源、缺字段、多字段、类型/枚举/路径/技能槽/哨兵错误及Object定义拒绝。目标已释放时，引用字段仍明确延期，不能据值层通过说成已经恢复引用。

报告SHA为 `a95cefeec92c3187cfaefb41faaf1ca7983d312590b1c2a97d656ce200503836`，独立摘要和原始日志见 [current_qa_summary.json](../qa/run_unit_values_20260906/current_qa_summary.json)。静态索引/启动器假报告拒绝检查与实际77项分开，不重复累计。

## 下一步

所有成功接口仍返回`restore_ready=false`。还需显式稳定ID与none/entity/expired引用、订单目标、来源池/历史身份、Inventory、地图/Battle/meta、暂停屏障及恢复赋值。实际快照必须先完整验证，再重建场景，并在独立进程恢复后继续真实行动。未入树的单Unit测试不能替代这些验收；M3仍开放。


## 2026-09-07 后续进展

值层受测原文保持。后续[引用/队列适配](RUN_UNIT_REFERENCES_20260907.md)新增17个声明字段并完成162条组合检查，原26个延期字段中仍有9个身份/来源/容器关联字段未覆盖，5个绘制缓存仍省略。[物品栏局部值](RUN_INVENTORY_VALUES_20260907.md)也完成独立155条检查，但没有owner/效果或全局UID恢复。前文77条值层历史范围不改写为新检查数；完整Unit、Battle和跨进程恢复仍未完成。
