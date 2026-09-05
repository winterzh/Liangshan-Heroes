# 驻守战四向与死亡表现复查修复

日期：2026-09-05。用户授权“你看一下然后改”。本批是本地修复，不是 Steam 发布。
问题原记录保留在 `../skirmish_direction4_recheck_20260905/README.md`，不覆盖旧检查结果。

## 实施结果

| 问题 | 当前处理 | 证据 |
| --- | --- | --- |
| 弓手 SW 站立/迈步朝向与出招相反 | 内置浏览器重新生成 SW idle、迈步；仅替换关联的 4 张条带 | `archer_actual_walk_attack.png`、`archer_revision_verify.json` |
| 行走/攻击裁图适配位移未用于绘制 | Art 帧附加纹理空间位移，Unit 按最终绘制比例消费；同方向 idle 回退同样处理 | `alignment_report.json` |
| 死亡帧锚点切换导致横跳 | 不机械撤销死亡帧 fit shift；分别平移倒下/伏地轮廓，使横向可见轮廓重心与接地线稳定 | 四张 `death_*.png`、独立 alpha 像素测量 |
| 骑兵枪兵仍走剑弧表现 | 两种骑兵明确 spear profile；本批四种完整四向攻击禁用额外整图挥动/旧弧光；旧图与剧情 variant 保留回退 | `unit_runtime_fix_report.json`、`cavalry_actual_weapon_route.png` |
| 致死闪红冻结 | dying 分支继续衰减 `_flash`，不改变受伤数值和死亡时长 | Unit 运行测试、`runtime_observations.json` |
| 活体列表删除后，死亡动画立即丢阴影 | 死者只在共享阴影批次临时保留，不放回战斗列表；随死亡淡出、自然释放后清理 | `report_headless.json`、`report_visual.json` |
| 血迹/掉落物过大且过早显现 | 血迹 .65、长兵器 .45、盔甲 .25、盾箭 .38、布鞋 .30；0.35 秒后用 0.20 秒淡入；取消无来源的方向偏移 | `equipment_scale.png`、`blood_shadow_fix_notes.md` |

死亡接地校准不改变任何位图像素或单位物理坐标。测量取 `alpha > 15/255` 的可见轮廓：
横向 alpha 加权中心目标为纹理 x=128，最低可见点目标 y=210。32 个倒下/伏地姿态的中心
误差均小于 0.51px，接地误差为 0；这是有限姿态的摆放校准，不是骨骼动画或动作连贯性的数学证明。

## 素材边界与来源

- 生成遵循 imagegen 与 computer-use 技能，但按用户指定使用 Codex 内置浏览器，
  稳定会话：<https://chatgpt.com/c/6a9aa67d-22a0-83e9-aeb6-0237a7882356>。
- 新下载原图 `source/archer_sw_idle_step_raw.png` 为 1774×887 RGBA；提示词单独保存，
  哈希和机械摆放参数位于 `../../assets/direction4/skirmish_archer_sw_revision_20260905.json`。
- 本地只取完整 alpha bbox、统一等比缩放、平移和透明补边。弱 alpha 像素也保留；没有
  镜像、旋转、抹像素、补画或调色。虚拟脚下基准不是“此点一定有实体像素”的声明。
- 四张新条带为 `guan_gong_{idle,walk,attack,death}_sw.png`。原出招和倒地姿态逐像素保留，
  只是其引用的 idle 帧随新 SW 待机一并更新。其余 564 张动画 PNG 哈希不变。
- 原四张保留在 `archer_before/`，原动作 manifest 与候选清单不改写。新 revision 与旧
  来源链分别核验，不能把旧审批记录改成新图记录。
- 对齐表放在预加载 `.gd` 中；运行时不依赖被导出规则排除的 QA/manifest JSON。

## 自动测试与助手看图

| 检查 | 本轮结果 | 输出 |
| --- | --- | --- |
| 四种官军严格四向动作 | 257/257，48/48 动作格 | `action_contract.json` |
| 帧偏移、真实 Art 纹理、死亡像素对齐与回退 | 327/327 | `alignment_report.json` |
| 武器、闪红、程序挥动隔离与偏移消费 | 27/27 | `unit_runtime_fix_report.json` |
| 通用方向回归（含 164 类可移动定义） | 67/67，临时代理资源已清理 | `direction_regression.json` |
| 死亡残留无头 | 28/28 | `report_headless.json` |
| 死亡残留 1280×720 Vulkan | 31/31 | `report_visual.json` |
| 战役核心 | 68/68 | `campaign_core_final.log` |
| 新弓手机械复建与范围核对 | 4 张修改、564 张不变 | `archer_revision_verify.json` |
| 新旧来源链破坏性隔离自测 | 11/11，在临时副本中执行 | `tools/campaign_direction4_coverage_audit_selftest.py` 命令输出 |
| 当前全量严格来源覆盖 | 109/347，31.412%；现有 109 个精确文件状态全部来源合规 | `coverage_report_after_revision.json` |
| 真实时间死亡生命周期，1280×720 Vulkan | 59/59 | `realtime_death_report.json`、`realtime_death_final.log` |

