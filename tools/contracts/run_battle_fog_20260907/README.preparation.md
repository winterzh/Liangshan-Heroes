# Battle 迷雾局部值草稿

2026-09-07。仅本 scratchpad 内实现 `fog_values.gd` 与真实对象 `qa_driver.gd`，生产源码、Unit refs、共享 controller 和正式 docs 均不修改。**尚未解析或运行 Godot**；本轮交付可供根任务独占运行的冻结源码和 QA 合同。当前完整续玩剩余字段见 `remaining_coverage.md`。

## 选择理由与字段

`Battle.fog/_vision/_sight_now/_reveal_t/_fog_t` 在 `scripts/battle.gd:173–180` 声明；`is_visible_world:3905`、`is_lit_world:3939`、`is_explored_world:3949` 直接使用这些值决定可见与探索状态。这不是可随意清空的绘图缓存。`_fog_pass:3971` 会减少倒计时、重算视野、减少临时侦察剩余时间、写纹理及 Unit 可见性，加载时重跑一次会改变状态。

本层显式保存这五个 Battle 值与实际 `Battle.map.w/h` 两维。地图在 `Battle._ready:294` 用 `level.map_w/map_h` 初始化；标准驻守返回 60×60（skirmish:112–113），黄泥岗为 48×40，祝家庄 RTS 为 64×56，大名府 RTS 为 60×66。60×60 只是本轮标准夹具，适配器没有硬编码所有地图为方形。

| 字段 | 严格形状 | 本层处理 |
|---|---|---|
| `map_w/map_h` | 两个原生 int；每轴 1..256，乘积 ≤4096 | 从真实 GameMap 读取；先验证两轴再乘法；验证时还要与调用方另给的 Vector2i 精确相等 |
| `fog` | bool | false 时允许三份空数组；已分配的完整数组在 false 时仍保留 |
| `_vision` | PackedByteArray，值只许 0/1/2 | 在长度和位域检查之后转为 codec 的整数 Array；解码检查之后才重建 PackedByteArray |
| `_sight_now` | PackedByteArray，值只许 0/1 | 同上，保留逐格行序，不能先转换而截断 -1/256/float/bool |
| `_reveal_t` | PackedFloat32Array，有限且 ≥0 | 用 c8c4 codec 的 packed_f32 字节形式，保留负零、次正规数及原 float32 舍入 |
| `_fog_t` | 原生 float64，有限且 0..0.18（两端含） | 这是迷雾刷新倒计时相位；按完整回调边界取样，不重置、不转 float32；负零保留 |

启用 fog 时三数组必须全部为 w×h；禁用且未初始化时三者可以全部为空，部分空/错长一律拒绝。本模块拒绝回调中途的负 `_fog_t`，不自行等一帧或推进模拟“修好”它；快照屏障仍由上层实现。4096 格是本模块明确预算，不是地图系统上限，超出就拒绝，不截断、不缩图。

数组宽度验证在遍历/转换前完成。整个七字段树只调用一次 codec encode/decode，不能逐字段重置总预算。以冻结 codec 的收费规则静态计算，4096 格合法记录为 12,303 个节点、约 820,910 字节保守 JSON 预算，低于原 32,768 节点和 1 MiB；实际最大格数正例仍须真实引擎验证。

## 接口

```gdscript
# Autoload/全局类就绪后，由可信调用方加载固定 GDScript。
var adapter = fog_adapter_script.new(battle_script, map_script, value_codec_script)
var captured = adapter.capture_values(actual_battle, expected_content_fingerprint)
var checked = adapter.validate_record(parsed_record, expected_content_fingerprint, expected_map_dimensions)
```

最后一个参数必须由外层已验证地图合同提供，不能直接拿待验记录自己的宽高冒充期望值。主体和 map 要是精确固定脚本的有效对象，拒绝待删除节点；读取 map 时保持 Variant，先判有效，再访问维度。构造时按 LF 源码摘要核对 Battle/Map/codec；原始 raw/LF/bytes 在 pins.json，内容指纹只作调用方合同的传入与比对。

record 精确字段为 `schema,battle_source_lf,map_source_lf,content_fingerprint,values`；value tree 精确包含上表七项。validate 返回独立的原生值缓冲，不写回 Battle，不返回 Node。所有成功/失败均保留 `restore_ready=false`；失败没有半份 values/record。

这五值的局部结构完整，不表示完整 Battle/Map 或跨字段业务一致。`_vision`、实时视野、临时揭示和 Unit.fog_visible 仍须整局屏障及引用图验明；这里不根据当前单位重算或自动纠正。`lit_cells` 是单独高亮倒计时，未混入本模块。Image、ImageTexture、FogLayer 需后续纯绘图构建，不能保存对象；本层没有赋值恢复、绘图重建、Unit 可见性重整、RNG/时钟恢复、磁盘或继续入口。

## QA 合同与运行交接

QA 延迟加载真实 Battle/Map 与 codec；`.new()` 后只在树外布置已知字段，不调用 `_ready/_init_fog/_fog_pass/init_map/bake`。默认 disabled/空数组、标准 60×60、非方形 7×3、4096 格边界均经过真实 JSON.stringify/parse。核对完整原生类型、行序、byte 域、float32 负零/最小次正规/0.1 舍入/16777217 舍入/最大有限值，以及 float64 相位位值；不消费额外 RNG、不别名源缓冲。六个代表格还与原 Battle 只读可见/明亮/探索查询对照。

负例包含 wrapper/schema/来源/内容指纹、独立期望尺寸、类型/轴/乘积预算、短长错位数组、非法 byte 转换、错误 packed 类型、相位边界、普通 NaN/INF、未知 Object tag、递归编码、codec 节点预算、错误/已释放主体、已释放 typed Map 引用。待删除节点的拒绝有代码检查，本批尚未安排运行此额外边界；不得写成已测。report 的 check_groups 区分 behavior/rejection/json/fixture/source/environment，不预填实测数量。

本目录没有 runner。根任务复用已经增强的共享锁、实际非 console exe/子进程句柄、源文件与玩家保护、严格 Unicode/Parse Error/ERROR/WARNING/FAIL 日志检查。独占并设新私有 APPDATA/LOCALAPPDATA/TEMP/TMP 后，入口为 `--headless --path <checkout> --script res://scratchpad/run_battle_fog_state/qa_driver.gd`。设置 `BATTLE_FOG_QA_MANIFEST`，指向新 `scratchpad/run_battle_fog_state/runs/<run_id>/manifest.json`；格式与 Unit refs 相同，含 `run_id,run_dir,private_user,report,source_sha256`。private_user 要在该 run 的 private_profile 内，report 必须是尚不存在的 run/report.json。GD 校对实际 `OS.get_user_data_dir()`、manifest 原字节 SHA 与五源前后摘要，不接受未隔离或旧报告。

外部须核对 run_id、manifest SHA、PID、实际 user 目录、五份 runtime raw SHA、stdout 唯一报告标记、非空完整检查/分组、exit、来源前后相同及最终锁。source 分组含 10 条逐文件 before/after、1 条精确来源集合、1 条来源聚合和1条 manifest 不变检查，不把来源或 fixture/json 辅助断言算成独立功能案例。report 单独选择归档，不复制私有 profile。默认准备期无任何引擎结果；实际检查数、日志和来源后续写入新收据，不能回写本次 preparation。
