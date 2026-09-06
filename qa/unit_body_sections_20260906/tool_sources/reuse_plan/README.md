# Unit 四段诊断：复用分离私有项目的换代计划

状态：计划就绪，未执行换代、未运行 Godot、未读取/重哈希 590 MB 的 base.tar 或约 700 MB 项目内容。所有本轮新文件仅在本 `reuse_plan/`；现有 Unit 草稿、私有项目、历史报告和收据均未改。

项目根仍是 `scratchpad/separation_sections_diag/runs/20260906T104036739951Z/project`。其原始导入失败收据不变，真正已完成的父代次是 `scratchpad/separation_sections_diag/resume_runs/20260906T110413889769Z/`：receipt complete=true，timed/clockless analysis_valid=true，lock_released=true。不能拿原失败目录的 receipt 当作本次的完成收据。

## 已确认的有限范围

本轮读了 18 个明确指定的私有脚本/UID，共 1086848 字节，raw SHA 全部与父代 `source_final.json` 对应条目一致。另对 11 个 frozen 关键源只读 `git show 4baafc11af55b0e46a57a48e54df181b8c1917a2:<path>`，确认 LF 内容全部一致；Battle/Unit/Crowd 的原 frozen raw 也与 Git blob 逐字节一致。

完整观测见 `inspection_receipt.json`；可供逐文件执行的计划见 `file_plan.json`。两份都是本次只读准备的收据，不是换代成功收据。

- 私有 Battle 仍是旧分离插桩 raw `72ddfd2716a85ca2adda81b3d6d9a19e43ee63fa34f303a58b25e8261c40727a`。
- 私有 Crowd 仍是旧分离插桩 raw `19fde3994424acf3f41962df7ddd9fe73cbbe91247a8bc01df7d0e7318bda4fe`。
- 私有 Unit 是未插桩 raw `c8310fd12a29858df8f7410dd06d2f1dc51f40f5eedc0e7a6a16599eb5e58856`，故本次明确选 **raw 产物**，不能选择 LF 版把整文件换行改变。
- 新 Unit driver/ledger 目标不存在，目标的 `scratchpad/`、新目录和 `generated/` 没有 `.gdignore`。
- 旧公共 M1 三工具、project.godot 部分是已归档 CRLF 字节；LF 与 4baa 一致。它们保持当前 raw，不顺手归一换行、不换成当前 live 06c2c69 版本。
- 父代最终源清单 3302 文件、缓存清单 2376 文件；已保存的 cache_after_completed_import 与 cache_final 内容一致。本次仅读清单，**没有确认当前所有资源/缓存字节仍与它们一致**。

既有 `static_receipt.json` 的 31 项是逆向还原、结构和算术检查，仍明确 `gdscript_parsed_or_executed=false`。本轮验证新产物摘要匹配 pins，不重跑会改写既有收据的生成器。

## 允许的逐文件变更

下表路径均相对上述**私有 project**，payload 相对当前主 checkout。完整 before/after SHA 在 `file_plan.json`。

| 私有目标 | 动作 | payload |
| --- | --- | --- |
| `scripts/battle.gd` | 恢复 4baa 原 raw，移除 SeparationDiag preload/包装计数 | `scratchpad/separation_sections_diag/frozen/scripts__battle.gd` |
| `scripts/crowd_separation.gd` | 恢复 4baa 原 raw，移除 SeparationDiag begin/section/end | `scratchpad/separation_sections_diag/frozen/scripts__crowd_separation.gd` |
| `scripts/unit.gd` | 原 raw 匹配后替换为完整 body 四段探针 | `scratchpad/unit_body_sections_diag/generated/unit_instrumented.raw.gd.txt` |
| `scratchpad/unit_body_sections_diag/generated/driver.gd` | 新增，必须原先不存在 | `scratchpad/unit_body_sections_diag/generated/driver.gd` |
| `scratchpad/unit_body_sections_diag/generated/ledger.gd` | 新增，必须原先不存在 | `scratchpad/unit_body_sections_diag/generated/ledger.gd` |

