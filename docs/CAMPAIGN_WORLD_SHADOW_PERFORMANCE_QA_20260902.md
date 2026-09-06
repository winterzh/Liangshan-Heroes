# 共享阴影性能与视觉复核（2026-09-02）

本批只改共享阴影路径：移动单位的接触影和右下投影合并到一个 MultiMesh 实例的两张局部 quad；建筑和资源仍使用原有纹理轮廓阴影。平面地图在 `height_field == null` 时直接返回 identity 坡面基和原位置，等价于原先的零高度采样；有高度场的战役地图继续逐坡取基准。本批未改 Steam、关卡内容或美术资源。

最终源码：`scripts/world_shadow.gd` SHA-256 `629bc58f07d6bbcf1e58f5414e9a7c47921d0a0b44562cac76a3d59279f1e254`。

验证：

- Godot 4.6.3 editor parse 退出 0：`qa/direction4_20260902/shadow_flat_fastpath_final_editor_parse.log`。
- RTX 4060 / Forward+、1280×720 六模式实渲染夹具 105/105 PASS：`qa/direction4_20260902/runtime_world_shadow_flat_fastpath_final/report.json`。战役关确认有高度场和非 identity 坡面；竞技场、遭遇战、AI 遭遇战、自定义防守和场景夹具确认没有高度场、使用 identity 坡面。每个移动单位仍有一层接触影和一层右下投影，且每个 batch 只有一次提交；建筑仍有纹理轮廓。
- 固定顺序完成三组 OFF→ON 独占实战采样，所有六次退出 0、源码哈希未变、开始和结束都没有 Godot 进程。完整原始帧间隔、GPU 状态、P95/P99、draw calls 和活动单位数在 `qa/direction4_20260902/performance_flat_fastpath_recheck/`。

| ON 轮次 | 祝家庄 P95/P99 | 梁山 P95/P99 | 120 兵 P95/P99 | 最大相对同对 OFF P95 |
| --- | --- | --- | --- | --- |
| 1 | 8.825 / 12.019 ms | 12.095 / 15.778 ms | 11.962 / 14.794 ms | 1.0731× |
| 2 | 9.027 / 12.301 ms | 12.423 / 16.168 ms | 11.906 / 14.969 ms | 1.0648× |
| 3 | 9.180 / 12.803 ms | 12.274 / 16.839 ms | 12.168 / 14.570 ms | 1.0576× |

门槛为 P95 不高于 16.7ms、P99 不高于 33.3ms、相对确认基线及紧邻 OFF 基线的 P95 不高于 1.10×。三对均通过；全部 ON 样本中的最大 P95 为 12.423ms、最大 P99 为 16.839ms、最大相对 OFF 比为 1.0731×。每轮 GPU 仍在 P0/P5 等动态状态间切换，因此该证据只证明这套固定短采样满足门槛，不把单次帧时差异归因于一个代码点。

性能目录和最终视觉目录的日志没有 `SCRIPT ERROR`、`Parameter "mesh" is null`、`mesh_get_` 或 `ERROR:` 标记。汇总见 `qa/direction4_20260902/performance_flat_fastpath_recheck/final_summary.json`。

未执行 30 分钟 soak，也未替代真人试玩或全图美术审查。
