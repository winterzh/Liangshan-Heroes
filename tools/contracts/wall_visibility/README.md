# 寨墙遮挡的冻结参照

`before_2ea8c69.txt` 是提交 `2ea8c69c97d04e49edc194720a9b47edca33a561` 中完整的 `scripts/liangshan_entrance.gd`，只将换行统一为 LF。SHA256：`96c5d1c144c21bc65f3c9005956a425d24248bc9ebbebb3d0c23853f9b728193`。

`tools/wall_visibility_qa.gd` 在自动加载完成后编译参照，共用同一地图、单位、墙体和门部件。每组先恢复相同颜色/门状态/计时器，再比较整个 `_process` 的输出。计时包括快照准备、原有两组门处理和墙体透明度写入，外部恢复不进入窗口。

参照不进入生产启动；运行输出默认位于忽略的 `.godot/wall_visibility_qa/`。冻结原始证据和计时限制见 `qa/wall_visibility_20260906/README.md`。
