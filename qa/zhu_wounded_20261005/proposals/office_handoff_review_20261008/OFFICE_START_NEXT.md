# 公司电脑开始续做（顶部入口候选）

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
powershell -NoProfile -ExecutionPolicy Bypass -File .	oolsun_local.ps1 -Mode import
powershell -NoProfile -ExecutionPolicy Bypass -File .	oolsun_local.ps1
```

先等共享引擎自然空闲；不结束或控制其它任务。普通启动/导入后回读日志和 git status，形成公司自己的启动 baseline；不把这一步当保存续玩或完整战役原生资格。

## 2. 原生依赖分开准备，先只读核验

GodotSteam 固定下载包可用 `python -X utf8 -B tools/setup_steam_dependency.py`，工具验证固定 archive SHA 并写本机忽略的 vendor/provenance；这不是 Steam登录/上传。reader还需 Visual Studio C++/CMake/Ninja，入口为 `tools/build_steam_stats_reader.py --work-root <公司独立英文短目录> --profile-root <新私有profile根>`，详见 `native/steam_stats_reader/README.md`。该工具编译并跑原生 smoke，受测 DLL 到 vendor 的 promotion 是后续受控步骤，不能把编译产物直接当已资格的原依赖。

准备到正常项目可导入后，下面是现成的**只读**前置命令（均不加 --run、不启动 Godot）：

```powershell
python -X utf8 -B tools/run_steam_integration_qa.py
python -X utf8 -B -c "from tools.run_steam_integration_qa import native_dependencies; print('native manifests verified:', ', '.join(native_dependencies()))"
```

第一条只核对普通 source/Godot/lock 配置，第二条核对实际 vendor 文件、manifest/SHA/许可清单。缺依赖或 SHA 不符即停在前置，不能绕过。`.godot`、vendor原生包、玩家/登录数据与导出包不靠 Git迁移。导入会重建缓存，不会下载DLL。

## 3. 下一次授权后新建公司 QA 批

已资格四文件：`run_snapshot_store.gd`、`run_slot_store.gd`、`run_scenery_json_boundary.gd` 及 UID。两份未资格提案在 `qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25/proposed/scripts/`，对应 Core SHA `92b2bdac…`、Contract SHA `b2f52bcc…`；原候选完整六条 SHA 见 `safe_retreat_candidate_v25x1.json`。先在**新的私有候选 checkout**逐文件应用提案并核对来源，不覆盖 stable 生产或原 QA。

旧 r2a/r2b2/base 固定截止为香港时间 2026-10-08 06:00；此后不能直接执行，也不能改旧代码或 CLI偷偷延长。旧工具还依赖物理 E 缓存工程。公司续做须在下一次明确授权后生成新 office sibling：重新bootstrap/导入、新 source/native/engine/cache/content基线、新UUID/私有profile，配套当前路径的独立 runner/producer门禁。该公司可执行后继**目前未提供，不能宣称已可直接复跑**。

只读历史依据和完整提案都已存 QA。full方案参考最新 s1/r2b2及独立 full审查，A-only review不能解锁 full。今夜的 prefix-C恢复仅用于同机四小时/原monotonic条件，公司新机器不能使用。

## 4. 从这里继续，完整门禁不删

顺序是：新六源码批 JSON533/OwnedSlot76/办理半程 ABC全部完成 → Lu-first/Shi-first两份真正单人安全 A → world264、component362、每角色live24三消费者 → 原 B/C/D自然终局与新进程旧槽拒绝。所有数量是既有合同，办公室通过须由新实际报告和来源链证明。原失败 profile只读保留，新批不复用半写档案或旧锁。

再按完整计划处理日志真实章节语义与 `CAMPAIGN_QA=0` 的持久进度、付费生产/船体运输/其他动态、自然胜败与奖励、同版九玩法 EXE、美术UI/多尺寸、长跑性能和 Android真机。`CAMPAIGN_QA=1` 不写 campaign.cfg，Steam-disabled不证明奖励。本轮 Git同步不发布新 Steam包。细节看 `HANDOFF_20261007_OFFICE.md`、`DEVELOPMENT_PLAN.md`；历史段落保留，不替代本页新执行入口。
