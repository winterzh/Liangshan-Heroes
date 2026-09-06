# Gameplay RNG 运行时合同草稿

当前仅完成静态准备，未启动 Godot；source 双进程和 PCK 均待 root 实跑。旧 `scratchpad/run_gameplay_rng_r1/` 和生产源码未改。此模块不代表完整续局，Battle 随机调用尚未迁移。

## 调用合同

```gdscript
const GameplayRng = preload("res://scratchpad/run_gameplay_rng_runtime/gameplay_rng.gd")
var stream = GameplayRng.new(TRUSTED_BUILD_CONTENT_VERSION)
var started: Dictionary = stream.start(initial_seed, actual_engine_sha256)
var saved: Dictionary = stream.capture()
# 新进程：内容版本来自编译进应用的内容清单，不能从 saved 解出后传回。
var restored = GameplayRng.new(TRUSTED_BUILD_CONTENT_VERSION)
var checked: Dictionary = restored.validate_record(saved.record, actual_engine_sha256)
var loaded: Dictionary = restored.restore(saved.record, actual_engine_sha256)
```

构造参数必须为非空、非纯空白、最多 256 字符的 String。保留精确原值，不 trim 后接受另一身份。生产根负责提供可信内容版本；QA 的固定 `rng-runtime-fixture-v1` 只适合本夹具，不是游戏内容版本。

`start`、`capture`、`validate_record`、`restore` 和四个 `draw_*` 接口结果形状沿用 R1。记录仍通过 production codec 的 int64 标签/浮点位串传递，封装 `version` 从 1 改为 2。compat 明确包含 `content_version`、整数 `module_contract_version=1`、整数 `codec_contract_version=1`，以及原有真实引擎二进制 SHA、完整引擎版本字符串、引擎提交 hash、OS、`real_t_bits`。逐项 codec 表示严格匹配，数值相等的 float 合同版本仍拒绝。

模块/codec 版本是维护者对受信编译内容的协议承诺，不是从存档或脚本文本推断。当前 codec 没有导出的 ABI 常量，这个包装器明确声明适用的 codec v1 合同；后续改变其格式/类型规则必须审查兼容性并更新根内容版本及必要的合同版本。固定 preload 可随 PCK 的脚本 remap 正常解析，不从 save 动态 load。实际 EXE SHA 必须由可信 host 测量提供，不能直接相信 save 的 compat；模块本身不读取任何源文件，也不试图认证恶意调用者。

保留 R1 的原生独立 RandomNumberGenerator、先 seed 后 state、native readback 后才 commit、失败不改既有流/计数、完整 signed int64、四种原生 API、合法反向与等值范围语义。没有全局随机调用、预播/预热或 Battle 副作用。R1 v1 记录明确拒绝，没有暗中升级旧记录。

## Source 双进程

`run_qa.py` 默认只读预检，`--run` 才复制三份精确冻结源码和最小 project.godot，使用两个独立 PID 和两个私有用户目录。每进程仍真实读取源码 SHA，这是 **QA 的 source 证据**，不是模块运行条件。

```powershell
& $Python -X utf8 scratchpad/run_gameplay_rng_runtime/run_qa.py --godot $ActualGodot
& $Python -X utf8 scratchpad/run_gameplay_rng_runtime/run_qa.py --godot $ActualGodot --run
```

参数要求实际非 `_console.exe` 的已冻结 4.6.3 引擎。复制沿 R1 已审查的完整生命周期：共同锁、真实 Popen 退出确认、严格 UTF8/ERROR/WARNING、唯一 stdout/sidecar、生产源码和真实玩家目录不变、私有源及 UID 限制、writer 成功后才 reader、完整失败现场保留。新 command 的 Popen 使用 CREATE_NO_WINDOW，并每 0.1 秒轮询自身日志；strict ERROR/Parse/WARNING 即停止持有的实际进程，随后确认退出。source 入口用精确 SHA 载入同一小函数，日志名为 `<stage>_report_process.log`。reader 按实际独立 PID 验证 7 个 seed、各 64 个原生混合后续值及终态，在 global/visual 随机噪声下仍精确一致；source 负例还覆盖内容身份不能自证、模块/codec 合同及类型不匹配、无效内容版本、错误不改流。

输出在 `runs/<UTC>/`。合格条件为 receipt 的 `complete=true`、`lock_released=true`、source/player unchanged、两个实际 PID 不同，报告所有断言通过。任何引擎告警/失败保留原轮次，不覆盖报告重跑。

## PCK 单独验证

见 [PCK_QA.md](PCK_QA.md)。`run_pck.py` 是独立入口，source 成功不能替代它。原生 PCG 实现依赖精确引擎合同，不承诺跨引擎/跨平台/不同精度可继续；不宣称与旧 Battle 全局随机序列等价或完整战斗恢复。

## 冻结与归档

`pins.json` 锁运行三源和必要支持文件；两个 runner 使用相同 pins SHA，并各自在运行边界守护自身实际 SHA，避免 pins/self 循环引用。交接 `freeze_receipt.json` 另列两个 runner 精确 SHA 和静态检查；不能把静态收据说成引擎解析/运行通过。

可归档源码副本（GD 改 .gd.txt 并加 .gdignore）、配置、pins、合同、README、冻结收据及每轮 manifest/环境四路径、报告、handoff、日志、进程和总收据。不复制私有 profile、private project、`.godot` 缓存或 PCK 构建产物到公共 QA；导出原始字节可保留在本私有轮次供实际复核。既有 R1 失败/成功证据保持原状。