恢复后的 Battle raw=`9fe157e49ef18f2ced0b10ee96f893a1f0ded4ce64e6d757e936d4ef4e9e1ee4`，LF=`784373eede18a82c24fc50a6e36a42b6c20516bf439cf200fe5be7d239db6e2c`；Crowd raw/LF=`3f6eb8221547787d5da59f58976ba506228c22ed5a3aa71822b160d659ce817b`。

新 Unit raw=`443e082699992d63e1a8f7eb905905ad86a4a63e6b06e5842c06c6a41c61d676`；新 driver=`9a3d0b019d83404396c88b8def35743a01492ad531bf5faffffcac75b4bc4491`；新 ledger=`eb9a3c1e38e9da184db83e6d6df73bd056788217d2a64e02987cc7fbac12008b`。

保留现有 `scripts/{battle,unit,crowd_separation}.gd.uid` 原字节。旧 separation driver/ledger 及各自 UID 四文件仍留原位，属于可追溯的惰性历史源；本次启动命令只选新 driver，恢复后的 Battle/Crowd/Unit 不得有 `SeparationDiag` 或旧 `separation_sections_diag/generated` 引用。不添加 Autoload、不改 project.godot、不复制整个草稿目录或其中 `.gdignore`、README/pins/备份到私有 project。

## 执行顺序与新 generation

1. 主任务在全新 `scratchpad/unit_body_sections_diag/generations/<fresh-UTC>/` 建换代目录，记录父代路径、父代 receipt/source_final/cache_final/import_metadata_policy/generated_uid_receipt 的摘要。**不写回旧 runs/resume_runs 任何证据文件**。旧 base.tar、失败日志、旧生成探针及已完成报告原样保留。
2. 使用现有 `.godot/redraw_rejection_source.lock` 共锁和真实 Godot 进程独占检查，确认旧测量/编辑器已退出；不要仅凭历史 receipt 或目录为空当作独占。新代先建立 `complete=false` 的收据。复用冻结的 process_safety/既有 helper 即可，不扩建通用 runner。
3. 修改前一次性核对全部五个目标的 before 条件、payload SHA、祖先路径无 reparse/link 且确实在该私有 project 内。新目录原先不存在。把三份将被覆盖的**实际当前 raw**分别存到新 generation 的 `before/`，记录路径/摘要/字节数；只备份约 1 MB 脚本，不复制项目/缓存/profile。
4. 先恢复 Battle 和 Crowd，并核对上述 frozen raw。确认 Unit 仍是 c8310f… 后再写 raw 探针及两 GD；每次写入完成回读 SHA，记录五项日志。五文件不是一项原子事务：任何一步失败都不启动 Godot，保留逐文件状态和备份；不能在外部修改或独占不明时自动恢复/删除现场。
5. 建立本代 expected source 清单：父代 `source_final.json` 的 3302 条保留，只覆盖三目标摘要，新增两 GD，共 **3304** 条；不删旧 probe/UID，不放宽其他路径。清单须另存，不能覆盖旧清单。实际源必须经本代资格检查；本次只读计划没有完成全项目现态校验，不能把派生清单称为全量重验结果。
6. 若主任务需要“全来源已核验”的入口，执行时应对旧清单全部路径及完整路径集合做一次受控核对，再与五项差异严格比对。本次不重读这些资产。若主任务选择只继承父代完整验证 + 本代小文件/元数据检查，必须显式记 `full_current_source_verified=false`，不能给出同等的完整来源资格。
7. 使用新 generation 的 setup 空 profile 做一次私有项目增量 import/编译；沿已经确认的实际非 `_console` exe 持有真实句柄，最多沿原 600 秒上限，遇编译/严格日志错误保留首失败。无需重新解包 Git archive、重新复制资源或删除已完成导入缓存。
8. source 侧只允许新 `.../driver.gd.uid`、`.../ledger.gd.uid` 两个明确附加路径，验证 UID 文本及其对应脚本摘要；现有 UID 全部不变。若两者均生成，源条目为 **3306**，数量不能代替集合精确比较。所有 `.import` 已是父代完成导入后的版本，本次不再次一概允许 CRLF→LF 或任意 metadata 改写。
9. setup 前后建立本代 cache 清单/差异。预期增量集中于 `uid_cache.bin`、脚本类缓存、editor filesystem metadata；不得仅因在 `.godot` 下就放行任何变化。生产资源及其 `.import` 不变，若 `.godot/imported` 资源内容有新增/删除/改字节，先列出来源依赖解释再冻结，不能静默借重导入掩盖差异。新代完成 import 后再冻结实际 source/cache 摘要；测试时沿原规则只允许另列 shader_cache 变化。
10. 同代 timed/clockless 使用完全相同源码/缓存起点和同一新 driver，仅换模式与新空 profile。各自的日志、配置、原 M1 报告、四段 sidecar、退出检查、完整性分析均在新 generation；新代 receipt 只有两入口及源码/profile/退出守护通过才 complete=true。保留旧父代记录，即使共享 project 此后换代，也不重标旧结果。

