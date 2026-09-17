# 稳定实体图与驻守关卡 v2 桥接（2026-09-07）

仅本目录新增文件，不修改生产、原 identity/root-effects 冻结包，也不启动 Godot。`candidate/scripts/run_defense_level_state.gd` 逐字节复制既有 root-effects 候选，SHA256 为 `b7cbf96458669df3cf87cced4fa1c786e4f538e9d14aa276e27e30bc00331283`。本批不额外改其他 native target/source 域。

## 审查结论

此 v2 修复独立审查发现的断口：位置表键以稳定 ID 十进制文本序列化，恢复成原稳定整数，不再经过 ObjectID 映射。capture/validate/restore 第四参均为**已通过 Unit graph/root 验证的 next_entity_id**。运行前仍由外层安装 allocator、绑定真实关卡 RNG owner，完成所有图绑定后释放共享 native tombstone；未把这些职责藏进关卡组件。

旧 `standard_defense_level_v1` 明确拒绝。历史位置可能属于本次采样后已死亡的实体，因此小于 next 的正 ID 可以不在当前 live registry 中。next 是高水位，不是完整分配日志；本候选不能证明每个小于 next 的陌生键曾实际分配。不能把这种有界历史键称为严格 live 成员拒绝。等于/大于 next 的未分配键、非规范数字、旧 native token、重复位置键均须拒绝。

## 驱动范围

`bridge_smoke.gd` 延迟加载生产类，创建真实离树 Battle/GameMap/Unit 和标准 Skirmish；不进入 Battle._ready，不调用 deploy/on_start，不读取玩家槽。两次真实 JSON.stringify/parse 边界覆盖 Unit graph 与 level v2，同时保留原 root/active 顺序、>2^53 稳定 ID 和 next。

第一边界把一个敌人的 stable ID 故意设成另一真实 Unit 的 ObjectID。位置表必须仍属于该敌人；原生 `_lin_spear_target_id` 同时必须恢复成目标新 ObjectID。反例包括 v1、未知 live registry 上界、位置 key 等于 next/超过 int64/非规范格式/数字类型/原生 token/重复，以及 live capture 收到不匹配 Unit.entity_id 的注册表。历史大 ID 样本作为正例保留。

恢复后向目标安装 graph 提供的 next，所有 Unit 仍在离树真实父节点内、保持禁用。直接调用真实 Skirmish.process 与 Battle.final_wave_cleanup：第一拍识别超过 32 像素的移动，清除旧历史样本、归零 quiet；随后三拍继续按 2 秒采样，与未恢复的源局比较 stable 位置表、quiet、attack-move 路径及 stall。使用已激活的纠偏状态，**不声称测试 8 秒阈值 HUD 首次通知或真实自动物理帧**。固定 gameplay seed 5088120，检查没有新增随机调用。第二边界再捕获/验证已消费后的图与关卡；最后实际 spawn_unit 验证新出生领取精确 next 且只递增一次。

这不是磁盘槽事务、跨进程整个 Battle 续玩、模拟时钟、全局效果恢复、30 波或八关回归。驱动手工创建地图/fixture 身份是为了构造碰撞和 int64 边界，不是生产出生流程替代；只有末尾新增实体使用实际 allocator 出生入口。

## 准备与 QA 接手

```text
py -3.14 -X utf8 -B scratchpad/stabilization_defense_identity_bridge_20260907/prepare.py
```

该命令仅核对 24 identity 候选及对应生产 before、复制候选身份、2 个 GDScript 语法和 Python AST，输出本目录 source_receipt/static_review。它不创建测试工程、不运行引擎。语法通过不等于 Godot 类型或行为通过。

同时生成兼容 `tools/run_stabilization_overlay.py` 的 `overlay_manifest.json`（25 项均为已存在生产文件）及 `freeze.json`，精确绑定 manifest、driver、说明、准备脚本、静态记录和单文件候选。实际运行后不重写此冻结记录；修改须作为后续尝试保留旧证据。runner 参数：candidate 指向本目录、expected-files=25、driver=bridge_smoke.gd、driver-destination=tools/stabilization_defense_identity_bridge/bridge_smoke.gd、suite=defense-identity-bridge、prefix 为带尾空格的 `[defense identity bridge QA] `。source-head 与 freeze-sha256 使用根当次已核实的完整值；默认仅 preflight，由持槽者显式加 --run。

QA 从受控正式基线构造私有工程，按 source_receipt 的 25 个 overlay 逐文件覆盖；驱动复制到 `tools/stabilization_defense_identity_bridge/bridge_smoke.gd`。不得把本目录 .gdignore 复制到入口。保持正式工程 Autoload，SceneTree 入口会在初始化后延迟加载类。

```text
Godot --headless --path <独立工程> --script res://tools/stabilization_defense_identity_bridge/bridge_smoke.gd
```

`RUN_RESTORE_QA_MANIFEST` 指向全新外部 manifest，字段 run_id/private_user/report/source_sha256；private_user 必须是实际 Godot user_data_dir，source_sha256 覆盖全部已冻结工程加载依赖与实际驱动。suite 为 `defense-identity-bridge`，stdout 前缀 `[defense identity bridge QA] `。QA 宿主必须持独占槽，隔离 APPDATA/LOCALAPPDATA/TEMP/TMP，严格检查日志、真实 PID/退出、输入副本/生产/实际玩家目录前后以及最后锁释放；本驱动不自行取得槽或代替宿主守卫。

根须在本批实际原生行为通过后，才把同字节 defense v2 与 24 identity 候选一起接入；当前状态为 native pending。
