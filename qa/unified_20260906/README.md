# 两会话统一版本 QA

2026-09-06。在 `8b5c077` 与本会话绘制比例补丁组合上执行。13组运行检查共1,244项、两组原生资源审计共485项，合计 **1,729项通过**。另有完整角色盘点、宋江/林冲36个排帧资源一致性检查、孙立草稿50条哈希校验及正常启动；这些单列，不加进1,729。

`runs.json`列出实际工具、环境参数、耗时、退出码和PASS数；每个目录有原始日志/报告。`receipt.json`保存基线、整合保留证明和关键源码输入SHA256；源代码文本哈希统一CRLF转LF，原生PNG哈希保持字节含义。`lin_sources.json`/`song_sources.json`是只读来源结果，`inventory/`是当前164定义盘点。

`frame_scale/`展示同一真实Unit通过不同Atlas留白绘制：未补偿时缩为101×88，补偿后恢复188×163，所有RGBA通道与原始图零差异。`gate/`保存两门近景/同屏远景，`wall_direction/`为正反铺设像素对照，`lin_chong/`含32个固定姿态的实际Unit绘制。固定夹具不是真人通关录像。

`fixture_errors/initial_frame_scale_compile.log`保留早期夹具过早加载Unit而找不到自动加载对象的失败；最终在自动加载就绪后编译，31项全部通过。此失败不计入通过结果。

`runner.py.txt`是本轮实际执行的顺序记录，依赖工程根目录和现有导入缓存。攻击测试原本默认写入旧QA，本轮结束已把结果移至`ranged/report.json`并恢复旧文件；重跑应明确设置下方 `RTS_TEST_OUT`。驻守路由的参数是目录，本轮原始记录多套了一层`report.json/`，结果完整另存`routing/result.json`；复跑应使用下方目录形式。

## 复现入口

在工程根目录运行，输出放在忽略的`.godot/`，避免改写本快照：

```powershell
$godotExe=(Get-Content godot.local.txt -Raw).Trim()
$env:FRAME_SCALE_OUT='res://.godot/unified_recheck/frame_scale'
& $godotExe --path . --script res://tools/directional_frame_scale_qa.gd
& $godotExe --headless --path . --script res://tools/enemy_candidates_qa.gd
& $godotExe --path . --script res://tools/redraw_stamp_qa.gd
$env:LC_VISUAL='1'; $env:LC_QA_OUT='res://.godot/unified_recheck/lin_chong'
& $godotExe --path . --script res://tools/lin_chong_direction4_qa.gd
$env:SJ_QA_OUT='res://.godot/unified_recheck/song_jiang'
& $godotExe --headless --path . --script res://tools/song_jiang_direction4_qa.gd
$env:TERMINAL_COSTUME_OUT='res://.godot/unified_recheck/terminal'
& $godotExe --headless --path . --script res://tools/campaign_terminal_costume_qa.gd
& $godotExe --headless --path . --script res://tools/wall_alignment_test.gd
$env:WALL_DIRECTION_VISUAL='1'; $env:WALL_DIRECTION_OUT='res://.godot/unified_recheck/wall_direction'
& $godotExe --path . --script res://tools/wall_direction_qa.gd
$env:GATE_ART_VISUAL='1'; $env:GATE_ART_OUT='res://.godot/unified_recheck/gate'
& $godotExe --path . --script res://tools/zhujiazhuang_gate_art_qa.gd
$env:RTS_TEST_OUT='res://.godot/unified_recheck/contact'
& $godotExe --headless --path . --script res://tools/zhujiazhuang_gate_contact_test.gd
$env:RTS_TEST_OUT='res://.godot/unified_recheck/ranged'
& $godotExe --headless --path . --script res://tools/ranged_firing_path_test.gd
& $godotExe --headless --path . --script res://tools/campaign_core_test.gd
$env:DIRECTION4_CONTRACT_OUT='res://.godot/unified_recheck/routing'
& $godotExe --headless --path . --script res://tools/skirmish_direction4_contract_test.gd
$env:DIRECTION4_INVENTORY_OUT='res://.godot/unified_recheck/inventory'
& $godotExe --headless --path . --script res://tools/character_direction4_inventory.gd
py -3 tools/build_directional_spriteframes.py assets/direction4/lin_chong_20260906.json
py -3 tools/build_directional_spriteframes.py assets/direction4/song_jiang_20260906.json
py -3 tools/directional_character_sources.py assets/direction4/lin_chong_20260906.json tools/contracts/lin_chong_direction4_20260906/generation.json --out .godot/unified_recheck/lin_sources.json
py -3 tools/directional_character_sources.py assets/direction4/song_jiang_20260906.json tools/contracts/song_jiang_direction4_20260906/generation.json --out .godot/unified_recheck/song_sources.json
```

未重新通关全部八关路线、重测整体FPS或完成30分钟长时验收。孙立草稿没有进入游戏，也没有运行其尚待资源的QA原型。当前事实与后续优先级见 [PROJECT_STATUS](../../docs/PROJECT_STATUS.md)。