本计划不承诺并发恶意更改下的原子性；共锁、已知文件摘要和真实引擎退出是本项目合作运行边界。

## 两个 10 秒入口合同

命令参数列表只选：`<actual-exe> --path <private-project> --script res://scratchpad/unit_body_sections_diag/generated/driver.gd`。原 4baa 的 M1 没有后来效果质量选择字段，保留它当时的原规则，不能混用 live M2C 的质量参数或脚本后仍叫同源诊断。

| 环境 | 值 |
| --- | --- |
| `UNIT_BODY_SECTIONS_MODE` | 先 timed，实际退出后再 clockless |
| `UNIT_BODY_SECTIONS_OUT` | 本代 `<mode>/report.json` 绝对路径 |
| `UNIT_BODY_SECTIONS_OUTPUT_ROOT` | 本代 `<mode>` 输出父目录的绝对路径，须覆盖 OUT |
| `UNIT_BODY_SECTIONS_USER_ROOT` | 该模式新建的空 `private_profile` 绝对路径 |
| `APPDATA` / `LOCALAPPDATA` | 该 private_profile 中各自独立目录 |
| `TEMP` / `TMP` | 同代私有 temp，预先创建，不指回玩家目录 |

父进程清除继承的生产诊断开关和所有 `SEPARATION_SECTIONS_`、`FIRST_USE_`、`ANIM_LOAD_`、`UNIT_BODY_SECTIONS_` 后只设置这次所需项，不能直接调用旧 separation `measure_pair()`（它硬编码旧 driver/环境/分析器）。可复用其小范围源码/进程保护 helper，不要改旧 runner/pins。公开 M1 environment() 只清理开关，不提供完整的共锁/私有 profile 防护。

沿原真实渲染 Vulkan Forward+、固定镜头、分辨率/音频政策，禁用 fixed-fps/headless 测量。driver 固定 defense200/fixed/10，原 seed、配置、输入、音乐就绪、300 步 warmup 及 frame_post_draw 循环都保留；不加入当前动画预加载或其他探针。设置实际 user:// 必须落入本代 profile，主任务仍应核对与预期完整路径相等且玩家目录前后不变。

四段仍是生命周期/建筑/死亡、状态与计时、目标/状态机/移动、尾部动画/命中/看门狗。原体 8 个外层早退保留，通过外 wrapper 收末段。尾段包含 `_deal_hit` 和卡死重寻路，不是纯视觉可删预算。

实际有效性要求：日志严格通过、真实进程退出；sidecar/M1 用原 started/now 对齐，测量步切片数量=原 M1 physics_ticks，呈现 raw_ms 相等；每步开始/完成守恒、四段和=完整 body、到达/结束计数守恒、无重入/溢出；timed 非负、clockless 所有单位级时长=-1。warmup 是至少 300 步，以实际 warmup_end_tick 为准。平均值除实际测量步数 N，不能补成 600 步。

## 剩余缺口

恢复与新探针 payload 均存在，关键源/换行选择没有缺失信息。以下只能在获准执行换代后完成：

- 全项目当前资源/缓存与旧完整清单的现态资格（本轮明确未做）。
- 新 Unit/driver/ledger 在真实 Godot 下的解析/增量 import、实际新增 UID/cache 差异。
- timed/clockless 两个 10 秒的同钟守恒、所有实际早退、实例生命周期和进程/profile 守护。

当前计划不需正式性能窗口或新镜像；两窗口也只用于归因，不是优化、FPS 提升或性能达标证据。
