# 施恩配套头像QA

最终66项/13图通过，全部原生PNG、报告、导入/解析/纹理参考/完整PCK导出及窗口日志在`native_pass/`。`production_binding.json`绑定本轮实际PCK与当前头像/Art源码；`visual_review.json`保存直接看过的图和审美范围。

实际PCK三张纹理像素/mipmap与原生导入一致，无源PNG回退。实际图鉴三尺寸+英文，原Level7非战斗施恩面板及原对白三尺寸，驻守战普通施恩面板三尺寸、英雄栏绘制路径一致；原图鉴身体动作、外来剧情身份拒绝和邻居人物头像保留。原NPC攻击0/空技能、普通英雄生命210/攻击15/四技能，原单位位置/生命/阵营和地图不变。

`source_checks.json`核对原生RGB及精确参考SHA、唯一UID、来源/生产PNG字节一致、Defs/Unit/HUD/Codex未改。`import_prior/`保存首次导入新import换行被规范化而拒绝的原始证据；`provenance/`保存最终实际执行脚本。

Battle和单位模拟冻结，图鉴/选择/对白调用实际入口，未投递指针或跑完整章节。背景是刻意保留的暖褐纸纹，没有透明承诺或本地抠像。面貌/年龄感为游戏设计，不作原著外貌考据。完整美术、全UI/语言设备、战斗/恢复/性能和Steam仍开放；实现与复现见`docs/SHI_EN_PORTRAIT_WORLD_20261015.md`。
