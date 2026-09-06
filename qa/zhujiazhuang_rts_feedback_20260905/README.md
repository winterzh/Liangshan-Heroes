# 祝家庄试玩反馈验证 · 2026-09-05

基线 `28ad7d7be761a8c1b64f821d84c876e43ddf74af`。用户反馈门朝向不符、守军近战/英雄站桩、两英雄即可杀穿。本轮保留共享英雄、兵种和建筑数值，修正朝向、守备/追击/施法逻辑，并在两入口放置现有箭楼。机制见 [实现说明](../../docs/ZHUJIAZHUANG_RTS_20260905.md)。Godot为 `4.6.3.stable.official.7d41c59c4`，图形为RTX 3070 Ti / Vulkan / Forward+。

最终140项自动检查通过（包含1项测试执行完整性），四张门体对照图保存成功且目检：19项守军/施法/命令检查、两种双英雄探测各2项、两条带兵路线各5项、39项工程/模式回归、68项核心回归。最终日志无脚本或解析错误。

本次双英雄直接冲门24.07游戏秒时林冲阵亡，另一路26.87游戏秒时宋江在外营阵亡；均没有攻破庄内大营。带兵正面313.33游戏秒、清1塔、34次生产排队；内应396.00游戏秒、清2塔、45次生产排队，均实际生产3次投石车、2次撞车，完成核心通关。内应入庄时正门完整，演义3/3；正面演义2/3。测试以4倍游戏速度执行，单次回放数字可能受帧序影响，不能当作真人时长或统计平衡结论。

## 验证组成

| 文件 | 范围 |
|---|---|
| `guards.json` / `guards_console.log` | 三类守军无攻击指令主动接近并造成伤害、目标离开回防、相同目标再入侵；敌将施法时序与真实结算；玩家停止/据守/移动语义。18个行为检查及1个执行完整性检查 |
| `hero_direct.json` / `hero_direct_console.log` | 宋江、林冲不造兵、不建造，直接进攻正门的实际战斗探测 |
| `hero_inside.json` / `hero_inside_console.log` | 同样两英雄先攻击外营、计划接孙立走偏门的实际战斗探测；可能在外营就失败，不声称已走完整内应流程 |
| `direct.json` / `direct_console.log` | 正常采集、训练、建造、战损补充，正门攻入，优先清入口箭楼、攻大营、护送并收军 |
| `inside.json` / `inside_console.log` | 正常经营的孙立偏门路线，记录正门完整时军队进入庄内，清箭楼、攻营、救援回营 |
| `contracts.json` / `contracts_console.log` | 原39项工程/经济/人口/门体寻路、驻守和AI对战模式切换、其余七关启动检查 |
| `core_console.log` | 既有68项核心检查 |
| `main_gate_aligned.png`、`side_gate_aligned.png` | 新门体朝向的两张1280×720实机图 |
| `*_gate_original_axis.png` | 同一当前场景里仅关闭门体镜像的图形对照，显示此前轴向问题；包含新箭楼，不是旧版本整体截图 |
| `visual_console.log` | 图形设备、四张截图保存结果 |
| `guards_before.json` / `guards_before_console.log` | 最初诊断中三类原地据守均不主动走近/造成伤害，共6项失败；后续夹具扩充，不能把它与最终19项当作完全同版对照 |
| `receipt.json` | 所列生产输入/工具按CRLF转LF后的SHA-256，QA日志、JSON和PNG按原始字节SHA-256；不包含自身、缓存或玩家存档 |

## 对照方法与边界

双英雄探测不生成援军、不更改血量/伤害/金币、不强制结束战斗。只控制两个开局英雄下攻击/移动指令和正常加点，开局四兵留营，工人按实际开局采集。未专门优化手动放技能、拉扯和高手绕路；失败只说明这些简单强冲策略被实际战斗阻止，不证明所有少兵玩法都不可能通关。

带兵路线真实扣费训练，包括撞车和投石车，先拆入口塔。测试只判断实际入口塔已毁、器械确实生产，并不伪造伤害归因或声称全程只靠器械造成伤害。完整通关仍不代表真人趣味、时长或所有难度组合已验收。

守军测试是明确隔离的行为夹具：其他单位暂停物理并改同阵营排除干扰，把无反击的宋江放到守军120像素外；仅该观察目标临时有2000生命，确保能持续观察扈三娘打人和回防。它不作为平衡证据。施法时序夹具仅将已存在抬手计时推进到0，确认AI不能改掉待结算序号、原技能真实伤害并进入冷却。真实路线和双英雄测试均不使用这些夹具改值。

截图临时关闭迷雾并显式设定测试单位可见，用于门体/墙轴检查；正常游玩仍保留迷雾。只镜像建筑外观和对应纹理阴影，血条/名字不翻转，3×3门体阻挡不变。截图瞬时FPS不构成长时性能证据。

## 调试记录

- 单改守备姿态后发现慢兵接近目标时仍提前放弃：旧1.1秒判断只看目标潜在速度；现在每取得12像素接近进展重置放弃计时。回防后再次接敌也重新计算进展。
- 扈三娘反复抬手但不出招，定位为AI决策早于待结算队列，新的施法序号淘汰了上一招。待结算完成前禁止重新起手后，技能与普攻实际造成伤害。
- 早期图形工具只调用show，没有同步测试单位的fog_visible，导致下一帧被隐藏；已修正并重新截图，空门图未纳入交付。
- 早期观察目标生命不足，被修复后的敌将真实击杀后读取失效对象，工具报错；改为明确的高生命观察夹具，双英雄真实测试只对失效对象安全读0。最终验收同时核对预期断言数和日志中无脚本错误，不能只看JSON的passed字段。
- 最初带兵策略忽略箭楼，造成长时间战损；改为清入口塔后再打大营。内应路线还会清掉覆盖大营前沿的正门箭楼，保留两塔交叉火力的实际影响。一次内应回放选到器械当救人办理者而卡住，改为从关卡允许的英雄/步兵名单选择。均为测试操作策略修正，未改游戏目标规则或给路线补充资源。

## 复跑

在仓库根目录使用已配置Godot 4.6.3：

```powershell
$godotExe=(Get-Content godot.local.txt -Raw).Trim()
$env:CAMPAIGN_QA='1'
$env:RTS_FEEDBACK_TEST='guards' # 或 hero_direct、hero_inside
& $godotExe --headless --path . --script tools/zhujiazhuang_rts_feedback_test.gd
$env:RTS_TEST_OUT='res://qa/zhujiazhuang_rts_feedback_20260905'
$env:RTS_TEST_ROUTE='direct' # 或 inside、contracts
& $godotExe --headless --path . --script tools/zhujiazhuang_rts_test.gd
& $godotExe --headless --path . --script tools/campaign_core_test.gd
& $godotExe --path . --script tools/zhujiazhuang_rts_gate_visual.gd --resolution 1280x720
Remove-Item Env:CAMPAIGN_QA,Env:RTS_FEEDBACK_TEST,Env:RTS_TEST_OUT,Env:RTS_TEST_ROUTE -ErrorAction SilentlyContinue
```

自动工具会重写同名QA文件；复跑后重做收据。`CAMPAIGN_QA`避免写玩家战役记录；无Steam导出/上传，未合并main。真人需重新启动源码游戏并重开本关加载新逻辑。
