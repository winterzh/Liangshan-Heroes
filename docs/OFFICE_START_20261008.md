# 公司电脑续做入口（2026-10-08）

<!-- campaign-proposal-v27x1 -->
下一计划项已备妥：v27b保存回读收据代码与独立源码审查存QA proposals/campaign_persistence_observability_v27。current=proposed_b，未native/未Rootapply。公司先建立新基线，再做19条真实ConfigFile故障验收；它不代替单人撤离完整负例/终局与日志持久恢复。收尾工具r2静态闭合，仍待06:00实际门槛和执行。

<!-- offline-terminal-v25x16 -->
最新终态（04:36）：F/run71d4275a在导入被共享Godot打断，actual exit1/锁已释放，C和双方撤离A未运行。完整证据已归档；当前没有本线程运行中的原生后台。准备通过、原始四文件资格及后续计划分别保留，源码候选仍未资格。下方04:19运行中与启动段落是历史。

<!-- offline-prepare-v25x10 -->
最新状态（04:19）：r2f/run71d4275a已启动，先做纯文件独立冻结，再按原守卫等待Godot。8f与5284两次导入中断都保留原证据，均未执行新C/双方撤离A。新准备入口的完整测试义务不变，暂无新native通过；r2e1全矩阵复用仍缺真实闭合A证明，不能称已完成。公司新机不能直接运行这些今夜固定截止/同机恢复入口。

<!-- prefix-interruption-v25x7 -->
最新结果（03:46）：后继8f3d393d在原生导入时因共享Godot恢复占用而中止，actual exit1、锁已释放，C/双方撤离A尚未执行。原失败批与新导入失败批分别保留，v25整体仍未通过。下方首段“刚启动”是启动时快照，以本段及最终收据为准。完整证据：qa/zhu_wounded_20261005/prefix_interrupted_delivery_v25x7.json。

先用 stable 正常开发；拉代码不会恢复家里的后台、缓存或运行中档案。当前已验证的生产变更是 JSON 边界四文件，v25 的 Core/UnitContract 两文件仍未资格，只放在 QA 提案。原 run07ad37bf 因共享引擎恢复占用中断，未完成 C/真实 Lu-Shi A；后继8f3d393d同机恢复批刚启动，尚无新原生通过报告，以最终收据更新结果。阶段结果不合并成整批通过。

## 1. 确认代码与本机入口

目标仓库 `winterzh/Liangshan-Heroes`，分支 `codex/sync-20260905-stable`。在公司独立 checkout 根目录检查：

```powershell
git status --short --branch
git remote -v
```

仅在干净、正确分支且未分叉时 `git pull --ff-only origin codex/sync-20260905-stable`。以本次最终远端同步收据的 SHA 为交接版本；旧 PR #1 已合并关闭，不继续操作它，不自行合并 main。旧外层 `Liangshan-Heroes/` 和全部 `E:/` 路径/PID仅作历史位置。

