# 实际PCK五类动作与窄窗口英雄HUD

最终`native_pass/`原始报告为700/700通过、98张PNG；原导出`pack_export/`为699项通过，最终复验只加强实际剩余冷却检查，复用同一SHA的真实完整资源PCK。25张人物纹理像素/mipmap与本轮原生导入逐项一致，原PNG在包内不存在；实际攻击/受击/死亡回调、待机/步态、原角色保护及中文/英文三尺寸切换通过。

Viewport GUI事件验证物品弹窗、信息开关、原Q加点热区；八人多选实际滚轮4次后末项完整可见，剩余冷却0、未瞄准。直接看过的最终六张图与限制见`visual_review.json`。`production_binding.json`记录包字节/哈希、HUD源码SHA、5258项原导出源集合、全部最终源字节和原件绑定。

`pack_export/`保留原导入、解析、纹理参考、导出、699项窗口报告等原记录；`native_pass/`完整保存700项最终原始日志/报告/98图。各目录`archive_manifest.json`逐文件与外部原件SHA相同。`provenance/`保留实际执行的原导出探针、最终探针和复验Python原文，不用新代码改写旧报告。

`native_prior_cases/`保留三个旧批日志、报告和原探针，失败原因在实现说明；全部旧PNG/PCK和冻结工程仍保留外部。`candidate_before_square_minimap.png`为首个实景候选的小地图拉长画面，未覆盖；最终小地图保持方形。

包在`D:/CodexTemp/shi_en_packed_hud_20261015/20261015_133648_2dd115e9/clean_runtime/LiangshanShiEn.pck`，884673168字节，SHA`19851ba8b665a87e3e5e2333459a8d14454aa7b78e4b0a656bf84462d34eba94`。包不入Git；最终复验使用同字节只读硬链接，前后两路径SHA一致。玩家资料未使用，Steam禁用，共享Godot串行执行。

详见[实现与复验入口](../../docs/SHI_EN_PACKED_HUD_20261015.md)。这是实际资源PCK的局部原生验证，不授予发布EXE、live SDK、Steam、全章、全游戏、美术或性能完成资格。
