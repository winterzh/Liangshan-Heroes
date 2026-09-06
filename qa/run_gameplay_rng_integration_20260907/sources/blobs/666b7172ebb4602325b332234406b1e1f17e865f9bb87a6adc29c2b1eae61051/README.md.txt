# Unit / Projectile 玩法随机候选（未应用、未运行 Godot）

仅生成 `candidate_unit.gd`、`candidate_projectile.gd` 和 `unit_projectile.patch`，不自动改生产。`prepare.py` 固定两份来源 raw SHA，来源漂移即拒绝；每个受改方法记录 old/new SHA，并用逆向替换重建原始整文件逐字节比较。全部既有声明字段保持原字节，未改方法也逐方法比对。原文小备份仅在本目录 `.bin`。候选带原生产 class_name，只能由根整合到受控工程相应路径，不直接在同项目并行注册第二个 Unit/Projectile 类。

来源：Unit `2819b06d4f6266b6b16c3f4fbfd85ffc3f547546cc6c38c47db2367e076818cc`；Projectile `949d44303dbd8f31f958118f54be6980d2aeb22ef0eeafbac5ba9aa544e530b8`。没有重新锁定其他漂移版本。

## 接口与消费

Unit 新增五个无自有状态的转发/查询方法：`_gameplay_rng_fault()`、`_gameplay_draw_checked(...)`、`_gameplay_randf_checked()`、`_gameplay_randf_range_checked(lo:float,hi:float)`、`_gameplay_randi_range_checked(lo:int,hi:int)`。调用根 Battle 的对应 checked 方法，读取其已锁存 fault；无 Battle 的实际 draw 返回 `NO_BATTLE`，没有 global fallback。无 Battle 的纯非抽样计时/值夹具仍可用。有效 Battle 必须已经具备可信 provider、随机流与所有 checked 接口；缺接口时动作/物理入口停止。接口返回形状错误作为局部错误拒绝，不代造随机值；正常运行错误的持久锁存和暂停由 Battle checked 实现负责。

按原窄合同保留全部 12 个 Unit 玩法表达式的顺序和短路：

- 驻出仍先清驻军关系，再 world_to_cell、整型偏移抽取、nearest_open。抽取失败不假称还原已清关系。
- 醉酒 start 的 move/atk 两次，以及随后原 timer 到期的 move/atk 两次都保留；第二次失败时第一次已写值不回滚。
- 命中保持 miss → evasion → crit → 飞斧 → 伤害/物品事件 → bash → 近战吸血 → 猎骑吸血。miss 概率为 0 但计时有效仍抽；非建筑/资源 crit 概率为 0 仍抽。概率命中/落空及建筑、资源短路不预抽后续数。
- 已学飞斧且 proc_roll<0 才抽，chance=0 仍保留这次抽取；显式 proc_roll 不抽。
- `lifesteal_frac() -> Dictionary`，无随机分支也返回 `{ok:true,value}`。真实 Unit、Projectile 仅有的两调用点同步改为 checked，近战等级区间不变。

两处 Unit 尘土 global 调用和 Projectile.setup 三处旋转 global 调用保留；其所属完整方法未改。玩法流与旧全局流不承诺输出一致。没有新 Unit 或 Projectile 字段，未修改保存 schema。

## 故障边界

Unit `_physics_process`、`_phys_body` 入口和动作返回点看到 fault 即停止。`_deal_hit` 在飞斧、主伤害、on_hit、分裂、额外伤害后检查；`take_damage` 在 on_damaged/low_hp/on_death、林冲反刺的间接随机回调后检查；唯一冲锋伤害处也停后续本步。Battle 多目标/波次/技能循环与持久 fault 锁存由根迁移负责，不能靠本两文件认定全局传播闭合。

Projectile 通过仍有效的 shooter/target 查询所属 Battle。飞行前已有 fault 则停步；本次命中伤害之后发生 fault/吸血抽取失败，则 queue_free 并 return，禁止继续吸血、溅射或后续效果。入口还拒绝 queued deletion 的重入，避免帧末销毁前再次结算。先前扣血、已刷新计时、已清驻军关系、已追加冲锋命中等均不回滚；锁存错误的战局必须暂停、禁止保存并交根事务处理。

## 根后续最小实跑建议

与根的 Battle/关卡候选和可信身份 provider 一起应用后，用真实 RNG 同 seed 参考实例核对调用顺序及 state/calls；不要以伪造 RNG stub 的数值对照代替正式流。

1. 命中短路：盲目零抽、miss 概率 0/1、evasion 成功/失败、建筑跳过 crit/bash/cav；正常一击各条件只消费原有次数。显式飞斧 roll 零抽、chance=0 的默认 roll 一抽。
2. 醉酒立即两抽加下一步两抽；lifesteal 随机等级区间；插入 global 视觉随机后玩法 state/calls/后续值不变。
3. 用正式 RNG 支持的末次计数边界制造一次成功后耗尽；确认醉酒第二抽失败保留第一值、驻出失败不伪造关系回滚、命中前失败不造成新伤害、命中后吸血失败只保留已发生的命中且 Projectile 退出不重复。
4. 真实物品概率回调触发锁存：主伤害之后不再执行吸血/溅射/余下多目标；下一物理调用不递减 Unit/Projectile 计时。恢复同一 RNG JSON 后跨新进程续接由根共同 driver 核对。

当前只完成 Python AST、固定原文生成和字节逆向/字段/未改方法检查；不宣称引擎语法通过、行为通过、PCK 或整局恢复。额外 fault 查询、callv 参数 Array、checked Dictionary 的热路径开销尚未量化，不作 FPS 收益结论。
