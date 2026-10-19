# 杨林连续预览 v2：停步收脚

双击[viewer.html](viewer.html)查看。与[首轮连续候选](../yang_lin_continuous_preview_20261019/README.md)相比，停步时不再保留一只脚的长迈步位置：先收落悬空脚，再抬起另一只脚收回。每脚恢复用0.30秒，收脚时有低抬脚弧线；另一只脚固定支撑。目标为身体两侧各20源单位、前后各8源单位，属于持枪站姿的美术选择，不是原著规定。

部件仍用相同原PNG和固定变换，只将重叠顺序改为按整条腿前后排序，再由靴/小腿/大腿依次遮盖。没有重画、清洗透明杂点、逐帧缩放或修改旧证据。膝踝接缝仍需美术返修，不把遮盖调整当作解决全部关节问题。

## 实际结果

[运行报告](actual/run_v1/browser_report.json)记录13秒、810次实际绘制，包含三档速度、两次停走与最终落脚。8张画布PNG、6张从实际视频解码的收脚中途图及完整页面已目检；[连续画布视频](actual/run_v1/continuous_canvas.webm)已保存，没有完成人工全视频验收。

[独立矩阵与媒体复核](actual/run_v1/independent_verification.json)检查1616条绘制记录、212组支撑参照，视频解码376帧，时间戳跨度12.918秒。[停步复核](actual/run_v1/recovery_verification.json)覆盖三个1秒停止区间、四个方向：每次最多一脚收回，另一脚保持落地，地图位置不变，最终两脚回到紧凑站姿。单靴底参照点稳定不证明完整鞋底接触、脚掌滚动或人体重心合理。短于收脚时间的急停再启动未专门验证。

来源alpha边缘资格、自然步态、真实Unit/Godot、方向切换、地形、普通/获救/被缚回归、图鉴/HUD、包内与性能均未验收，本批生产采用0。人形和一杆浑铁笔管枪沿用第44回书证，服饰、分层和站姿属于解释；不据绰号增添原著设定，不改变现有角色状态或技能。

## 工具与冻结

HTML已嵌入原图，无依赖即可看。自动运行使用已有Edge、工程外独立profile及私有Playwright 1.64.0，未修改用户登录profile或系统配置。工具依赖、profile不进Git；原公孙胜Godot单一等待队列与外来占用标记保持。

```text
python -X utf8 -B qa/yang_lin_continuous_preview_v2_20261019/run_playwright.py --deps <私有SDK目录> --output <全新工程外证据目录> --browser-exe <已有Edge路径>
python -X utf8 -B qa/yang_lin_continuous_preview_v2_20261019/verify_runtime.py <该证据目录>
python -X utf8 -B qa/yang_lin_continuous_preview_v2_20261019/verify_recovery.py <该证据目录>
python -X utf8 -B qa/yang_lin_continuous_preview_v2_20261019/decode_recovery_frames.py <该证据目录>
```

另需已有Pillow与ffprobe/ffmpeg。归档保留实际执行输入、DOM和原始POST，逐文件摘要见`actual/archive_index.json`。冻结后构建器拒绝覆盖；后续改动另建版本。129/16/81与HUD以及16份未验证本地公孙胜文件保持，main/Steam未操作。
