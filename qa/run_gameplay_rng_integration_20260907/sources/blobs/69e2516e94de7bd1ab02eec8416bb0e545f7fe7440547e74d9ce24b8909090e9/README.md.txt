# 可调用的安装内容身份草稿

生产未应用，未运行 Godot/Git，未导出或复制真实私有工程。8 个小型 Python 文件夹静态检查通过，当前收据由 `pins.json` 指向；`static_runs/20260906T205753162525Z/static_receipt.json` 是保留的早期准备历史，不冒充最终源码。静态检查不证明 GDScript 解析、真实源码身份或 PCK 运行已通过。

## 接口与职责

将 `provider.gd` 原字节放到私有候选 `scripts/run_content_identity.gd`。调用：

```gdscript
var provider = load("res://scripts/run_content_identity.gd").new()
var identity: Dictionary = provider.resolve_runtime_identity()
```

成功字段为 `ok=true/code=OK`、`identity_schema=1`、`identity_scope=installed_inputs`、`content_version=source-v1:<sha256>`、`source_sha256`、实际 `engine_binary_sha256`、`source_mode`、`save_eligible=true/save_code=OK`，以及 `rules_sha256/file_count/total_bytes/provider_sha256/optional_content`。失败返回 `ok=false`、具体 `code`、`save_eligible=false/save_code=code`。没有身份输入参数，save、展示版本、QA 环境变量均不能供应身份。

这是安装输入的身份资格。调用方另行验证标准 30 波、关卡内存参数、工坊/场景数据及完整 Battle 保存图；`save_eligible=true` 不代表任意模式已支持续玩。provider 失败的新局可使用根任务实现的无身份 RNG（禁止 capture），照常游玩；恢复绝不能降级为无身份/随机新局。

## 同一规范的两种路径

- 规范仅写在 provider 的 `INPUT_RULES_JSON`；Python 生成器直接读取这段精确字符串，双方把其 SHA 纳入规范头。排序路径采用原始 Unicode 字符顺序和 `/`，拒绝控制字符、路径穿越、链接/重解析点、大小写碰撞。文件行是 `F<TAB>path<TAB>bytes<TAB>raw_sha256<LF>`，目录/可选文件存在性另有 `D`/`O` 行；大小/计数均在精确整数范围。
- 源码模式只接受编辑器实际执行、没有 `--main-pack`、物理 `project.godot`/scripts/scenes 及 provider 原源码可读。执行中的 provider 文本与物理原文做 BOM/CRLF 规范比对，实际身份仍使用 raw SHA。扫描固定 scripts/scenes/assets/content/scenarios/fonts/shaders/addons 和固定根文件；输入规则之外的目录不扫描。`.gdignore` 是导入提示，不是显式读取不可能的证明，所以 marker 及固定 roots 内的后代均保守纳入；可能因此多包含源码工作区的非运行素材。文件/hash 后再做一遍路径/大小/mtime 列表核对；这是静止输入快照，调用方不得并行改源或挂载其他包。第二遍没有再次 hash，不能防御同秒同长度且时间戳不变的改写，也不重新证明全部已缓存 Script。实际 QA 必须用冻结来源和受控新子进程补足。每次解析会读输入文件，建议根启动事务只解析一次并保存上下文，后续源变化由现有 sourceguard 处理；没有引入跨局缓存，本批不宣称启动耗时已测。
- 打包模式只动态 `ResourceLoader.load` 编译后的 `run_build_identity.gd`，不尝试读取包内 `.gd` 文本。先确认 Updater 启动完成且没有未支持的实际挂载，再加载常量，避免早期 preload 命中旧常量。正式包中规范/schema/路径/字段/范围必须匹配；两份可选 JSON 的存在性、原始字节必须与编译身份一致。当前 Windows GodotSteam 的绑定源与原生 DLL 均在输入集合，运行时再校对当前 debug/release 实际 DLL；其他原生布局明确 unsupported。
- 两种模式都实时测量 `OS.get_executable_path()` 所指实际执行文件，不用导出模板或引擎展示版本冒充。不同编辑器、不同最终 EXE，或者源码全量集合与导出白名单集合不同，可以产生不同身份并拒绝互相读档，这是当前严格兼容合同。

