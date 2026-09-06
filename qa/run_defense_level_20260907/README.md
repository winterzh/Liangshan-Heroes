# 标准30波驻守 Level 与 Unit 图安装（2026-09-07）

第13个正式恢复组件 [run_defense_level_state.gd](../../scripts/run_defense_level_state.gd) 与受测原型原字节一致，SHA256 为 5cb83ac01cddcdab0865434caa5e0de5ec8e5d1f28a746c657dc745e7ca4aa91。它覆盖标准skirmish关卡的12个声明状态（10个值字段、hall引用和末波采样身份），只接受已启动的经典30波原表。未开始、随机/自定义关卡或其他波数在此合同之外。

| 路径 | Run（UTC） | PID / exit | 检查 |
| --- | --- | --- | --- |
| 原型 | [20260906T203250821538Z](runs/20260906T203250821538Z/report.json) | 37800 / 0 | 253：200 来源前后 + 53 功能/入口 |
| 正式 | [20260906T204006999300Z](runs/20260906T204006999300Z/report.json) | 34732 / 0 | 同组253项 |

两轮各自100个运行源码均有精确映射。报告与唯一stdout JSON、实际PID/user、manifest和报告SHA一致，执行命令末尾入口被manifest准确覆盖；complete、source_unchanged、player_unchanged、lock_released均true，exit0且实际子进程退出确认。正式路径重验原矩阵，不增加独立场景。

## 实际首波与新图安装

每轮只创建一个完整标准Battle，暂停并禁用其自动process；唯一原始启动通过_on_intro_done进入on_start，五名工人的采集命令实际下达后，给其中一人真实Stop。原level.process推进17.25秒后保存剩余102.75秒和完整真实Unit图，经真实JSON运输。参考分支再推进102.5+0.5秒，实际生成六刀兵、三弓兵、一投石车及下一波32秒。

UnitGraph.prepare创建全新树外禁用Unit，Level.restore通过同一尚未释放墓碑的identity绑定新hall；外层夹具才释放旧Unit、连接真实died/story回调并按保存顺序挂接/激活。恢复过程不调用setup/spawn_at/deploy/on_start/_waves；已保存Stop不会被重新下达采集覆盖。完整Unit值/库存/引用与Level记录回捕一致，复推进首波计时不提前、不重复出兵。

## 末波采样与真实清剿

末波分支显式设置_wave=30和_wave_t=0作为夹具前提，没有实际打完30波。原process获得十个敌军采样、quiet=4和剩余tick=1.25；显式移除一名敌军，再用真实spawn_unit生成同位置/血量替代对象，构造数量/总血不变但旧采样含一个已释放ID的边界。这不是击杀、奖励或跨进程ObjectID确定性检查。

第二次完整Unit图和新Level安装保留九个entity及一个retired采样token；quiet保持至原剩余tick到点，再与参考分支同样增至6。随后原消费者检测实际40px移动并归零；再经真实四拍累积到8秒才调用原Battle.final_wave_cleanup，敌军元数据证明执行效果，6秒时不提前清剿。

## 事务边界与来源

构造注入固定codec/标准Level/Unit Script和可信内容版本，不从存档动态load或读取原始GD。身份回调复用完整共享目标域，只接受entity/retired，验证回调结果类型、未知/重复ID与解码碰撞。全图先declare/validate，再UnitGraph.prepare、Level.restore，所有系统绑定后统一释放墓碑并安装/启用。任何解码途中失败都应丢弃私有identity上下文，不能复用半完成事务。

这两次安装始终复用同一个Battle/Map/Defs容器，金木、地图grid/block_count/revision保持；根_ai_spawn_serial在对照分支间按夹具保存值回设。因此本批证明Level与完整Unit图接续，不能说Battle或地图已恢复。全局RNG未迁移/重seed，只比较兵组、波次、计时和攻击移动意图，不比较随机出兵坐标或精确路径。

[source_index.json](source_index.json)映射两轮各100个源码、模块、driver/runner/pins、准备原文和promote_defense_level.py；相同既有QA源按SHA复用，不重复大Battle/Map。原准备README/preparation/pins的未运行状态不改写，本层实际结果仅由原始run收据证明。晋级脚本只是来源记录，归档过程没有执行它。

正式pins的driver字节数描述仍为原型22,071，实际正式driver因路径替换缩短为22,056；其raw SHA、运行manifest、报告和runner固定pins身份全部正确。归档原样保留该陈旧描述，在source index使用实际22,056并单列差异；不把正确的运行证据改写为失败，也不回写原始pins/收据。

独立完整相容checkout按source index恢复缺失忽略路径，GD/场景文本只去掉末尾.txt，Python保留原名，已有源码先核对SHA而不覆盖。正式入口 python scratchpad/run_defense_level_production_qa/run_smoke.py --godot "<实际 Godot 路径>"；不带--run只预检，实际执行追加--run，遵守共同引擎锁、新私有用户目录与新run。固定引擎/辅助模块沿原收据，完整生产资源仍依赖匹配checkout。

[archive_manifest.json](archive_manifest.json)列原始字节副本；[archive_verification.json](archive_verification.json)核对副本、精确复用依赖及生成摘要。没有私有profile、玩家内容、缓存、PCK、安装包、引擎或vendor DLL。未覆盖Battle/地图/全部效果与视觉整体恢复、退出重启、战役胜负、菜单/磁盘/PCK续玩；本批不包含尚未运行的施法流程候选或后续RNG身份工作，M3整局未完成。
