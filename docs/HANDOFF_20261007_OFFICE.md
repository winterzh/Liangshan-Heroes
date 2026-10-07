# 2026-10-07 办公室续做交接

仓库 https://github.com/winterzh/Liangshan-Heroes.git，分支 `codex/sync-20260905-stable`。本轮开始前远端独立回读为 `91865a638c4401c2a2449e7334b3794f10087fef`。当前 v24s 完整三进程与最终源码/原生核对通过，四文件修复、完整 QA 和后继提案按白名单增量同步；本轮提交以远端 stable 最新 SHA 及同步收据为准。最终提交以远端分支及同步收据为准。用户要求继续推进到香港时间 2026-10-08 06:00，届时更新实际进度并收尾。

## 已完成并同步

Root/Visual/Core 已接入实际高俅与大名府关卡，恢复同一新世界的 Mission/Level/收兵按钮引用。修复高俅永久静态码头节点的原生处理位，以及任务面板空构造器入树、原按钮回挂、文字和本地化绑定的填充顺序。原完整字段比较、所有权及激活门槛保留；公开战役续玩入口关闭。

| 验证 | 已通过范围 | 主收据（qa/zhu_wounded_20261005） |
| --- | --- | --- |
| 地图/场景 | 高俅、标准地图、大名府及旧六章14案281项 | campaign_scene_closeout_v23h.json |
| Core初态/高俅收兵组件 | 双关43、按钮32、旧六章132，共9案207项 | campaign_core_initial_qualified_v24i1.json、campaign_core_end_qualified_v24g2.json、original_world_complete_review_v24l.json |
| 独立任务界面 | 同进程218、独立重启130项 | campaign_presentation_qualified_v24j.json |
| FX组合 | 同进程650、独立重启31项，保留17类负例 | fx_partition_qualified_v24n1.json、fx_partition_caller_migration_v24n1.json |

这些分别限定范围的组件资格不能相加当成完整动态战役验收。高俅按钮结局由组件夹具创建，不证明自然通关或奖励一次。Presentation/FX公共测试入口已迁移。5039行冻结输入为5035不同路径，4个重复行内容一致，不能把行数当作唯一文件数。

## 保存边界修复已通过，原失败证据保留

大名府通过正常移动进入办理半程及HELD，首次真实 `Session.save_held` 返回 `NONCANONICAL_RECORD`，B/C未启动。v24p只读取同一失败事务pending proposal，保留两个完整字符串：仅196个归属整数变为JSON浮点，UTF-8增加392字节。原规范校验正确拒绝了变化后的记录；没有重捕世界替代失败数据或重试不安全写事务。

四文件候选在 `qa/zhu_wounded_20261005/proposals/native_ownership_json_v24q`，来源见 `native_ownership_json_candidate_v24q.json`，设计见 [NATIVE_OWNERSHIP_JSON_REPAIR_20261007.md](NATIVE_OWNERSHIP_JSON_REPAIR_20261007.md)。只在固定Map/Scenery读取边界检查有限性/整数性/节点范围后还原Gao/Daming归属索引；原生写入仍要求整数，原全量Scenery验证、canonical字节、SHA和修订链保留。旧章/标准场景不转换。helper UID为原生生成，需逐文件显式同步，不能受默认忽略遗漏。

v24s 新整批已通过 import、负 profile guard、固定 JSON 11 案 533 项、原 OwnedSlot 76 项及完整 A/B/C。A PID202132 保存世代1并退出，39项；B PID216580 完整安装、正常办理完成并保存世代2，351项；C PID215764 安装世代2、正常120物理步且不重复效果，342项。完整 world/packet/22 sections、Root/Mission时钟、Campaign选项、设置、profile flag、local binding均核对；最终raw5041/distinct5037/完整runtime5102与原生依赖零漂移，profile/锁已释放。主收据为daming_admission_continuation_qualified_v24s.json。四生产文件据此同步；公开战役继续入口关闭，单人撤离/战役进度写盘/自然通关/奖励仍未资格。

v24r/r2原错夹具、A32成功后B重复capture_rejected测试错误、共享引擎中断的原producer/profile/log均保留。v24s只修测试自己的成功/拒绝一次性监听生命周期，未放宽原全量比较。外层Slot身份类型守卫另为v26未应用/未原生提案，不把本次固定Map边界资格扩展为全Slot负例资格。

## 明天开始

在办公室独立checkout核对身份、分支及未提交改动。干净且未分叉时：

```powershell
git status --short --branch
git remote -v
git switch codex/sync-20260905-stable
git pull --ff-only origin codex/sync-20260905-stable
```

未提交修改或分叉先核对来源，不自动stash/reset。共享外层目录不是checkout，按 [SOURCE_SETUP.md](SOURCE_SETUP.md) 使用既有独立checkout。Godot路径通过被忽略的godot.local.txt、GODOT_PATH或参数配置，本批固定4.6.3；缺缓存重新导入。包、玩家存档、登录数据和.godot不通过Git分发。

QA绝对E:/路径/PID是历史证据，不能直接作为办公室参数。world/pending文本来自隔离原生夹具，不是玩家数据。办公室复验从对应harness、新工程外输出目录及私有profile开始，重新建立source/engine/native哈希，不复用旧写锁/失败profile，不覆盖已执行producer。88个 `daming_qualified_metadata_v24o4` .import/.uid是原合格工程普通源码伴随文件，不是.godot缓存。

本次 v24s 已终止成功，原profile只保留证据、不得复用。未来仍在运行的家里后台只由本线程回读，办公室不要重复启动同一运行。共享Godot等自然空闲，不控制或给盲盒任务发消息。占用中断与工程失败分开记录；真实断言失败须先修复再建新sibling。

## 后续顺序

1. 在办公室 fresh 私有工程/profile复验已通过的JSON边界和办理半程三进程；公开入口仍须其他动态分支全部通过后再评估。
2. 单个获救者安全撤离仍FIGHT的合同修复：v25提案和路线/四进程runner已存入QA，尚未apply/原生，已采纳s监听后继，须完成负例门禁及实际路线验收。限定实际Lu/Shi，严格stop字段、selection/caster清理、另一演员live/root/active及同token Mission安全事件。实际保存/独立继续后等durable terminal完成才称本地结算成功；Steam-disabled批次不证明Steam奖励。
3. 双关其他动态、付费生产、船体/运输、旧章动态、自然胜败及奖励一次。
4. 同版九玩法/实际发行EXE；完整美术动作/拥挤UI/多尺寸流程；正常时钟同负载约10分钟性能、长帧/内存/切换回收；Android2.0.1真机DPI/安全区/触控/持续性能。

单人安全撤离的完整设计见 [DAMING_SAFE_RETREAT_DESIGN_20261008.md](DAMING_SAFE_RETREAT_DESIGN_20261008.md)。`CAMPAIGN_QA=1`跳过Campaign写盘，所以当前runner不证明战役进度持久；正常私有profile须另测。

全开发计划和长期平台方向保留。源码同步与Steam发布分开；本轮不发布新平台包。Steam已上线Build25768878及四语公告见 [STEAM_UPDATE_20261007.md](STEAM_UPDATE_20261007.md)。此前约1.68GiB重复imported清理已完成，不重复执行。
