# 发布候选物理白名单工具

`build_release_candidate_staging.py` 只建立一个供后续 Godot 导出的干净源码候选目录。它不会运行 Godot、不会生成 EXE、不会调用 Steam，也拒绝把候选建在源码仓库或任何 `Steamworks` 目录内。

`export_presets.cfg` 的 `exclude_filter` 只是第二层防漏。即使其中已经排除了 `implementation_20260902/*` 和 `**/__pycache__/*`，也不得把它称为物理白名单。真正的白名单由本工具逐文件复制形成。

## 固定允许内容

- `project.godot`、`export_presets.cfg`、`icon.png`、`icon.png.import`、`icon.ico`
- 五个正式 `scenes/*.tscn`
- `scripts/` 下的 `.gd`、`.gdshader` 和相应 `.uid`
- `assets/` 根目录固定登记的 38 张非 `_raw` 正式 PNG 及其 `.png.import`
- `assets/anim/`
- `assets/campaign/anim/`
- `assets/campaign/objects/`
- `assets/campaign/portraits/`
- `assets/campaign/environment/`
- `assets/vfx/`

运行时资产目录只接受 PNG 及对应 `.png.import`。任何 PNG 缺少导入侧车都会阻断候选。`implementation`、`qa`、`docs`、`tools`、源图、提示词、网页会话和 manifest、JSON、`_raw`、缓存及测试文件不会复制。

因为人物、战役物件和环境素材由字符串动态加载，不能只依赖 Godot 的“选择场景及依赖”。工具会检查代码中的具体 `res://` 引用，并要求所有格式化动态路径都落在固定运行目录内。

## 默认只读检查

候选目录必须由使用者明确指定，且必须不存在或为空：

```powershell
py -3 -X utf8 -B .\tools\build_release_candidate_staging.py --staging C:\Temp\Liangshan_release_candidate
```

默认只把 JSON 报告写到标准输出，不创建目录、不写报告文件。需要查看完整文件哈希表时加 `--show-files`。

当前工程会按预期拒绝提交：环境素材为 `0/69`，严格四向覆盖为 `13/347`，人工发布门禁也尚未建立。

## 提交前的三层门槛

1. `scripts/campaign_environment_art.gd` 必须恰好登记 69 张环境 PNG；69 张 PNG 和 `.import` 必须存在。`qa/environment_art_intake/environment_web_provenance.json` 必须为每张当前 PNG 提供唯一匹配的输出 SHA、网页源图 SHA、提示词 SHA、ChatGPT 会话地址、全通过人工检查及哈希一致的归档 source manifest。
2. `qa/campaign_direction4_coverage_20260902/report.json` 必须通过自身确定性哈希校验，全部输入 SHA 必须仍然一致，并达到 `347/347`；不得有缺图或来源不合规行，四个方向的运行时 PNG 必须全部进入白名单。
3. 完成人工视觉核对（素材近景、方向、阴影和剧情状态；这不等于真人节奏或平衡试玩）后，建立 `qa/release_candidate_gate.json`。它必须绑定本次只读报告给出的白名单树 SHA、四向报告 SHA、环境来源账本 SHA 和至少一份人工证据文件。

门禁格式：

```json
{
  "schema_version": 1,
  "kind": "liangshan_release_candidate_gate",
  "source_freeze_complete": true,
  "manual_review_complete": true,
  "approved_for_staging": true,
  "allowlist_tree_sha256": "<dry-run source_tree_sha256>",
  "direction_report_sha256": "<current report SHA-256>",
  "environment_provenance_sha256": "<current provenance SHA-256>",
  "reviewer": "<reviewer>",
  "reviewed_at": "<ISO-8601 time>",
  "evidence": [
    {
      "path": "qa/<manual visual evidence>",
      "sha256": "<evidence SHA-256>"
    }
  ]
}
```

门禁和证据都留在被排除的 `qa/` 中，不进入候选。工具在复制前、临时目录完成后和原子安装后重复核对源码及全部证据；任何 SHA 漂移都会回滚。

全部门槛通过后才能执行：

```powershell
py -3 -X utf8 -B .\tools\build_release_candidate_staging.py --staging C:\Temp\Liangshan_release_candidate --commit
```

文件先复制到候选同盘的随机临时目录并逐个复核 SHA，再原子替换空目标。完整文件清单写在候选旁边的 `Liangshan_release_candidate.manifest.json`，不会放进候选项目并被打包。写入失败会删除临时候选并恢复提交前的空目录。

这个目录仍然只是“可供导出的源码候选”，不是 EXE 或可上传 Depot。后续 Godot 导出、包内容检查、隔离安装和 Steam 操作必须在全部验收完成后另行执行。

## 自测

```powershell
py -3 -X utf8 -B .\tools\build_release_candidate_staging_selftest.py
```

自测只在系统临时目录构造合成夹具，覆盖路径逃逸、缺失环境图、动态加载漏资源、开发目录误入、源码 SHA 漂移和写失败回滚。
