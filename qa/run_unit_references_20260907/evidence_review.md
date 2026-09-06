# Unit 引用适配器独立证据审阅

2026-09-07（Asia/Hong_Kong）。结论：修复后的实际引擎 QA 通过，有界独立复核未发现阻断项。仅新增本说明和 `current_qa_summary.json`；未运行引擎、修改受测源、读取私有 profile 内容或重新哈希大资源。正式 docs / qa 由根任务归档。

## 失败、定位与修复

| 实际运行（UTC ID） | 引擎 PID / exit | 结果 |
|---|---|---|
| `20260906T153930613198Z` | 11812 / 1 | 19 项检查，18 PASS、1 FAIL；失败为 `default values plus reference layer capture`。原报告未记录失败 code，不倒填诊断结果。 |
| `20260906T155758109217Z` | 39892 / 1 | 相同 19 项检查、相同失败标签；新增状态记录明确为 `CODEC_UNSUPPORTED_TYPE`、`$/key16`。适配器原始 SHA 与首轮一致。 |
| `20260906T160052202189Z` | 42344 / 0 | 162 PASS，0 FAIL；`complete=true`、`lock_released=true`，实际进程退出已确认，约 4.109 秒。 |

`unit_references.gd` 先插入 14 个直接引用与 2 个数组，随后用 dot 写入新的 `_queue` 键。诊断的 `key16` 与第 17 个顶层键相符；修复后真实引擎夹具证明空 Dictionary 的 dot 新键为 `TYPE_STRING_NAME`，原严格 codec 仍以 `UNSUPPORTED_TYPE`、`$/key0` 拒绝这种键。codec 在 `scripts/run_state_value_codec.gd:180–188` 逐键编码，未新增 StringName 支持。

修复仅涉及五处新键写入：`unit_references.gd:116/117/123/126/154` 的 `pos`、`group_cap`、`explicit`、`target`、`_queue` 改为 `result["..."]`。独立按这五处替换及一行说明重建源文件，字节完全一致；四文件统一差异也与 `fix_string_keys/changes.patch` 一致。候选、before 副本、seal、application receipt 与当前文件 SHA 全部对应。首轮封存与诊断封存的七份运行文件均与原件一致，失败历史保持失败。

QA 修复为纯增加，未删除或改写原行；此前诊断阶段也保留全部原断言行。四项新增回归均各执行一次并通过：真实 dot 新键类型、严格 codec 继续拒绝、默认引用输出递归 String 键、七种订单和引用标签递归 String 键（`qa_driver.gd:73/75/105/160`）。

## 数量与实际覆盖

逐行复算为 **162 = 12 个前后来源哈希检查 + 150 个其他检查**。150 包含辅助检查，不能称为 150 个独立行为用例。报告六组为 behavior 61、rejection 38、fixture 31、json 18、source 13、environment 1；source 的第 13 项是六文件清单形状检查。共有 117 个唯一标签；重复为真实 JSON parse 18 次、负例树 decode 15 次、encode 15 次。控制器要求的 12 个关键功能标签均恰好一次。

完整运行越过了原默认捕获失败点，并覆盖默认值、14 个直接引用逐项映射、两数组的顺序/重复/none/expired、有效零 HP 尸体、真实 free 的 Object Variant、七种订单及重复订单、Vector2/float/bool 类型、超出 JSON 安全整数范围的十进制 String ID、未登记/非法/重复 ID 拒绝、未知字段和订单拒绝、与冻结值层的组合拒绝、输出容器不别名、输入容器不变、混合捕获/JSON/校验不消耗 RNG，以及无 Unit death/story/appearance 信号。实际 Unit 只 `.new()`，不进入模拟树、不执行 setup、orders 或 physics。

## 来源、进程与隔离

有界独立复核共 102 项条件全部通过。复算三个 `sources.json` 的保存清单与 combined SHA，三代生产来源清单完全相同：2713 文件，combined SHA 为 `f12de07498b7074dd1c8fb0edf0bde9bdc5f0dfad5b95d850624b32e2a65fa20`。仅重新读取小型受测脚本/控制器/清单及封存证据，不重读 2713 个资源。全量运行前后守护成立的依据是冻结控制器的检查流程和本次 `source_unchanged=true` 收据；这不是审阅者再跑一次全量检查。

六项 runtime SHA 在 manifest、configuration、report、pins 及当前小文件间对应；控制器、生命周期 helper 和生产 guard 均与固定 SHA 对应。原 Unit、严格 codec、旧值适配器未改。成功报告 SHA 为 `77fd54681b80a8264b1bebb7fdb6aa4e121bfd8dd32d1cdb433c1cdfc030c377`。

报告 `OS.get_process_id()` 与外部 Popen 的 PID 42344 一致；非 console Godot 4.6.3 的 headless 单子进程退出为 0，无 timeout、清理异常、解码异常或严格日志错误。日志 SHA、manifest SHA 和报告 SHA 均独立复算对应。实际 `user://` 与 manifest/configuration 的本代 `private_profile` 子路径一致；控制器在启动前分别设置 APPDATA、LOCALAPPDATA、TEMP、TMP，拒绝 custom user directory 并持共同锁。真实玩家 settings/campaign/screen 的保存前后签名相同。审阅未打开这些玩家文件或私有 profile 内容。

## 仍然成立的边界

这里只完成结构运输与验证。`validate_record` / `validate_unit_record` 仍调用 `_registry`，要求调用者提供**实际有效 Unit 对象 → 稳定十进制 String ID** 注册表；不接受纯 ID 清单，不分配或持久化 ID。另建 Unit 壳使用相同 ID 的校验发生于同一 PID，未给壳写引用，不能视为跨进程恢复。

范围为 241 个声明值 + 14 个直接引用 + 2 个有序引用数组 + 1 个订单队列 = 258 个声明字段，另有继承的 position/modulate；9 个延期字段与 5 个视觉遗漏保持明确。重复/空槽能运输不代表驻军、矿工或完整引用图合法。metadata、业务定义、玩法 ObjectID 迁移、过期引用恢复政策、完整图验证、跨进程 ID 连续性和 Battle 续玩仍未完成。所有 `restore_ready` 仍为 false，生产未接入。

冻结 README、field contract、pins 的“未运行”标签是运行前历史，未为更新状态改动受测输入。实际结果以本次原始 report / receipt 及新增摘要为准；本审阅不宣称恢复能力、性能收益或生产验收。
