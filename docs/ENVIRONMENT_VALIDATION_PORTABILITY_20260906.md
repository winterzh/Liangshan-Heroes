# 环境美术验证跨电脑修复

2026-09-06，基线 `374b2ecdd4f1240202ed3c8c5cf21eb350682d37`。本批处理环境验证工具与证据清单，与江州关卡开发隔离；没有改变关卡、生产 PNG 或美术验收要求。

## 依据与实际缺口

当前 Git 历史不是浅克隆。已查询全部本地分支历史，并在项目、桌面、下载目录查找冻结清单；未找到原 `environment_batch_manifest.json`、`static_self_check.json` 和旧路由报告。仓库内生产映射模板仍在，其 SHA256 与历史说明一致，因此可以独立核对全部 64 个物件/覆盖层/旗帜状态及 5 个地表路由。

清单从**已提交 Git 对象**建立生产字节基线，而不是从待验证工作文件自动生成通过条件。69 个目标中，36 个 PNG 存在并匹配基线，33 个仍缺失。文档记录的四张地表原图，已对仓库 1,401 张 PNG 核对尺寸、对 84 张 1254×1254 候选计算哈希，没有匹配。原提示词文件名/哈希依赖缺失的批次清单，未自行编造。

这些结论只表示在已查范围未找到原件；办公室原目录尚未接入本机。完整来源验收仍不通过。

## 三层结果

| 层次 | 检查内容 | 当前状态 |
|---|---|---|
| 路由契约 | 独立映射的关卡、状态、目标路径、消费者源码证据；保留明确木墙复用规则 | 静态790项通过；Godot运行794项通过 |
| 生产字节 | 全69目标清单、现有文件哈希和尺寸、删除、额外文件、未经审核的新图 | 36现有文件匹配；另33目标缺图 |
| 原始来源 | 冻结批次、提示词、下载原图、接入记录及对应哈希 | 缺证据，整体退出码1，不计为通过 |

审计报告有253个逐项缺口：33个生产目标、69目标各3类来源记录，以及13项历史输入。数量包括尚未生产目标的来源准备项，不等同丢失了253个曾经存在的文件。每项都带目标ID/组件或原件名称；4张地表原图另带文档中的已知SHA。静态路由PASS的报告明确写出 `provenance_verified: false` 和 `resource_completeness_verified: false`。

## 跨电脑复现

Python 3.9及以上；整体审计需要 Pillow，旧素材接入工具及其自测另需 NumPy。已有工作环境中直接运行；缺依赖时可在自己的虚拟环境安装 `Pillow` 和 `numpy`。

在仓库根目录：

```powershell
python -X utf8 -B tools/campaign_environment_art_static_contract.py
python -X utf8 -B tools/environment_art_audit.py
python -X utf8 -B tools/environment_validation_selftest.py
```

也可从其他目录用脚本绝对路径执行，或给前两项传 `--repo <checkout>`。默认输出 `.godot/environment_validation/`，不会覆盖库内历史QA。`--report`/`--output`限定在所选repo的 `.godot/` 或 `scratchpad/`；收尾审核后再将必要报告复制到独立QA目录。

- 静态路由：0=契约通过，1=当前源码不符合契约，2=输入缺失/损坏/输出路径不合法。
- 整体审计：0=所有层次完整，1=缺素材/来源证据，2=哈希漂移、错误路由、非法输入等。**当前预期退出1，不能按成功处理。**
- 隔离自测：验证工具自身能接受正确夹具、拒绝错误输入；它通过不代表生产来源通过。map-clamped正向测试使用明确标注的临时伪造元数据，仅验证路径解析与拒绝行为，不作为原画来源证据。

Godot验证使用 `godot.local.txt`、`GODOT_PATH`或现有路径解析器定位本机Godot4.6.3。首次先完成导入，然后：

```powershell
$env:ENVIRONMENT_QA_REPORT='res://.godot/environment_validation/runtime.json'
& $godotExe --headless --path . --script res://tools/campaign_environment_art_runtime_contract.gd
```

`$godotExe`须先按 `SOURCE_SETUP.md` 配置；公共脚本无本机绝对路径。

## 保留历史门槛

`environment_web_art_intake.py` 和 normalizer 默认从 `tools/contracts/environment/legacy/` 找原冻结清单；仍保留原manifest、自检及九份提示词的精确SHA要求。两个旧自测在输入缺失时报告 `tests_executed: 0`、退出2；不是跳过后算通过。

`environment_map_clamped_contract.py` 缺安装证据时列出输入并退出2。恢复后会现场重跑完整当前路由检查，不再把旧“785项/65张缺失”计数当成当前事实。显式指定旧路由报告时，必须与当前源码哈希和断言记录匹配。

迁移绝对路径时用 `--evidence-map paths.json`。例如将历史 `C:/office/raw.png` 显式映射到 `qa/restored_sources/raw.png`；key必须与原证据中的字符串完全一致。所有目标必须留在仓库内，源图哈希、候选字节、RGBA尺寸、裁切/变换和来源字段检查仍执行，不能通过映射绕过。

## 验证与交付

本轮报告、自测、Godot运行结果及输入哈希保存在 [QA](../qa/environment_validation_20260906/README.md)。冻结输入通过 `.gitattributes` 保持精确字节；从 `f930cdb` 新建的无缓存干净检出已验证28/28输入哈希、30项隔离自测及六个入口的预期退出码，执行前后工作区干净。旧记录保留原样，并在相关说明中标明当前缺口。

后续恢复原件时逐文件审核并同步必要来源证据。不要把所有 QA/source 文件当缓存删除，也不要仅更新哈希以使工具变绿。角色四向、真人画面评价、性能和发行验收分别跟进。
