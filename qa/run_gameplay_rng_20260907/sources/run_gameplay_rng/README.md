# 独立玩法 RNG 准备

状态：仅 scratchpad 源码与两进程 QA 合同已准备；未运行 Godot、未通过解析或运行验证。没有生产调用方，没有修改 Autoload，也没有迁移原全局随机流。

`gameplay_rng.gd` 使用一个自有 `RandomNumberGenerator` 实例，提供 `start`、`capture`、`validate_record`、`restore` 和四个 `draw_*` API。正常结果为 `{ok:true, code:"OK", value:...}`；capture 用 `record`，validate 用解码后的 `value`。start/restore 成功没有 draw value。拒绝返回 `{ok:false, code:...}`，不替换旧实例、不推进旧 state 或计数。

## 数据与兼容合同

整份 checkpoint 是 c8c4 value codec 的有界 tagged 值树，原生字段恰好为 `kind/version/compat/seed/state/calls`。seed/state/calls 全部用 `int64` 的十进制字符串 tag 穿过真实 JSON，没有经 JSON 数值或 float 解析。version 为 codec 保持的整数 1；kind 为 `godot-gameplay-rng`。

- seed 接受 GDScript signed int64 全域，包含负种子、MIN/MAX、±(2^53+1)。原生读回不一致会拒绝。负值使用绑定层的有符号表示，不把它改成正的 uint64 JSON 数字。
- state 也按 signed int64 运输。只能保存并恢复实际 `RandomNumberGenerator.state` 取得的状态；shape/domain 验证无法证明某个整数的历史来源，不能把本模块当作存档签名或可信来源验证。QA 的 state MIN/MAX 只测 codec 运输；实际恢复使用原生捕获的 state，并要求至少有一个实际负 state。
- restore 先校验全部字段、版本与兼容身份，再新建临时实例，依次赋 seed、state，读回一致后才提交。先设 state 再设 seed 会破坏续接；重新用 seed 跑固定次数也不是本模块的恢复算法。
- calls 只计成功公共 API 调用，不计 PCG 内部步骤。相等整数端点仍计 1；非法调用计 0。MAX_INT64 可运输但下一次任一 draw 拒绝，防止溢出。计数不是防篡改凭据。
- randi 返回原生 unsigned32 结果在 GDScript int 中的 0..4294967295；randi_range 要求两个 TYPE_INT，均在 signed32 范围，允许反向及相同端点，并直接调用原生接口。
- randf 返回原生接口结果。randf_range 明确要求两个 TYPE_FLOAT、有限且绝对值不超过 1e30，以避开 real_t=float32 的中间溢出；允许反向及相同端点。这个窄域涵盖已查主路径，现有整数文字端点迁移时改为浮点文字，不静默截断/夹紧。无 NaN/INF 哨兵、randomize、randfn、weighted、shuffle API。
- compat 恰好含 `engine_binary_sha256/engine_version/engine_hash/os/real_t_bits/module_sha256/codec_sha256`。脚本与 codec 真实 raw SHA 在运行时读取，codec 必须是 c8c4。real_t_bits 用可区分 float32/64 的 Vector2 存储值探测。主机必须独立确认实际运行的非 console Godot 二进制与传入摘要一致；模块本身不证明外部传入摘要属实。compat 采用本模块生成的有序字段形式并严格比较 codec 形式，数值相等的 32.0 不能冒充整数 32。

兼容身份故意严格：引擎可执行文件、引擎版本/hash、平台、real_t 精度、模块或 codec 任一变化都需要新的显式兼容策略和实测，不能承诺跨 Godot 版本或跨构建续接。生产层还必须绑定玩法源码/内容版本、模式、流所有者与快照版本，模块并未代替它们。

