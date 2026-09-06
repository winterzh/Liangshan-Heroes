# 陨石与守卫恢复（2026-09-07）

第12个正式恢复组件 [run_meteor_wards_state.gd](../../scripts/run_meteor_wards_state.gd) 与受测原型原字节一致，SHA256 为 35d7ed60320167d1c72e840a2ce6193fe6ea3bba62abac319033a4bcc3636fa3。本批只新增 _meteor_zones、_wards 两个权威数组；连同此前三数组持续效果及四数组区域效果，已处理9/17个数组，既存视觉 Node 仍由外层恢复。

| 路径 | Run（UTC） | PID / exit | 检查数 |
| --- | --- | --- | --- |
| 原型 | [20260906T201655159599Z](runs/20260906T201655159599Z/report.json) | 40312 / 0 | 54：18 来源前后 + 36 其余 |
| 正式 | [20260906T201847036187Z](runs/20260906T201847036187Z/report.json) | 41376 / 0 | 同组54项 |

两轮均 complete=true、exit0，实际子进程退出确认、源码/玩家前后摘要一致且共同锁释放。实际命令末尾入口与 manifest 键/driver SHA 完全对应，报告与唯一 stdout JSON、实际 PID/user、manifest及报告SHA一致。正式路径重复同组检查，不新增场景计数。

## 身份与根事务边界

meteor 有序 hit 字典通过真实 run_graph_identity 目标域保存为 entity/retired token，再绑定为新正整数 ObjectID 键，保留顺序；不直接复制旧ID，不接受scalar/source-pool token。活着的已命中目标和退休命中目标均重新映射，解码碰撞或未知/重复token拒绝。三个可信身份回调和外层完整Unit集合先声明、验证、分配后再配置、绑定。

payload 保存源 _ward_serial，validate/instantiate 返回 required_ward_serial，bind 要求根 Battle 已恢复精确值，本模块不代写或递增。active aura_id 唯一且不超过serial；Unit已经持有的攻速/减伤来源池及离域宽限时间属于Unit层，不能靠重新施加守卫效果补造。任何 bind 失败都应丢弃整份私有事务：即使Battle数组未赋值，identity decoder也可能已分配墓碑。全图完成绑定后才由外层统一释放墓碑、安装和启用模拟。

## 实际续接检查

真实创建器先消耗初次陨石冲击/起手铺火、heal/attack/poison各一次脉冲及旗阵aura，再经真实JSON绑定新图；expired/none施法者保留其语义。Unit血量和已有来源池由夹具直接提供，避战且无inventory的真实Unit逐步调用原 _physics_process 执行TTL与降档，没有复制一套计时算法。

25组原 _zone_pass/_ward_pass 与真实Unit计时对照验证效果记录、血量、来源池和新地火数量。旧陨石目标不重复命中、新目标仅一次，地火沿剩余行进距离在第10/20步生成；守卫保留原脉冲相位。较强忠旗到期后降到仍存在的义旗，各来源再按原TTL清理；空数组不重授、不重复伤害/治疗/铺火。恢复serial后下一次真实建桩使用6，未重用旧1–5。

重复hit、未知ID、浮点serial、未知字段与根serial未恢复等被拒绝；缺墓碑不会部分写Battle数组。仅bind不造成伤害、脉冲、来源池刷新、地火或serial推进。后续原消费者确实创建真实FX，但这不证明保存时已经存在的视觉Node恢复。

## 视觉与未覆盖项

MeteorFx 还需 start_w/end_w、life、TimedFx t/dur、_roll、_embers及Node状态；WardFx 还需life、t/dur、style、lite、_ph及Node状态，style不能只由mode推导。外层不能调用_ready重新消耗视觉随机数来冒充原对象。既有GroundFire/Flameburst/BlinkShot及DOT也不由这两数组恢复。

[source_index.json](source_index.json)映射两轮所有源码、正式模块、driver/runner和固定helpers；当前Battle/Inventory复用UID+zone归档，旧Map/Unit/identity等按精确SHA引用既有原字节，不重复大文件。[原准备README](sources/scratchpad/run_meteor_wards_resume/README.md)中的“未运行”保留历史原文，实际结论以本层run收据为准。

在独立完整相容checkout按source index恢复缺失忽略路径；GDScript只去掉末尾.txt，Python保持原名，已有源码核对SHA、不覆盖。正式入口为 python scratchpad/run_meteor_wards_production_qa/run_smoke.py --godot "<实际 Godot 路径>"；不带 --run 仅预检，实际执行追加 --run，保持共同引擎锁、新私有用户目录和新run。不要直接运行归档文本。

[archive_manifest.json](archive_manifest.json)保存原始字节复制，[archive_verification.json](archive_verification.json)核对原文与依赖。没有PCK、私有profile、玩家内容、缓存、引擎、vendor DLL或资源二进制；完整checkout和生产资源仍是复现依赖。本批不证明全部17数组、既存视觉恢复、RNG隔离、一般未来实体分配、整局跨进程继续、菜单或PCK续玩；标准30波关卡适配的后续草稿不在本批，M3整局未完成。
