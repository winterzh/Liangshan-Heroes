# 原生场景归属索引的保存边界修复

当前四文件已由v24s完整验收：固定JSON533、OwnedSlot76、实际A39/B351/C342及最终5102源码/原生核对通过，纳入stable同步。公开战役续玩入口仍关闭。下面r2描述为历史失败。r2固定JSON11案533项与原OwnedSlot76项通过，A真实保存退出32项通过。B独立安装全量比较已写证据，第二次HELD因QA自己的重复rejection信号连接ERROR中止；B无最终报告/C未启动，整体仍失败。新sibling只修测试监听生命周期，不覆盖原生产者/profile或放宽任何世界比较。

大名府的真实任务办理半程验收通过正常移动到达触发点，进入真实 HELD 后调用 Session.save_held，返回 NONCANONICAL_RECORD。A进程终止，B/C未启动。v24p在同一失败事务中保留原 pending proposal 的两个完整字符串，确认196个场景归属索引从整数变为JSON浮点，其余形状和值无变化；UTF-8文本增加392字节。首个差异为 world.sections.map.sections.display.ownership.sprites 中的2与2.0。原规范格式检查正确拒绝了发生变化的记录。

证据：qa/zhu_wounded_20261005/daming_admit_canonical_root_cause_v24p.json、canonical_original/normalized_v24p.txt及原生报告/日志。未重新捕获另一份世界来替代失败数据，没有重试不安全的原写事务。

## 候选边界

通用 SnapshotStore 的JSON读取增加专用验证入口，默认继续调用原模型验证，原 canonical 字节相等、payload SHA、previous SHA链及写事务不变。Slot读取仅规范指定高俅/大名府场景所有权索引：类型、有限性、整数性及节点范围检查全部先于int转换；随后运行原完整Scenery验证。其他节点Codec、材质、芦苇、灯光、阴影记录和数值原样保留。

高俅只处理 entrance 和原七份归属列表；大名府只处理 walls/sprites/trees。原生写入端严格要求整数，不接受浮点索引。未知字段、跨章上下文/样式、无效索引和非法归属仍拒绝。旧六章及标准场景数据不做数值转换。Scenery原验证实现没有修改。

新增helper UID由固定Godot4.6.3实际生成，并核对已验收输入无碰撞。新helper及UID纳入下一批明确冻结清单；内容身份随源码变化重新计算，不能沿用旧源码身份。

## 必须完成的验收

- 用实际原失败payload通过完整Store envelope解码，逐UTF-8字节重现原文；带2.0的原不规范payload继续被拒绝。
- 高俅262、大名府196个指定路径精确转换；其他六章和标准场景保持完整数据不变。源数据与所有无关字段前后精确比较。
- 缺失/额外字段、跨章、非整数/非有限/越界索引、重复/遗漏归属、错误节点和父关系、灯光/材质/芦苇/阴影变异及恶意容器身份字段受控拒绝。
- 原OwnedSlot故障事务回归，证明通用hook与自定义文档模型的重试/归属/恢复行为保留。
- 重新执行大名府A真实半程保存退出、B独立Session安装并续办/再保存、C独立回读及真实tick不重放副作用。完整world外壳、所有section、Session选项/设置/根节点/上下文/本地binding和时钟边界都须检查。

此分支验收不代替自然结局与奖励一次、其他动态分支、同版九玩法/发行EXE、完整美术/UI流程、约10分钟正常时钟性能或Android真机。用户要求香港时间2026年10月8日06:00收尾同步GitHub，最终交接应据当时实际收据记录完成和未完成项。
