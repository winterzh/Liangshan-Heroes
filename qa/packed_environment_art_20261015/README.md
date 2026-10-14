# 环境 PNG 打包校准证据

实现与当前边界见 [说明](../../docs/PACKED_ENVIRONMENT_ART_20261015.md)。

- `baseline_ten/`：十项快活林实际打包反例，资源加载成功，但原PNG不可读，校准失败。
- `baseline_all26/`：全26项同类实际反例，同时给出源码及PCK导入RGBA相同的证据。
- `pixel_binding_lineage.json`：原字节SHA、原RGBA、实际导入RGBA、尺寸及原源码绑定。
- `first_portable_pass/`：修复后的26项源码/PCK校准通过。
- `failure_probe_constant_map/`：工具常量查询编译错误，原失败保留。
- `portable_and_guards/`：26项源码/PCK、源码6项/PCK4项拒错与恢复检查完整通过。
- `minimal_pck_summary.json`：最小PCK范围的阶段收据；完整游戏场景仍未通过。

原PCK、私有工程、用户目录和完整游戏首次失败包保留在各自原批目录，不上传安装包或玩家档案。PNG素材与现有视觉几何没有修改。
