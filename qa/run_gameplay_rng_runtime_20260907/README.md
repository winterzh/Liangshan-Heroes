# 运行时玩法 RNG：源码与独立 PCK 验证（2026-09-07）

第9个正式恢复组件 [run_gameplay_rng.gd](../../scripts/run_gameplay_rng.gd) 与本批 runtime 原型同字节，SHA256 为 7705f9e054f3cf4e422623b280dea3bebc1ec4509f768ed8094078f0123d7e45。它使用独立原生随机流，构造时由外层注入可信 content_version；恢复继续核对引擎/平台及模块、codec 合同，按 seed 后 state 的原顺序恢复。运行时不再读取原始 .gd 文件哈希，兼容版本不能由存档自证。

| 阶段 | Run（UTC） | writer / reader PID | 结果 |
| --- | --- | --- | --- |
| 源码模式 | [20260906T193936497244Z](runs/20260906T193936497244Z/receipt.json) | 7728 / 36120 | 161 + 47 = 208 项，均 exit 0 |
| 原 PCK | [20260906T194037811287Z](runs/20260906T194037811287Z/receipt.json) | 29188 / 未启动 | 导出 exit 0，writer exit 2，整轮失败 |
| PCK R1 | [20260906T195011243688Z](runs/20260906T195011243688Z/receipt.json) | 20224 / 41908 | 24 + 33 = 57 项，均 exit 0 |
| 正式资源路径 PCK | [20260906T195239912542Z](runs/20260906T195239912542Z/receipt.json) | 1400 / 2596 | 同组 57 项，均 exit 0 |

成功轮报告与唯一 stdout JSON、实际PID、私有用户目录、manifest、handoff/报告SHA对应；源文件与玩家前后摘要一致，共同锁释放。PCK writer/reader 从空启动目录加载同一受哈希保护的独立夹具包，确认三份原始 .gd 文件不可直接读取而编译资源仍能加载。七种有符号种子各64个后续混合结果及最终状态匹配，且不受无关全局随机噪声影响；正式资源路径复验同一矩阵，不重复累计为新游戏场景。

## 原 PCK 失败与 R1

原 PCK 已写出24项全true的 writer_report，内部 complete/passed 也为true，但没有stdout报告，writer exit2、reader未启动。外层receipt的complete=false与pck_tested=false原文保留，不能把内部报告当整轮通过。

已定位旧 _write 在成功写出报告后、输出stdout前返回false；旧实现要求JSON复读后的原生Dictionary完全相等，没有观测到RNG判断失败。Engine元数据经JSON往返发生类型变化（例如StringName与String键差异）是可能解释，键类型未单独实测，不能确定为根因。R1只改_write为写入UTF-8字节、确认parse成功并逐字节复读一致，随后整轮通过；归档对比确认其余driver文本未变，RNG判断和宿主验证保持。[修正原文](sources/scratchpad/run_gameplay_rng_runtime/pck_r1_correction.json)保留旧/新driver与runner/pins SHA。

原失败包SHA为 b31d014c98b5a97739073c8e105b309133ee549775d9713d3a6a9565d8193203；R1为54a8ba8ec47e2adaa52c3ff4fd0cf1fd88259c6266672de65540d2b711f97042；正式路径为401c1dd1e28a488e39ef778b18ba9a2997e6970bc25b4b061c2a427c39d691d5。包本身不入档，哈希、导出进程和模板原文足以标识各自证据，复跑产生新包。

## 归档与复现

[source_index.json](source_index.json)映射模块、源码driver、旧/R1/正式PCK driver/runner/pins、导出模板、合同及精确helpers。相同旧RNG归档字节明确复用，不重复依赖。原准备pins/README/freeze_receipt的未运行状态不改写；实际结果单列。源模式私有project来自受测runner内的PROJECT字节常量；PCK私有源文件映射到模板，生成UID仅保留原摘要。

在独立完整相容checkout按source index恢复缺失忽略路径；GDScript、Godot模板只去掉最后.txt，Python保持原名，已有文件核对SHA而不覆盖。源码入口为 python scratchpad/run_gameplay_rng_runtime/run_qa.py --godot "<实际 Godot 路径>"；正式PCK入口为 python scratchpad/run_gameplay_rng_production_qa/run_pck.py --godot "<实际 Godot 路径>"。不带--run仅预检，实际执行追加--run，并遵守独占引擎、新私有用户目录及新run。不要直接运行归档文本或复用历史profile；固定引擎身份见原始receipt。

[archive_manifest.json](archive_manifest.json)保存原字节复制，验证见[archive_verification.json](archive_verification.json)。归档不含PCK、私有project/profile、玩家文件内容、缓存、引擎或vendor DLL；handoff是纯QA合成数据。仅按已完成run的源前后收据记录历史，不将后续Battle/Inventory UID工作混入。

本批没有迁移Battle的全局随机调用，没有接通RunSession、整局跨进程持续战斗、菜单继续或整游戏PCK续玩。独立夹具PCK加载与随机流续接通过，不代表M3整局或线上Steam版本已完成。
