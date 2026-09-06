# Battle Fog 局部值 QA（2026-09-07）

run `20260906T162217847550Z` 使用实际 Godot 4.6.3，PID 4652、exit 0；182 条断言通过，严格日志、来源/玩家保护与锁收尾通过。分组为 source 13、environment 3、behavior 30、rejection 51、json 31、fixture 54；辅助断言不等于独立场景。runner 172 条 other 中仍含 3 条来源汇总检查。另有 14 条 controller 合成报告拒绝，属于准备证据，未计入 182。

[current_qa_summary.json](current_qa_summary.json) 与 [evidence_review.md](evidence_review.md) 给出完整证据链；原始七文件在 [run 目录](runs/20260906T162217847550Z/report.json)。report 的原路径即本次 run/report.json，未从整个用户目录复制。configuration/manifest 中保留历史绝对私有路径，仅为当时的来源记录。

真实对象的已释放 typed Map 拒绝、float32 输入位值与真实 JSON 往返、float64 相位、4096 格预算和非方形尺寸通过。这仍只有 Battle 迷雾五值+地图宽高的 capture/validate，未接入赋值恢复、导航、Unit/效果引用、绘图重建、快照屏障、RNG/磁盘或完整续玩；不是性能验收。

preparation 保存旧 README/pins/字段和 QA 合同原文，未回写准备期状态。[controller_review.md](controller_review.md) 是实际运行前的只读评审。测试源码与完整原文依赖另存于 `tools/contracts/run_battle_fog_20260907`，其 README 解释原路径还原与受控启动。
