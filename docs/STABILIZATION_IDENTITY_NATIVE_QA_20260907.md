# 稳定实体身份候选原生 QA（2026-09-07）

隔离的 24 文件候选通过一次新的 Godot 原生验收：86 项行为检查、1 项实际私有目录检查、2875 个受测文件各做前后 SHA 检查（5750 项），共 5837 项通过，零失败。它仍是候选，未覆盖生产；没有验证或实现玩家“继续本局”入口。

## 实际受测输入与边界

- 当前实际检出提交：`925d03fc8e62bf7287efcbf5044820e185c9f5f3`。2873 个生产路径按 Git 白名单从当前工作区复制原始字节，并逐项保存原始 SHA、Git blob ID。全部 24 项候选覆盖前 SHA 与其冻结收据精确匹配。
- 候选目录：`scratchpad/stabilization_identity_20260907`；源码收据 SHA256 `9b55e9ebe583eb1a83a559bc27d873adc71fc0dc5c3f8dce4974caeebf37f24f`，补丁 SHA256 `40ce475bf0c1125db3cd691de9c52456c0f353b8a663382fddae02a02e155072`。
- 通过版本的原始 `freeze.json` SHA256：`76ebd52649c873994bc9fdbe03ec0c280570502059eaf6a9357e90a2ecb6a0a2`；driver SHA256：`770ce846142918c8542b4efb7a765eeac9abe6a7080937c3905c6aaada0efb11`。
- Godot 4.6.3，二进制 SHA256 `ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00`。全新私有工程，先 headless import，再 headless 运行 `res://tools/stabilization_identity/identity_smoke.gd`。
- 使用共同 Godot 锁与短新 APPDATA/LOCALAPPDATA/TEMP/TMP，Steam 禁用。运行报告实测的 PID、用户目录、run_id、完整 source manifest 必须与宿主一致；源码、玩家、私有受测文件、冻结候选前后均核对，未触碰真实玩家文件。

通过尝试为 `identity_20260907T062049Z_2c1a100c`。import PID 1764，exit 0，16.98 秒；测试 PID 33492，exit 0，7.44 秒。原生日志无脚本错误、警告或泄漏，`complete=true`，四类前后守卫均 true，退出后无 Godot，锁已释放。实际执行源码快照与收据哈希一同保留。

## 行为检查实际覆盖

真实离树 Battle、GameMap、Unit 图验证根顺序与 active 顺序独立保存、死亡动画对象、重复/失效引用、typed tombstone、原生 target/source token 重映射、物品 UID、全部显式 Unit 值字段、先完整验证再构造、暂停激活与无部署回调。

真实 Battle 出生与 allocator 验证正数单调 ID、不重用已释放 ID、int64 最后可分配值和耗尽哨兵、失败不发布新节点、故障后 RNG/graph 捕获拒绝。江州替换、敌军补兵退款、连环马演练重建、野猪林解缚、高俅交接、arena/scenario 波次容量、清场重部署和付费生产失败，采用明确拒绝创建的测试替身调用真实关卡/Unit 消费路径。

上述失败检查不代表所有真实关卡的正常成功流程已跑完，也不证明整个任务原地事务回滚。Battle 未执行 `_ready`，没有进行完整经济/特效/根状态恢复、模拟时钟、跨进程 Battle、存档磁盘、菜单、PCK 或真人验收。报告明确 `battle_resume_tested=false`。首版标准 30 波、之后祝家庄与其余关卡的续玩路线，仍需继续开发和单独终验。

## 首次失败与工具修正

首次尝试 `identity_20260907T061258Z_551411d4` 的 import 成功，CLI 测试入口提前加载带 GameMap/Unit 类型的测试替身，导致真实脚本编译时 `Art` / `Sfx` Autoload 名称不可见，随后出现无效构造错误。QA 用完整私有工程命令行核实本次 PID 40616 后仅终止该异常进程；宿主确认 exit 1、全部守卫通过、无存留进程、锁释放。

候选负责人只修改测试 driver：Graph 延迟动态加载，测试替身的真实游戏类签名改为 Variant。24 个候选覆盖文件和候选补丁未变。第二次使用新的 freeze 与新私有工程运行，通过后保留两个尝试，未覆盖失败记录。

宿主 runner 现在在发现原生错误日志时只终止自身创建的进程并记录原因，避免异常脚本留在循环中；完成码在全部 finally 守卫之后决定。通过尝试的 `freeze.json` 曾由宿主重新序列化，字段相同但原始文件 SHA 不同。归档的 `frozen_candidate_inputs/freeze.json` 是负责人原始字节，精确匹配收据中批准的 SHA；当前 runner 已改为直接复制原始字节。没有改写通过尝试的原收据或冒称重新运行。

## 归档与运行入口

`qa/stabilization_identity_20260907/` 保存两个尝试的原始日志、报告、manifest、收据、实际执行工具、准确受测的 24 文件与 driver、完整冻结候选输入。`archive_manifest.json` 对这些文件逐字节记录 SHA；不包含私有玩家目录、Godot 缓存或完整生产项目副本。`summary.json` 分开记录 86 项行为和 5750 项哈希检查，不能把后者计成游戏场景数量。

```text
py -3 -B tools/run_stabilization_identity.py --source-head <完整当前HEAD> --freeze-sha256 <负责人新冻结SHA> --run
```

不传 `--run` 为只读预检。默认候选路径与 profile 根目录可通过参数指定，Godot 路径读取被忽略的 `godot.local.txt`。每次运行都创建新工程与新 profile；不复用历史 PASS，不运行旧 `run_smoke`，不覆盖生产。

本次由 QA 所有者新增的交付白名单是 `tools/run_stabilization_identity.py`、本说明及 `qa/stabilization_identity_20260907/`。候选业务文件与其后续说明由候选负责人管理。公共交接文档和 Git 收尾由主任务统一处理。
