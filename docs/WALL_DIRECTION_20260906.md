# 木墙比例、铺设方向与门楼阴影

2026-09-06，基于2ea8c69，继续处理用户指出墙歪的反馈。

当前祝家庄、梁山和驻守的实场景都没有反向墙段。主要画面问题是旧分段固定约3格，把不同高度的同一墙片压进近似宽度；梁山/驻守最高横向轴校正达40.12%。现在按原图端柱的78像素落差、98像素柱高和2:1地面比例计算墙片数量，再连接原有两端。祝家庄17→18片；梁山/驻守32→20片，后两者最大校正降至17.05%，宽高缩放比约0.895～1.220。地形起伏仍需校正，没有宣称零变形。祝家庄最大校正仍15.20%，变化仅长墙分段，不能把驻守的改善数字套用到祝家庄。

另外修复了反向铺设的通用缺陷：先匹配原图与世界的上下柱脚，同一墙段交换起终点后，每个源像素的世界位置保持。六种方向/坡度含水平和近水平，通过真实Vulkan逐像素比较，并确认渲染内容非空。原始木墙PNG字节保持，未重新生成或处理墙图。

门楼阴影原先绕过可见变体，可能用旧图集轮廓套新门柱坐标。现在显式门变体复用实际显示纹理，祝家庄与大名府各自保持自己的来源；其他建筑沿用原来的环境/建筑/地形优先级。门楼原图、柱脚、颜色和尺寸未改。墙线、柱高、不可通行格、门耐久、单位数值和任务规则均保持。

验证：方向与比例32、墙线/遮挡46、门楼30、孙立接应22、宋江动作250，共380项通过；六个固定地图机位输出，代表图另存[QA](../qa/wall_direction_20260906/README.md)。初版夹具引用自动加载时机和SubViewport属性错误已修复，失败日志独立保存，没有计入通过。

PowerShell在工程根目录复现：

```powershell
$godotExe=(Get-Content godot.local.txt -Raw).Trim()
$env:WALL_DIRECTION_VISUAL='1'
& $godotExe --path . --script res://tools/wall_direction_qa.gd
& $godotExe --headless --path . --script res://tools/wall_alignment_test.gd
$env:GATE_ART_VISUAL='1'
$env:GATE_ART_OUT='res://.godot/wall_direction_gate'
& $godotExe --path . --script res://tools/zhujiazhuang_gate_art_qa.gd
$env:RTS_TEST_OUT='res://.godot/wall_direction_contact'
& $godotExe --headless --path . --script res://tools/zhujiazhuang_gate_contact_test.gd
$env:WALL_VISUAL_TAG='direction_review'
& $godotExe --path . --script res://tools/wall_alignment_visual.gd
```

方向专项默认输出`.godot/wall_direction_qa/`，可用`WALL_DIRECTION_OUT`指定。重新运行`Play.cmd`并重开关卡加载源码改动，无新增素材或安装包。截图冻结单位并隐藏HUD/迷雾，仅检查视觉，不表示真人战役、平衡或性能验收。全库四向仍未完成，林冲候选未接入生产；后续教程、战斗恢复、长时性能和发行验收继续。