Godot 官方说明支持通过 [Script 的常量表读取编译脚本信息](https://docs.godotengine.org/en/4.6/classes/class_script.html)；文件是否有原源码不能等同于脚本资源是否可加载。枚举使用 [DirAccess 的显式打开/遍历/链接检查](https://docs.godotengine.org/en/4.6/classes/class_diraccess.html)，没有把导出资源列表冒充物理源码列表。

## 热补丁和合法内容

`updater.patch` 是唯一必需的运行引导修改：实际 `_init` 完成后 `complete=true`；仅在签名/平台/SHA/size 校验后 `load_resource_pack` 成功，记录当时精确 `patch_sha256`。只读 `run_content_mount_identity()` 返回这三项。旧实例无方法、未完成或证明结构不符，身份解析失败；已验证挂载非空 SHA 返回 `PATCH_MOUNT_UNSUPPORTED`，不假设无补丁。新局仍可无身份运行。没有读取展示版本来判断这一状态，也没有读玩家补丁文件后自己模拟验签。

合法 `res://content/units.json` / `abilities.json` 可以存在，按真实 raw SHA 纳入并在 PCK 中校对。`steam_builder.patch` 同时把成功 QA 收据中的 content JSON 纳入物理复制白名单、给 Windows Steam 的 include_filter 增加 `content/*.json`，使实际直接读取的文件不会导出丢失。没有扩大为任意工坊脚本或原生模组的恢复支持。

## 私有构建步骤

生成器默认不运行引擎；只有 `seed/generate` 写入，且限制到所属 checkout 的 `.godot` 或 `scratchpad` 下、名为 `project` 的私有工程。`snapshot` 只读，可用 `--provider-rel` 指向实际加载的 scratch provider，此路径本身及实际字节也会进入身份，不会冒充正式 provider。

1. 按成功 QA 的真实白名单复制候选工程、安装既有 native。候选必须已经有正式路径 provider 和 Updater 窄补丁。不要改旧 QA 收据来冒称包含它们。
2. `python build_identity.py seed --project <private-project>` 创建唯一无资格的常量 stub；已有常量严格拒绝，不覆盖。之后由根在共享独占锁内运行已有 import。Godot 生成的 `.gd.uid` 正常参与输入；仅派生常量 `.gd` 自身被排除，不能连 UID 一并跳过。
3. `python build_identity.py generate --project <private-project> --receipt <run>/content_identity_generation.json` 根据导入后的真实输入生成最终编译常量；只允许替换精确 stub。收据放工程外。生成前后复核同一输入集合，旧输入/旧常量漂移拒绝。
4. 使用现有导出步骤。`python build_identity.py verify --project <private-project> --receipt <generation-receipt>` 在导出后严格核对实际字节；不能用随手刷新摘要消除导出漂移。
5. 运行下述 source 和实际 PCK probe。两者均通过后，才把这条新构建路径标记为具有可保存身份。

```text
python probe_runner.py --project <private-project> --receipt <generation-receipt> --godot <actual-non-console-Godot.exe> --run
python probe_runner.py --project <private-project> --receipt <generation-receipt> --godot <actual-non-console-Godot.exe> --main-pack <actual-exported-LiangshanHeroes.exe-or-pck> --run
```

无 `--run` 只做 preflight。runner 不导入/导出/改生产，仅为现成工程/包启动一个实际 Popen 子进程，严格匹配 10 个非空唯一检查、实际 PID/user://、stdout/sidecar、引擎与源码摘要。复用仓库已归档 R1 utility `8f9c…`、process safety `7983…`、sourceguard `1cec…` 的原字节，仅重绑这些 helper 的文件路径；不依赖另一台机器不存在的 scratchpad 历史文件。共同锁由 CLI 或既有 builder 持有，退出不明/收据缺失保留锁。子进程只设置私有 APPDATA/LOCALAPPDATA/TEMP/TMP，不覆盖 HOME。真实玩家目录与生产源前后必须相同。

PCK probe 用实际编辑器加载实际导出包，测试真实编译资源及包内 provider 路径。它会如实报告 `release_process_tested=false`；已有 Steam verifier 的实际 EXE/DLL 检查继续保留。根还需在正式 EXE 的真实 Battle 入口核对 provider 成功，不能把编辑器 PCK probe 自称为发布进程的 Battle 保存验证。

## 现有 Steam builder 的窄提案

`steam_builder.patch` 在现有构建的 import 之前 seed，import 后 generate，export 后 verify；沿用现有 Steam 包检查后，在同一锁中顺序执行 source probe、PCK probe，并保留真实玩家/生产 sourceguard。任何新 probe 退出未确认，外层 builder 不释放锁。没有改其他旧构建链；那些链缺少生成资源时 provider 如实失败，新局可以无身份玩，不能保存或恢复。

补丁预期把 `build_identity.py`、`probe_runner.py`、`pck_probe.gd` 和 `.gdignore` 原字节放到 `tools/contracts/run_content_identity_20260907/`（Python namespace package），把 provider 原字节放 `scripts/run_content_identity.gd`。辅助文件都在既有 export 排除的 tools 下；派生常量仅在私有 staging 产生。当前只是该落点的提案，未实际复制或应用。
