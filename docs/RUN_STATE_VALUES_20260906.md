# 续玩基础：显式值 codec（2026-09-06）

`scripts/run_state_value_codec.gd` 是供未来显式 Battle/Unit 字段适配器调用的小型值编码模块。它没有生产 Battle 调用方，不扫描 Node 属性，不 dump 对象，也没有实现完整实体 schema 或恢复战斗。模块原文 raw SHA 为 `c8c4a58d1e68e22abb9f8b1abcb1a9cc1dbaa486e51ea5174dd16984aaa35d15`；晋级逐字节复制 12,091 字节已受测源码，仅更换文件路径。

## 接口与格式

`encode(value)` / `decode(tagged)` 返回明确的成功值或错误 code/path，失败不返回部分解码结果。支持 null、bool、String、int64、有限 float、Vector2、Vector2i、Color、Array、按实际迭代顺序排列的 Dictionary entries 和 PackedFloat32Array。每个标签的字段集合和数值类型严格匹配；未知标签、额外字段、重复解码键、Object/Callable/Resource 均拒绝，不调用用户对象方法。

int64 使用规范十进制字符串并逐位负向累加，覆盖 −2^63 至 2^63−1；`2^53+1` 不经过 JSON 数字/float。有限浮点使用确定的 hex 字节字符串，保留 f64 的 −0 和 float32 量化；Vector2 构建后逐位复核目标精度，不能无声舍入。普通标签树不含 JSON 数值，避免 JSON 解析器把整数统一转成 float 的影响。Color 保留有限 HDR 值。INF 只通过独立 `encode_infinity` / `decode_infinity` 显式处理，普通递归路径仍拒绝 NaN/±INF。

上限为根深度 0 至 32、32,768 个计费节点、1 MiB compact JSON 字节的保守上界。遍历/分配前检查容器尺寸，按祖先引用身份拒绝环；不会先 stringify 任意巨大/循环对象再检查。预算是每次调用的值树预算，上层仍需整个快照的累计上限。

typed Array/Dictionary 约束、只读标志和共享容器身份未编码；适配器须明确重新构建需要的字段类型。引用的 none/entity/expired 不由本层解释。`decode` 接收已解析的标签 Variant，JSON 原文的语法、NUL、重复 object 成员和解析前字节上限仍须上层负责；输入到达前已替换或折叠的信息无法由本模块恢复。

## QA 与原始诊断

真实结果以 [current_qa_summary.json](../qa/run_state_values_20260906/current_qa_summary.json) 及其指定原始 report/log/receipt 为准。当前验收是 Godot 4.6.3 的 `20260906T143634734025Z`：341 个非空检查全部通过、失败清单为空、exit=0、实际 PID 13904，原始日志无 Unicode/Parse Error 或其它规定诊断。独立复核确认 stdout 与文件报告相同、三份来源和报告摘要匹配、实际 user:// 位于本轮私有 profile；控制器收据确认精确进程退出、来源未变与共同锁释放。

正例经过 encode → JSON.stringify → JSON.parse → decode，核对类型、浮点位、字典迭代顺序及再次编码。包含 int64 两极和 ±(2^53+1)、f64/f32 已知位 oracle、−0/subnormal、向量键、重复键、有界嵌套/循环/节点/字节限制和非法标签/Object 拒绝。三文件私有项目没有 Autoload 或生产资源。循环及恶意 Object 的拒绝例直接进入有界 codec，避免在检查前对它们 stringify；不把这些拒绝例写成已做 JSON 中转。

原 `20260906T114114538519Z` 的报告为 340 检查通过、exit=0，但日志第 3 行有 `Unicode parsing error ... Unexpected NUL character`，最初启动器的前缀匹配未识别。独立审阅因此拒绝将这一轮当作无诊断验收，原收据和旧驱动字节保留。错误来自 QA 在 encode 之前调用 String.chr(0)，不是 codec 执行对象/文件操作；原 NUL 假正例无法证明字符保真。

修复只把该输入改为 Godot 支持的中文/换行/tab/CR/引号/反斜杠/emoji，并在 encode 前增加独立 UTF-8 字节 oracle。codec 原文未改；新的驱动 raw SHA 为 `d555a5032ec967eb1996dc0f005ea32d21e91cef655afc01a40bcea5062be202`。上述 341 检查的新轮已采用同时识别 Unicode parsing error/Parse Error 的严格日志检查；旧 340 轮未回写，不声称原始 NUL 已支持。

三文件源码、原名映射和复现边界见 [tools/contracts/run_state_values_20260906](../tools/contracts/run_state_values_20260906/README.md)。封存 GD/配置均为文本，恢复到一个全新、被忽略的私有项目后才运行，不从生产场景打开 QA，不新建公共 runner，不复制玩家/profile/cache。

## 下一层工作

需要另行实现受支持战斗阶段的显式字段白名单、完整内容兼容验证、稳定实体 ID/引用图、RNG/定时器/队列、快照屏障与场景重建。完整验证必须在创建场景前完成，并以独立进程真实战斗恢复检查为证。这里的可复用值模块尚不能开放保存/继续入口，也不等于已经接通磁盘草稿或恢复决策。
