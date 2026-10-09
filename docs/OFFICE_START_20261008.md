# 公司电脑续做入口（2026-10-08最终交接）

本夜已于香港06:00截止开发并完成两份未资格生产候选的精确复原。stable保留已通过限定原生验证的四文件JSON修复；完整候选和全部失败证据存QA，单人撤离完整验收、自然终局/持久进度及其它原计划仍未完成。没有本线程运行中的原生后台。交接提交d609b38e已独立回读，心跳6实际PAUSED；后续仅本次完成收据元数据提交，最终SHA见Git stable分支与最终独立远端收据。

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

已资格四文件：`run_snapshot_store.gd`、`run_slot_store.gd`、`run_scenery_json_boundary.gd` 及 UID。两份未资格生产候选已于本夜收尾逐文件复原；完整提案仍在 `qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25/proposed/scripts/`，对应 Core SHA `92b2bdac…`、Contract SHA `b2f52bcc…`；原候选完整六条 SHA 见 `safe_retreat_candidate_v25x1.json`。先在**新的私有候选 checkout**逐文件应用提案并核对来源，不覆盖 stable 生产或原 QA。

旧 r2a/r2b2/base 固定截止为香港时间 2026-10-08 06:00；此后不能直接执行，也不能改旧代码或 CLI偷偷延长。旧工具还依赖物理 E 缓存工程。用户已授权按计划续做与同步；公司继续时建立新 office sibling，并设置当次新截止：重新bootstrap/导入、新 source/native/engine/cache/content基线、新UUID/私有profile，配套当前路径的独立 runner/producer门禁。公司 fresh 环境的 baseline/cache/path 门禁仍需建立，当前旧执行器不能宣称已可直接复跑；这些是技术前置，不是额外用户审批。

只读历史依据和完整提案都已存 QA。full 方案参考 s1 与 e61（r2b2）原完整链及独立 full审查，A-only review不能解锁 full。最新r2e1继承e61完整链并只扩展精确r2f来源，已静态peer；r2f实际import中断、C和双方A缺失，因此真实proof不存在、full未启动，公司不能直接复用今夜入口。今夜 prefix-C/来源复用仅适用于同机四小时/原 monotonic 条件，公司新机器应建立 fresh 全链，不继承旧 PID/时钟/profile。

## 4. 从这里继续，完整门禁不删

顺序是：新六源码批 JSON533/OwnedSlot76/办理半程 ABC全部完成 → Lu-first/Shi-first两份真正单人安全 A → world264、component362、每角色live24三消费者 → 原 B/C/D自然终局与新进程旧槽拒绝。所有数量是既有合同，办公室通过须由新实际报告和来源链证明。原失败 profile只读保留，新批不复用半写档案或旧锁。

再按完整计划处理日志真实章节语义与 `CAMPAIGN_QA=0` 的持久进度、付费生产/船体运输/其他动态、自然胜败与奖励、同版九玩法 EXE、美术UI/多尺寸、长跑性能和 Android真机。`CAMPAIGN_QA=1` 不写 campaign.cfg，Steam-disabled不证明奖励。本轮 Git同步不发布新 Steam包。细节看 `HANDOFF_20261007_OFFICE.md`、`DEVELOPMENT_PLAN.md`；历史段落保留，不替代本页新执行入口。

## 5. 已准备的下一计划项

保存结果可观察性的v27b代码与独立源码/API审查在 `qa/zhu_wounded_20261005/proposals/campaign_persistence_observability_v27/`，current=`proposed_b`。先完成本机基线，再实现/运行19条真实ConfigFile故障矩阵；该提案未应用生产，未解析/native/真实写盘验收，不能当作完整持久恢复。失败UI、pending锁与安全重试、真实章节context、终局intent/ack和跨进程恢复继续在完整计划内。
