# 3365 完整源上的 Projectile filter 单文件后继

本目录提供准备与首次冷导入入口。交付时仅进行了 Python AST、`--help` 和默认命名来源检查；没有运行本目录的全量预检、复制、Godot、冷导入或玩法流程。后续真实执行以各批次原始收据为准。

固定祖先是 `20261027_063133_392242bc`，完整身份为 `source-v1:3365e369ba351e9d9593d2324391c7b042a967144df85f1c35f7cb9aad932539`。只替换其已有 `scripts/run_visual_graph.gd`：原 SHA `d7bc061b6ee934c3502451a76043999992029d9342ea7583be6f0c45de8e0213`，候选 SHA `feca8481000d8edb1bab5b00ad6f7c03ffeb9802637a92c714b795eee3a64582`。该文件新增到跟踪清单，得到 26 脚本和 1 个原生 helper；完整工程的文件集合与目录集合不增加，只有 Graph 内容增加 203 字节。先前 25 项、原生文件和所有其他完整源必须逐字相同。

## 入口

在工程根目录运行：

```powershell
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/integration_3365/prepare_projectile.py
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/integration_3365/prepare_projectile.py --help
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/integration_3365/prepare_projectile.py --prepare
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/integration_3365/prepare_projectile.py --import-cold <新批次目录>
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/integration_3365/prepare_projectile.py --check-run <新批次目录>
```

默认入口只读命名脚本、来源清单和完整身份元数据，返回 `metadata_and_named_sources_only`、`full_source_verified=false`、`cold_import_qualified=false`。不会遍历资源树、创建 profile、申请引擎锁或启动 Godot。`--full-preflight` 是显式的完整祖先验证，但不复制或启动引擎。

`--prepare` 在共享引擎锁内完成完整祖先准入，再从祖先完整身份的文件列表复制至全新私有项目。仅替 Graph，不从生产工作目录补取资源，不改原 freeze。来源原件保留于 `preparation_inputs`，不把 EXE 当文本证据再复制；原 helper 作为完整工程原生输入仍按原路径复制。准备结束再次验证来源、生产身份、祖先身份、新完整身份及冷缓存状态。仅自身锁且无活引擎时释放。默认 `--wait-lane 0` 遇占用即失败并留收据。

## 冷导入证明

准备阶段不复制祖先 `.godot/imported`、editor、shader 或其他缓存。新项目 `.godot` 只有程序以排他创建方式写出的 `extension_list.cfg`，恰好注册原有 GodotSteam 与 Steam stats reader。DLL、gdextension 等原生源已包含在完整身份中，不重装或重写。这里的“冷”允许这一份全新原生扩展注册文件，不等于 `.godot` 必须为空；源身份内的正式导入配置仍原样保留。

准备时的 `cold_preparation_inventory.json` **不能**转授以后导入的冷状态。`--import-cold` 另外申请共享锁，完成全部来源、项目、引擎与未导入 stub 准入，创建一次独立 profile 后，在紧邻 `process_step` 前再次检查 `.godot` **完整直接子项**：只允许精确注册文件，任何其他文件或空目录均拒绝。检查后的实际 `cold_before.json` 与首次排他 `cold_import_attempt.json` 都保留；其间只有这些证据写入，随后调用原生 `--headless --editor --import --quit`。

冷导入使用独立四根 profile，显式设置 `CAMPAIGN_QA=''` 与 `STEAM_DISABLED='1'`，并清理继承的外部 QA 环境键。任一已有 import 目录、首次 attempt、generation 或 expected identity 都阻止再作为首次冷导入运行。失败原件不删除；即使失败发生在引擎启动之前，该批已留 import 目录，也不允许重试冒充首次成功。需要重新准备新 freeze。普通 `run_batch.py import` 的收据不能满足本目录的冷准入。

只有真实子进程 PID、退出 0、无引擎错误、原始 log SHA、完整源前后相同、派生 generation/expected identity 相符、引擎及所有来源 pins 相符、子进程已终止、共享 lane 空闲且自身锁释放，冷 import 收据才可 `complete=true/cold_import_qualified=true`。保留首个异常 traceback；后验及收尾异常分别列出，不能覆盖原错误。无法证明自有子进程终态时保留锁。不会结束其他任务的进程。

## 接口与资格

模块暴露 `p/h/require/inside/merge_pins`，供外部宿主复用。`lightweight()` 返回命名来源状态；`preflight()` 返回完整祖先准入；`prepared_state(new_run)` 返回 `run_base/project/generation/pins/content_version/engine/engine_sha256/imports`、`validation_level=full_new_freeze_and_own_import` 和 `cold_import_qualified=true`，仅在新 freeze 自己的首次冷 import 完整通过时成立。`base` 保留 3365 祖先目录，`run_base/project` 指向新工程。

本目录 schema：`projectile_3365_overlay_v1`、`projectile_3365_sources_v1`、`projectile_3365_integrated_manifest_v1`、`projectile_3365_preparation_v1`、`projectile_3365_cold_import_v1`。实际冷前库存 schema 为 `projectile_cold_cache_inventory_v1`，首次尝试为 `projectile_cold_import_attempt_v1`。

冷导入仅证明这个完整源的首次原生导入条件和结果。它不授予自然高俅胜利、完整 61 阶段、19 类故障、公开继续入口、SDK、EXE、人类验收或发布资格；这些仍需要各自原始流程证据。父目录的合成 VisualGraph 模型与本完整 freeze 也分别记账。
