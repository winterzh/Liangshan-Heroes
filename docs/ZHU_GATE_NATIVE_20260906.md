后续：门阴影已统一到实际显示变体，木墙分段也已调整，见[当前修正](WALL_DIRECTION_20260906.md)。下文27项为原门楼批次历史证据，本次门专项为30项。

# 祝家庄门楼与墙线衔接

2026-09-06，接续用户指出“墙还是歪的”。基线57e2512中的木墙柱已竖直，但旧门楼的石翼、栅顶和木墙造型不一致，仅看四个端点对齐不能判断画面合格。本轮先实机比较旧门高度144/192/224.56；单纯拉高使门楼更失真，未采用。

两座祝家庄门现在显式使用一张重新绘制的原生朝向门楼：灰瓦、石门柱、木门和与寨墙相近的木栅侧翼。没有把整排墙换图；木墙的原图、52柱高、逐段布局与既有遮挡规则保持。原图1536×1024为内置生成的RGBA，标准导入为512×341并生成mipmap，原文件没有本地裁切、去背景或改写像素。

`campaign_gate_visual.gd` 记录原图两处石脚(1322,647)/(230,935)，映射到原来的4格门口两端，柱与门框保持竖直。纹理高度180，与木墙桩高进行实机校准。新画面使用原生方向，不进行左右镜像；仍需约10.45%的轴校准，旧图约17.94%，不是声称整幅图零剪切或生成器精确输出2:1。自然地面和画布留白不能当作门脚。

只对建筑贴图使用(0.60,0.70,0.83)颜色校准，压低新木色；名称、血条与选择颜色保持原值。`Unit` 仅一处门贴图绘制传入此色，其他建筑默认原色。大名府门、梁山门及驻守门没有启用新变体。没有改英雄/兵种数值、AI、门耐久、逻辑墙格、寻路或任务规则。

孙立接应依旧需要选中孙立，普通右键3号旗标并完整停留5秒；群选可用，H或新命令会中断，A移动不接任务。成功后偏门按既有剧情退出/隐藏并释放通路，本轮没有新增开门动画。接应测试改为读取实际门楼变体及其脚点，避免继续验证旧图集。

工作区只有本轮明确来源的美术/门配置修改时，检查远端5457de7的改动不重叠后安全快进；随后才增加一处贴图颜色调用，保留所有单位重绘调度修改。最终在整合后源码上通过：门素材/几何/隔离27项、只读来源22项、墙体46项、孙立接应22项、宋江动作250项，另保存并查看三种地图六机位图。详见 [QA、前后图和收据](../qa/zhu_gate_native_20260906/README.md)。

复现（PowerShell，根目录）：

```powershell
$godotExe=(Get-Content godot.local.txt -Raw).Trim()
$env:GATE_ART_VISUAL='1'
& $godotExe --path . --script res://tools/zhujiazhuang_gate_art_qa.gd
py -3 tools/zhujiazhuang_gate_sources.py
& $godotExe --headless --path . --script res://tools/wall_alignment_test.gd
$env:RTS_TEST_OUT='res://.godot/wall_gate_native/contact'
& $godotExe --headless --path . --script res://tools/zhujiazhuang_gate_contact_test.gd
$env:WALL_VISUAL_TAG='native_gate_review'
& $godotExe --path . --script res://tools/wall_alignment_visual.gd
$env:SJ_VISUAL='1'
$env:SJ_QA_OUT='res://.godot/wall_gate_native/song'
& $godotExe --path . --script res://tools/song_jiang_direction4_qa.gd
```

门专项可用`GATE_ART_OUT`指定输出，否则在`.godot/wall_gate_native/runtime`。截图为冻结单位、关闭迷雾/HUD的画面检查，不是人类战役通关或性能验收。没有再次修改木墙段宽度差异，也未关闭全关造型/真人观感验收。全库四向本轮未新增，林冲及其余角色、教程、战斗恢复、长时性能和发行缺口继续推进。没有导出、合并main、创建Release或Steam发布。
