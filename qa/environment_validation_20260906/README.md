# 环境验证工具跨电脑 QA

2026-09-06。源码起点 `374b2ecdd4f1240202ed3c8c5cf21eb350682d37`，Windows、Python3.9.13、Pillow11.3.0、NumPy2.0.2、Godot4.6.3。代码与完整输入SHA见 [receipt.json](receipt.json)，生产字节基线单独保存在 `tools/contracts/environment/inventory_20260906.json`。

| 验证 | 结果 | 证据 |
|---|---|---|
| 全部环境目标静态路由、关卡/状态/路径、消费者证据 | 790项通过，退出0 | [router.json](router.json) |
| Godot真实资源解析、作用域、标牌和尺寸校准 | 794项通过，退出0 | [runtime.json](runtime.json)、[日志](runtime_console.log) |
| 隔离的复制checkout，缺文件/篡改/路径/资源删除/旧报告等反例 | 30项通过，退出0 | [selftest.json](selftest.json)、[日志](selftest_console.log) |
| 全69目标生产与来源审计 | 36现有PNG哈希吻合；33缺图；来源证据不完整，退出1 | [audit.json](audit.json) |
| 历史素材接入、normalizer完整自测及map-clamped来源验收 | 原件缺失，各退出2，0项执行，不算通过 | [legacy_status.json](legacy_status.json) |
| 已知原图查找 | 检查1,401张PNG头、计算84张候选哈希，4个已知原图SHA均未匹配 | [source_search.json](source_search.json) |

Godot首次干净导入退出0，未发现脚本或解析错误。本次没有改动生产PNG或运行时代码，不新增视觉、性能或真人体验结论。

审计的253项缺口包括33张目标图、69目标分别对应的原图/提示词/接入记录，以及13项历史输入。它是明确的准备与证据缺口列表，不表示曾丢失了253份已有文件。静态PASS只证明接线；不能用自测或运行路由PASS抵消来源失败。

自测在新临时目录复制必要源码、工具和36张生产图，不含Git目录或办公室目录，从其他cwd执行。所有删除、替换和路径攻击只发生在该目录；结束前核对恢复后的审计计数。map-clamped正向夹具使用明确标注的合成元数据，仅验证路径迁移及源码/哈希门禁，不作为实际来源记录。

第一次新增map-clamped正向夹具少写了原合同要求的 `steam_written: false` 和 `release_approved: false`，导致47/48。补齐夹具，保留合同要求，最终全部通过。失败输出保存在 [attempts](attempts/missing_fixture_flags.log)，不计入最终通过结果。

首次真实Git干净检出中，六条命令的退出码全部符合预期，27/28输入字节一致；`.gitattributes`自身被Windows转换为CRLF，收据因此正确判失败。为它也显式固定LF后重新检出验证。首次失败记录见 [换行失败收据](attempts/clean_checkout_line_endings.json)。

最终从提交 `f930cdb382d7b7f5583afb39c74af35df0d2539d` 新建干净Git检出：运行前无Godot缓存、无godot.local.txt，28/28收据输入逐字节匹配，从检出外cwd执行六条命令，退出码分别0/1/0/2/2/2，隔离自测30项通过；执行前后Git工作区都干净。见 [clean_checkout.json](clean_checkout.json)。随后的收尾提交仅补这份验收与文档，不改验证工具或生产输入。

复现命令与退出码见 [说明](../../docs/ENVIRONMENT_VALIDATION_PORTABILITY_20260906.md)。本目录历史文件不会被日常重跑覆盖；最终远端同步SHA以本任务实际回读为准。