助手逐张查看了四种单位死亡矩阵、弓手行走/攻击矩阵、骑兵攻击矩阵和固定五类残骸实景图。
矩阵中的各列是不同单位在指定时间的冻结画面，掉落类型受单位种子影响，不可把多列当成同一
单位的连续录像。`equipment_scale.png` 强制呈现全部五类残骸并与真实死亡 Unit 对照，避免随机
夹具漏测稀有大装备。高地同一死者的尸体/血迹 `render_height` 均为 90.880981，0.71 秒时闪红为0，
死者不在 `Battle.units`、仍在树中且阴影批次保留1个；逻辑变换差不等于屏幕悬空距离。

另跑同四名真实单位的一次性致死、自然时间推进：实际采样0.021/0.409/0.756/1.509秒，
未手调死亡钟、血迹年龄、Unit physics 或阴影更新。在0.409秒时闪红全部为0；0.756秒时四具
尸体仍存、血迹完全显现、死亡阴影保留4个；1.509秒时四尸体自然释放、保留阴影为0，血迹仍存。
四单位位置及地形高度保持稳定。截图 `realtime_death_075.png` 与 `realtime_death_150.png`
是同一批单位的自然时间过程；图像压缩推迟到全部采样后，采样在完整 `frame_post_draw` 边界。
这仍是自动夹具，不是真人试玩。

## 未通过与未覆盖

- 较宽的旧阴影图形夹具仍为 **101/105**，原始失败报告保留在 `world_shadow/report.json`。
  四项是驻守/自定义防守“没有场景物、地面基底必须为单位矩阵”的旧地图假设，与当前有地形高度
  的地图不符；没有把它们删掉或冒称整套通过。本批移动阴影批次、地形投影、死亡保留专项通过。
- 本批没有真人 30 波试玩、兵海性能/长时间 soak、完整阵容 hurt 美术、八方向动画、导出验证或
  Steam 上传。现有两帧行走与三个攻击节拍仍属于有限姿态首批，并非高帧数流畅动画。
- 初次全量审计在 `coverage_report.json` 记录了 108/347：新 SW idle 未绑定 revision，
  被审计正确拒收。补齐与三张动作共用的严格新来源链后为109/347；初次报告保留、不覆盖。
  本批是替换修正，不新增美术状态，故覆盖数量没有增加。
- 实时夹具首跑 autoload 顶层加载错误和第二跑提前于 Node._process 读取阴影统计的失败证据
  均保留；最终改为 deferred load 和完整绘制帧边界后59项通过。前两次是测试夹具问题，
  不能抹去失败记录，也不能冒充又修了两个生产漏洞。

## 复现命令

在项目根目录运行；`$godotCheck` 是本次测试变量：

```powershell
$godotCheck = 'C:\path\to\Godot_v4.6.3-stable_win64_console.exe'
& $godotCheck --headless --path . --script res://qa/skirmish_direction4_fix_20260905/action_contract.gd --log-file qa/skirmish_direction4_fix_20260905/action_contract.log
& $godotCheck --headless --path . --script res://qa/skirmish_direction4_fix_20260905/alignment_contract.gd --log-file qa/skirmish_direction4_fix_20260905/alignment.log
& $godotCheck --headless --path . --script res://qa/skirmish_direction4_fix_20260905/unit_runtime_fix_test.gd --log-file qa/skirmish_direction4_fix_20260905/unit_runtime_fix.log
& $godotCheck --headless --path . --script res://qa/skirmish_direction4_fix_20260905/direction4_regression.gd --log-file qa/skirmish_direction4_fix_20260905/direction_regression.log
& $godotCheck --headless --path . --script res://tools/skirmish_death_remains_test.gd --log-file qa/skirmish_direction4_fix_20260905/death_headless.log
& $godotCheck --path . --script res://tools/skirmish_death_remains_test.gd --log-file qa/skirmish_direction4_fix_20260905/death_visual.log
& $godotCheck --headless --path . --script res://tools/campaign_core_test.gd --log-file qa/skirmish_direction4_fix_20260905/campaign_core_final.log
& $godotCheck --path . --script res://qa/skirmish_direction4_fix_20260905/runtime_probe.gd --log-file qa/skirmish_direction4_fix_20260905/runtime_probe.log
& $godotCheck --path . --script res://qa/skirmish_direction4_fix_20260905/realtime_death_probe.gd --log-file qa/skirmish_direction4_fix_20260905/realtime_death_final.log
py -3 -B tools/skirmish_archer_sw_revision.py verify
py -3 -X utf8 -B tools/campaign_direction4_coverage_audit_selftest.py
py -3 -X utf8 -B tools/campaign_direction4_coverage_audit.py --output qa/skirmish_direction4_fix_20260905/coverage_report_after_revision.json --check
```

`verify` 仅重新生成 QA stage 与验证报告，不再次提交生产 PNG。图形测试由隐藏控制台启动
Godot 自身的测试窗口并自动退出，不操作用户当前游戏进程。
