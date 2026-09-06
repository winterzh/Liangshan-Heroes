# 技能走近、抬手与引导恢复（2026-09-07）

第14个正式恢复组件 [run_cast_flow_state.gd](../../scripts/run_cast_flow_state.gd) 与原候选同字节：15,409 bytes，SHA256 127a230696570b50207fd06a3c4e7a4f33dad7bb24d33a333e4d136343976587。覆盖 _walk_casts/_pending_casts/_channels，权威效果数组累计12/17。首轮真实消费者失败促成同批 Battle 窄修复；原失败证据没有覆盖。

| 运行 | Run（UTC） | PID / exit | 结果 |
| --- | --- | --- | --- |
| 原型原生产 | [20260906T204913855863Z](runs/20260906T204913855863Z/receipt.json) | 40952 / 1 | complete=false；严格日志捕获运行错误，无 report.json |
| 相同 driver + 生产修复 R1 | [20260906T205452854069Z](runs/20260906T205452854069Z/report.json) | 23352 / 0 | 63项：32来源前后 + 31功能/宿主 |
| 正式资源路径 | [20260906T205651467321Z](runs/20260906T205651467321Z/report.json) | 32308 / 0 | 同组63项通过 |

三轮各16个运行来源精确映射，实际命令末尾入口在各自 manifest 中；两轮通过报告与唯一 stdout JSON、PID/user、来源及 report SHA 一致。三轮 source_unchanged/player_unchanged/lock_released 均 true，子进程退出有原始回执；失败轮不能据此改为通过。正式重验同矩阵，不新增独立场景。

## 真实生产缺口及最小修复

旧 Battle SHA 为 d88caffd78a8530a79521262199a7ce116b2d0f5631c16cac136b6fa38552af5。首轮在原 _tick_pending_casts 中将 previously freed Object 传给 _do_ability 的第4个 Unit 参数，严格日志报类型错误，host 终止并保留 exit1；没有完整报告，不能推算失败前检查数。这不是夹具失败或 manifest 缺口。

原 target != null 条件可能把已释放 Object 当 null 而跳过实例有效性检查。修复后的 Battle SHA 为 47357265c54a8cd6c2a5fef24998e357773974843559c4e23965ea3e0d51b629：_tick_pending_casts 和 _walk_cast_pass 在 null 判断前先以 typeof==TYPE_OBJECT 且无效拒绝过期目标，pending 向 typed API 传已检查局部变量。三处编辑体现在原始 unified patch 的两个上下文 hunk 中。没有改变合法 point/null 目标、原 cooldown、寻路或施法逻辑，也未修物品的两个 consumer。

R1 driver 原字节 SHA 1cc55020ce467025e5d6ca78ac380ac3d42c07110355a39298c9b87fb94b1a35 与首轮完全一致；运行时只更换受测 Battle 和入口位置/对应指纹。正式 driver 仅替换模块 preload 资源路径。application.json、修复前 Battle 的精确映射、原 patch、prepare_cast_flow_runner.py / fix_expired_cast_target.py / promote_cast_flow.py 和各版 runner/pins 均保留。归档阶段只读比对，没有执行这些修改脚本。

## 保存合同与真实消费

walk保存 c/slot/tgt/point/serial/t/age；pending保存 caster/slot/lp/tgt/serial；channel保存 caster/center/eff/sc/rank/r/tick/tick_t/ad。eff/ad完整经有预算的codec保存，可选键缺失保持缺失，不填null或丢弃元数据。实际消费者字段及严格类型校验、有限值和int64序号保持；单体walk原Vector2.INF只在该哨兵字段编码为 unit_target 标记，点地用有限point。过期计时或stale serial保留给原consumer判定，不重置为新动作。

new(codec_script,battle_script,unit_script) 注入固定Script，capture/validate/instantiate/bind 使用可信content_version与稳定Unit ID；运行模块不读取源GD哈希或从存档动态load。bind只接受树外DISABLED、信号阻断、目标数组为空的真实Battle壳；先完整验证再一次赋值三数组，不重新施法、寻路、下命令、开始CD或运行消费者。

Unit自身 _cast_t/_cast_dur/_cast_serial、_channel_t/_channel_dur、ability_slots冷却、order serial/路径/队列/目标/控制状态由外层先精确恢复，required_unit_fields仅声明依赖，不证明完整Unit层已经恢复。expired引用先绑定外层identity提供的活类型墓碑，所有图绑定完成后统一释放，再安装/启用；不能先释放墓碑再继续绑定。

夹具采用真实Battle/Unit/GameMap/LevelBase/HUD空壳，不运行Battle._ready/deploy。两个QA能力数据走真实smite，channel用实际ling_zhen_q。真实creator先产生有余时的走近/抬手/引导及实际已释放目标/施法者；真实JSON→新对象映射→bind→释放墓碑→回捕一致。Unit局部值、原路径和可信能力定义由夹具直接供应，没有假称完整UnitGraph恢复。

25步原 _walk_cast_pass/_tick_pending_casts/_channel_pass 与真实Unit计时体对照：抬手第3步结算一次；显式位置到达后两个walk第7步结算一次；引导第4/8/12/16/20步再跳五次。真实order_move取消旧意图，apply_silence停止引导，过期目标不结算/不扣CD；空队列不会重复施放或修改路径。第3步到达位置是明确夹具安排，不是完整移动仿真。原/恢复后消费者新建FX数量一致，不等于保存时已有视觉Node恢复。

## 复现与边界

[source_index.json](source_index.json)为每轮历史来源单独保留路径和SHA；相同旧依赖按精确字节复用，不重复大Battle/Map。full sources/players before/after只是原始摘要；完整资源仍依赖相容checkout。本目录不含private_profile、玩家文件、cache、PCK、引擎、vendor DLL或安装包。原准备README/pins的未运行描述保持原文，实际结论看本层原始收据。

独立相容checkout按source index恢复缺失忽略路径，已有文件先核对而不覆盖；GD等文本归位时只去掉末尾.txt，Python保留原名。正式入口 python scratchpad/run_cast_flow_production_qa/run_smoke.py --godot "<实际Godot路径>"；不带--run仅预检，实际运行加--run，保持共同引擎锁、新私有用户目录和新run。正常游戏入口未变化。

[archive_manifest.json](archive_manifest.json)列原字节副本，[archive_verification.json](archive_verification.json)核对全部复制、复用依赖与生成摘要。未测试物品施法/其他效果、完整Unit/地图/Battle事务、既存视觉重建、一般未来实体分配、Battle RNG迁移/隔离、退出重启、菜单/磁盘/PCK续玩。物品候选与后续工作不在本批证据内；M3整局仍未完成。