原生依据：[Godot 4.6 RNG 文档](https://docs.godotengine.org/en/4.6/classes/class_randomnumbergenerator.html) 明确 state 恢复约束及 seed 的副作用；[4.6.3-stable RNG 头文件](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/core/math/random_number_generator.h) 给出 uint64 seed/state 与原生 API；[RandomPCG 源码](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/core/math/random_pcg.cpp) 显示实例 randomize 使用自身状态与时间、相等整数端点不 draw、完整 signed32 范围有专门处理。这些是源码核对，不是本机运行证明；实现不复制或自造 PCG 算法。

## 两阶段实际运行交接

`qa_driver.gd` 使用 built-in 类型和运行时 load，没有早期 Autoload 全局依赖。根任务可用已有受控生命周期，把下列三个文件按原路径放在最小私有项目：

1. `scripts/run_state_value_codec.gd`，原字节 c8c4。
2. `scratchpad/run_gameplay_rng/gameplay_rng.gd`，pins 的 raw 字节。
3. `scratchpad/run_gameplay_rng/qa_driver.gd`，pins 的 raw 字节。

私有 project.godot 由主机生成并单独 pin，无需主工程场景或 Autoload；禁止覆盖已有目录。原 scratchpad 的 `.gdignore` 是扫描隔离标记，入口用完整显式 `--script` 路径加载，不依赖导入扫描注册 class_name。不要复制主工程缓存、玩家目录或其他生产脚本。

设置 **子进程**环境 `GAMEPLAY_RNG_QA_MANIFEST=<绝对路径>/<run_id>/<writer|reader>_manifest.json`。两个 manifest 的精确九字段见 `qa_contract.json`。writer/reader 各用 `run_dir/private_profile/<stage>/` 下的独立实际 user://，子进程 APPDATA/LOCALAPPDATA/TEMP/TMP 由主机设置；不改 HOME、不改父进程环境，不使用不存在的 `--user-dir` 参数。

顺序必须是：新 run → writer → 确认该实际 PID 退出、report/stdout/日志/源码通过 → 冻结 writer_report.json 与 handoff.json raw SHA → 新 reader manifest → **另一个实际 Godot 进程** → reader → 确认退出和完整 guards。shared source lock 必须覆盖每次真实子进程存活窗口；主机在释放锁前确认退出，无法确认就不解锁。不与 Steam 导出、其他 Godot 或性能运行并发。

writer 用七个种子，对每个先做 17+index 次混合调用，再保存 checkpoint，继续 64 次混合调用形成预期后缀与终态。每段直接对照另一个同种子的原生 RNG 实例。writer 把 checkpoint、浮点位值、int、终态统一经 value codec 写成 handoff.json；reader 从该文件解析并恢复，和另一 PID 产生的后缀/终态比较。reader 在每个玩法调用前额外消耗全局 RNG 与独立视觉 RNG。writer 另查本模块初始化/draw/capture/restore 不消耗全局流。

这两轮成功只证明同一已锁定运行环境中该模块的跨进程续接。没有复现旧共享全局序列，没有验证 Battle 恢复、物理步顺序、所有玩法调用迁移或存档磁盘原子性。`restore_ready` 始终 false。

主机验证应严格执行 `qa_contract.json`，包括唯一 stdout JSON 与 sidecar 相等、实际 PID/user 路径、两个阶段 source before/after、两输入工件 SHA、非空 checks 的全部 passed、强制 labels、严格 Unicode/Parse Error/ERROR/WARNING/FAIL 日志检查。writer 独自成功不能记为跨进程成功。静态 preparation 也不是游戏 QA。

## 尚未接入的生产边界

见 `production_boundaries.md` 的实际方法/行号/读源 SHA。未来由 Battle 明确持有本流，把该实例传到 Unit 等玩法对象；视觉继续走另一实例或独立视觉策略，不能从 gameplay_rng 派生视觉随机消耗。所有随机调用要保留原来的短路、循环、事件顺序与“已有 proc_roll 就不再 draw”的条件。统一快照屏障、异步/延迟伤害对象和恢复时禁止构造副作用仍由完整 M3 方案负责。
