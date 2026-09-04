# 当前本地候选综合门禁（2026-09-02）

## 结论

- `local_code_gate`: **PASS**，94/94 项通过。
- `release_gate`: **FAIL**。这不是可发布候选，不能导出或上传 Steam。
- 真人试玩：未执行，不能得出节奏、难度或平衡结论。
- Steam：本轮未导出、未上传、未检查新 BuildID；物理白名单只做了 dry-run。

完整机器可读报告：`qa/final_local_gate_20260902/summary.json`  
报告 SHA-256：`f23d0068a3c9d846086f538a9d2fa14f6b76e8d7365cb48c583cfaa49a6bb3f7`  
审计工具：`tools/final_local_gate_audit.py`  
工具 SHA-256：`5a89da81882abb589e38dd8b1d93a61a481ac7d3d942d43f7c57b13c11dfeff0`

报告记录了本次读取的 105 个证据、源码、测试日志及截图文件的路径、字节数和 SHA-256，证据集合 SHA-256 为 `f4e779edb4abae46fcc3f35c8e7118cdaec9b3f788879e8ec6c9fd60b89e8e98`。审计不是抄写上游 `PASS`：它重新核对报告结构、当前源码哈希、测试日志哈希、截图哈希、冻结清单互相引用，并现场运行方向素材入口的 63 项正向和 18 项负向自测。同一组输入连续执行两次，报告 SHA-256 均为 `f23d0068a3c9d846086f538a9d2fa14f6b76e8d7365cb48c583cfaa49a6bb3f7`，证明输出不会因运行时间自行漂移。

## 已通过的本地代码门禁

| 范围 | 当前证据 | 结论 |
|---|---:|---|
| 八关主链、自由玩法、非致死与水陆规则 | 八关主链通过；16 组主回归报告通过 | PASS |
| 最终舰队边界 | 最新 11/11，相关复测共 165 项 | PASS |
| 原著文案与旗号 | 72/72 | PASS |
| 环境路由静态契约 | 785/785 | PASS |
| 环境路由运行契约 | 758/758 | PASS |
| 四向素材覆盖审计与冻结链 | 覆盖报告有效；入口自测 63+18 | PASS（覆盖未完成） |
| 全模式阴影视觉夹具 | 105/105 | PASS |
| 固定性能协议 | P95 12.423ms；P99 16.839ms；最大相对基线 1.0731 | PASS |
| 音频退出 | 完整矩阵 8/8；连续复测 9/9；无泄漏标记 | PASS |
| 短时切换测试 | Vulkan 1280×720，90.481 秒，28 次切换 | PASS（仅短测） |
| 物理白名单 dry-run | 只出现已知素材、来源和人工门禁阻断；未复制文件 | PASS（阻断行为正确） |

性能门槛为 P95 不高于 16.7ms、P99 不高于 33.3ms、相对关闭阴影基线不恶化超过 10%。三项均通过。本结果只对应当前电脑、Vulkan、1280×720 和固定自动场景。

## 历史 9/11 失败没有被隐藏

`qa/final_campaign_regression_20260902/summary.json` 仍保留以下两个失败：

- `fleet_killed_before_lure`
- `dead_hull_cannot_lure`

综合门禁只允许 `qa/fleet_edge_fix_20260902/summary.json` 覆盖这两项。覆盖条件包括：历史记录必须仍是同一组 9/11；最新边界测试必须是 11/11；修复范围必须严格为 `scripts/levels/level5_liangshan.gd` 和 `tools/campaign_regression_edges.gd`；两份当前文件及六份复测日志必须与修复报告中的 SHA-256 完全一致。当前这些条件全部满足。旧报告仍作为修复前证据保留。

## 发布阻断项

当前 `release_gate` 必须保持失败：

- 环境成品位图为 0/69。
- 四向精确且来源合规的状态为 13/347。
- 网页端 ChatGPT 来源台账尚未建立。
- 逐图人工视觉门禁尚未完成。
- 正式 30 分钟连续运行未执行；当前只有 90.481 秒短测，原报告明确 `acceptance_eligible=false`。
- 物理白名单只做 dry-run，`commit_ready=false`，没有生成可导出目录。

因此本报告只能说明当前代码、路由、回归夹具、短时稳定性和固定性能协议满足本地门禁。它不说明美术已完成，也不说明玩家节奏和平衡已验收，更不构成 Steam 发布授权或发布证据。

## 复核命令

```powershell
py -3 -X utf8 -B tools\final_local_gate_audit.py --self-test
py -3 -X utf8 -B tools\final_local_gate_audit.py
```

默认命令在本地代码门禁通过且发布仍被已知缺口阻断时返回 0。需要把“可发布”作为命令成功条件时使用：

```powershell
py -3 -X utf8 -B tools\final_local_gate_audit.py --require-release
```

在当前状态下该命令必须返回 3。
