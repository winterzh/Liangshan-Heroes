# 木墙方向与比例 QA

- 基线2ea8c69；最终输入与证据见receipt.json。四个生产文件：liangshan_stockade、liangshan_entrance分段、campaign_scenery分段、Unit门阴影。未提交的林冲资源生成工具不属于本批。
- direction.log / direction_report.json：32项，六种方向的可见图像逐像素相同；真实三地图的比例/变换约束。forward.png/reverse.png为代表对照。
- alignment.log 46项、gate.log 30项、contact.log 22项、song.log 250项，共380项。gate_report.json与side_gate.png保留新阴影来源的实机证据。
- before_metrics.log / after_metrics.log记录原始数值。驻守/梁山最大轴校正40.12%→17.05%，祝家庄最大15.20%保持；校正不是柱子倾角或FPS。
- before/和after/的同名近景供对照；after/另含祝家庄/驻守远景。原始六机位保存成功的日志在before_visual.log/after_visual.log。冻结单位、隐藏迷雾/HUD；仅视觉复核，不是实际通关或性能验收。
- initial_fixture_failure.log保留首次脚本自动加载和错误SubViewport属性的失败，已修复后重跑，未算通过。

[祝家庄改后](after/zhu_close.png) · [祝家庄改前](before/zhu_close.png) · [梁山改后](after/liangshan_close.png) · [梁山改前](before/liangshan_close.png) · [驻守远景](after/defense_wide.png)