配置 Godot 4.6.3：在工程根被忽略的 `godot.local.txt` 写本机 EXE 完整路径（无引号），或设置 `GODOT_PATH`。原正常启动命令可执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_local.ps1 -Mode import
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_local.ps1
```

先等共享引擎自然空闲；不结束或控制其它任务。普通启动/导入后回读日志和 git status，形成公司自己的启动 baseline；不把这一步当保存续玩或完整战役原生资格。

## 2. 原生续玩 QA 的依赖准备（普通开发无需先执行）

先正常导入和开发即可；缺 vendor 或未编译 reader 本身不构成普通源工程的启动前置。只有重新建立原生续玩 QA 基线时，才需要以下原生依赖与来源核验。普通启动无 steam 特性时由 SteamService 提前返回；这只是当前源码合同，尚未验证公司机器启动。

GodotSteam 固定下载包可用 `python -X utf8 -B tools/setup_steam_dependency.py`，工具验证固定 archive SHA 并写本机忽略的 vendor/provenance；这不是 Steam登录/上传，也不会自动把扩展安装到普通Root。QA producer调用install_native(project)时才给隔离工程装入addons并在首次导入前登记extension_list；普通run_local不做此步骤。reader还需 Visual Studio C++/CMake/Ninja，入口为 `tools/build_steam_stats_reader.py --work-root <公司独立英文短目录> --profile-root <新私有profile根>`，详见 `native/steam_stats_reader/README.md`。该工具编译并跑原生 smoke，受测 DLL 到 vendor 的 promotion 是后续受控步骤，不能把编译产物直接当已资格的原依赖。

准备原生续玩 QA 基线时，下面是现成的**只读**前置命令（均不加 --run、不启动 Godot）：

```powershell
python -X utf8 -B tools/run_steam_integration_qa.py
python -X utf8 -B -c "from tools.run_steam_integration_qa import native_dependencies; print('native manifests verified:', ', '.join(native_dependencies()))"
```

第一条只核对普通 source/Godot/lock 配置，第二条核对实际 vendor 文件、manifest/SHA/许可清单。缺依赖或 SHA 不符时只阻断原生 QA 前置；正常源码开发仍按第1节启动，不绕过 QA 来源核验。`.godot`、vendor原生包、玩家/登录数据与导出包不靠 Git迁移。导入会重建缓存，不会下载DLL。

## 3. 公司新建 QA 后继

已资格四文件：`run_snapshot_store.gd`、`run_slot_store.gd`、`run_scenery_json_boundary.gd` 及 UID。两份未资格提案在 `qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25/proposed/scripts/`，对应 Core SHA `92b2bdac…`、Contract SHA `b2f52bcc…`；原候选完整六条 SHA 见 `safe_retreat_candidate_v25x1.json`。先在**新的私有候选 checkout**逐文件应用提案并核对来源，不覆盖 stable 生产或原 QA。

旧 r2a/r2b2/base 固定截止为香港时间 2026-10-08 06:00；此后不能直接执行，也不能改旧代码或 CLI偷偷延长。旧工具还依赖物理 E 缓存工程。用户已授权按计划续做与同步；公司继续时建立新 office sibling，并设置当次新截止：重新bootstrap/导入、新 source/native/engine/cache/content基线、新UUID/私有profile，配套当前路径的独立 runner/producer门禁。公司 fresh 环境的 baseline/cache/path 门禁仍需建立，当前旧执行器不能宣称已可直接复跑；这些是技术前置，不是额外用户审批。

只读历史依据和完整提案都已存 QA。full 方案参考 s1 与 e61（r2b2）原完整链及独立 full审查，A-only review不能解锁 full。最新 r2e 继承实际 e61 全链，已静态 peer；因尚缺真实 A 来源仍为 blocked，不能称公司可直接运行。今夜 prefix-C/来源复用仅适用于同机四小时/原 monotonic 条件，公司新机器应建立 fresh 全链，不继承旧 PID/时钟/profile。

## 4. 从这里继续，完整门禁不删

顺序是：新六源码批 JSON533/OwnedSlot76/办理半程 ABC全部完成 → Lu-first/Shi-first两份真正单人安全 A → world264、component362、每角色live24三消费者 → 原 B/C/D自然终局与新进程旧槽拒绝。所有数量是既有合同，办公室通过须由新实际报告和来源链证明。原失败 profile只读保留，新批不复用半写档案或旧锁。

再按完整计划处理日志真实章节语义与 `CAMPAIGN_QA=0` 的持久进度、付费生产/船体运输/其他动态、自然胜败与奖励、同版九玩法 EXE、美术UI/多尺寸、长跑性能和 Android真机。`CAMPAIGN_QA=1` 不写 campaign.cfg，Steam-disabled不证明奖励。本轮 Git同步不发布新 Steam包。细节看 `HANDOFF_20261007_OFFICE.md`、`DEVELOPMENT_PLAN.md`；历史段落保留，不替代本页新执行入口。
