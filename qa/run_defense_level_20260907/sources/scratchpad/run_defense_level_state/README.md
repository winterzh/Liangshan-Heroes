# 标准驻守关卡恢复切片（已静态准备，尚未运行 Godot）

覆盖 `scripts/levels/skirmish.gd` 全部 12 个声明状态：10 个 VALUE_FIELDS（含完整 30 波 cache）、hall、_final_cleanup_positions。只接受已 started 的经典 30 波原表；未开始、随机/自定义/其他波数不在合同内。调用方注入可信 content_version 与固定 codec/标准 Level/Unit Script，不从存档动态 load，不读源 GDScript，不调用 `_waves`、`on_start`、`deploy` 或随机函数。

接口保留根草稿：`capture(level, version, object_to_id, encode_id)`；`validate(record, version, known_ids, validate_id)`；`restore(record, version, id_to_unit, validate_id, decode_id)` 返回新的真实 RefCounted Level。三个身份回调各接一个 Variant，encoder/decoder 返回 `{ok:true,value}`，validator 返回 `{ok:true}`。使用根共享身份图目标域（smoke 显式桥接 `_chase_last_id`），只接受 entity/retired。顺序为全图 declare/validate → UnitGraph.prepare → Level.restore → 全事务 release_tombstones → 根安装/激活。解码途中失败应丢弃整个私有身份事务。

本次修正：构造参数失效拒绝；身份回调先检查实际 Variant 类型；采样 token 结构、已知实体及编码/解码碰撞校验；未采样历史和倒计时边界拒绝；hall 在绑定时确认为 faction 0 的真实 hall 建筑。保留浮点原值、采样顺序；末波 active 启用后即使 quiet 因真实进展重置，也不擅自关闭。

## 实跑

在当前 checkout，以真实非 `_console` 的 Godot 4.6.3 引擎路径传参：

```powershell
python -X utf8 scratchpad/run_defense_level_state/run_smoke.py --godot $ActualGodotExe
python -X utf8 scratchpad/run_defense_level_state/run_smoke.py --godot $ActualGodotExe --run
```

第一条只读 preflight，第二条才启动一个 headless 进程。入口 `res://scratchpad/run_defense_level_state/driver.gd`，环境 `RUN_RESTORE_QA_MANIFEST`，suite `defense-level`，唯一 stdout 前缀 `[defense-level QA] `。pins 包含当前 100 个生产 GD/场景/project 和本目录两 GD，另验证路径集合完整性，不把上轮 99 当固定数量。runner 沿已实跑 item-respawn 生命周期：共同锁、私有 APPDATA/TEMP、完整源/真实玩家目录保护、真实非 console Popen PID 和退出确认、每 100ms 检查自有日志并在错误时中止、严格 Unicode/报告核对。固定 pins 与自身前后摘要，旧 utility/helper 路径与 SHA 保留；不创建新生命周期框架。失败不覆盖，输出位于 `runs/<UTC>/`。

## 真实夹具与边界

只初始化一个完整标准 Battle，暂停并禁用其自动 process。唯一源启动经 `_on_intro_done` 进入原 on_start，确认五工人真实采集，再给其中一人真实 Stop。原 level.process 消耗 17.25 秒，记录余 102.75 秒的 Level 与完整 Unit 图，实际 JSON。参考分支调用原 process 102.5 和 0.5 秒，真实生成六刀兵、三弓兵、一投石车及下一波 32 秒。UnitGraph.prepare 先创建真实离树、禁用、阻断信号的新 Unit；Level.restore 绑定新 hall。显式安装夹具才释放旧 Unit、连接真实 Battle died/story 回调、按原顺序入树并 activate。恢复不再调用 setup/spawn_at/deploy/on_start。原 Stop、全部 Unit 值/库存/引用与 Level 记录回捕应一致；同样推进后不能提前或重复出兵。

同一个 Battle/Map/Defs 容器保留，根 `_ai_spawn_serial` 在分支间按夹具保存值回设；检查地图 grid/block_count/revision 和金木不变。**这不证明 Battle 或 Map 已恢复。** 全局 RNG 未迁移也未重 seed；仅比较波次、计时、兵组数和向大厅攻击移动语义，不比较随机坐标/精确路径，不宣称自然重演 RNG。

末波明确设 `_wave=30`、`_wave_t=0` 作为分支前提，没有假称打完三十波。原 process 产生十个敌军采样、quiet=4、tick=1.25。采样间显式移除一个刀兵，以真实 spawn_unit 补同位置/血量单位，构造数量/总血相同、旧采样含一个真实已释放 ID 的边界；这不是击杀/奖励测试。JSON 新图安装后，quiet 要保持到剩余 tick 到点，再同原对照增长为 6；原消费者检测真实 40px 移动后归零。随后真实四拍到 8 秒才调用原 Battle.final_wave_cleanup，以敌军元数据观察调用效果。

不覆盖清剿生成坐标与 ObjectID 跨进程确定性、整局战斗、胜负/菜单、磁盘续局或 PCK。静态结果：声明字段 12/12、Python AST、默认只读 preflight 通过；预计正常分支 53 个功能/入口检查和 200 个源前后检查，此数量是待测预期。原 meteor/ward 和其他已验证文件未改。
