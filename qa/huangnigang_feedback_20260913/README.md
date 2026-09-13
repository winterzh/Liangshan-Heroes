# 黄泥冈押队停靠与白胜自动入场：本轮验证

最终同版玩法181项、全新八关Level组件207项、黄泥冈世界恢复专项309项及全新默认经典296项通过，[四批联合核验](validation_summary.json)为`passed=true`。本轮相关专项完成；世界批是缓存复用的七用例子集，不是全新默认37用例完整验收。第一批失败、第二批171项成功中间版保留原结论。[实现说明](../../docs/HUANGNIGANG_FEEDBACK_20260913.md)。

## 验证范围

- `arrival`：正常时钟和真实渲染下，十五人从东路逐人行走，歇脚标记后十五人短暂停稳，杨志盘问时其余十四人持续分散停稳；采样实际位置、身体间距、路径/订单和位移，不以目标点间距代替真实移动。白胜从原入口自动行走，途中不出现酒具，到位停稳1.5秒才落担。
- 同一测试的另一条实际入场路线：真实停止热键接管白胜，等待超过五秒保护计时后仍不被抢回；实际改道、到达后仍不自动返程，再由玩家右键原落担标记完成。没有人物摆位或阶段注入。
- `huangnigang`：既有酒计/强夺与搬担路线回归，酒计入场改为等待自动白胜；其四倍执行只用于功能验证，不用于正常运动表现或玩家通关时长结论。可另选的`zhu_contracts`不在第二批两用例范围，不计作已完成的八关通关。
- ARRIVAL强夺、白胜死亡/节点释放、无自动控制时的手动落担回调和重打均有明确边界夹具。夹具允许冻结、摆位、时间和死亡注入，报告不计作自然通关。
- 死亡接力检查保留旧三项送担/收队断言，并要求旧送担动作退役且未伪完成、同一出口的`_nearest_clicked_action`实际选中新attempt、真实右键和任务计时完成交付，之后重复回调不得重复结算。
- 最终玩法版本的死亡夹具先以实际命令让晁盖、吴用、白胜各挑一担，刘唐保持空手；删除的旧送担处于列表中间，其他两个送担仍待办。死亡前、退役并新增接力取担后、接力新增送担后，逐项读取现存旗标号，要求按动作顺序连续且唯一；另确认其余两担仍归原人并能直接实际交付。不将此死亡/摆位夹具写作自然通关。
- 八关Level组件检查新增三个显式字段；自动开关、指令序号、卸担计时和取消状态往返属于组件夹具，不替代正常命令路线。
- 黄泥冈组件及原六进程链：未入齐押队→自动携酒途中→恢复后自动落担与酒计配合→携担→三担/八人/4项剧情目标胜利→终局旧槽拒绝。逐次对照新增Level字段、白胜订单序号/路径/队列/手动和任务控制状态，保留原角色与景物记录。
- 共享HUD离树守卫另跑同版经典默认流程；旧296项结果不代替本轮重跑，实际数与结果以新收据为准。

## 复现

在checkout根目录配置`godot.local.txt`或`GODOT_PATH`，也可显式传`--godot`。下方四个命令必须串行运行；将示例工作根换为本机独立短路径，每次由驱动创建新私有工程和玩家目录。已有游戏或Godot运行时不绕过独占检查，不杀玩家进程。

```powershell
py -3 -X utf8 -B tools/run_campaign_feedback_qa.py --run --cases arrival huangnigang --evidence-group huangnigang_feedback_20260913 --work-root E:/CodexTemp/huangnigang_feedback_20260913/gameplay
py -3 -X utf8 -B tools/run_campaign_level_state_qa.py --run --work-root E:/CodexTemp/huangnigang_feedback_20260913/level_state
py -3 -X utf8 -B tools/run_level3_world_restore_qa.py --run --work-root E:/CodexTemp/huangnigang_feedback_20260913/world --cache-from E:/CodexTemp/huangnigang_feedback_20260913/gameplay/20260913_134926_3ee0795d --cases level1_component level1_cross_save level1_cross_arrival level1_cross_wine level1_cross_cargo level1_cross_finish level1_terminal_reject
py -3 -X utf8 -B tools/run_continue_flow_qa.py --run --work-root E:/CodexTemp/huangnigang_feedback_20260913/classic
```

玩法证据由驱动归档至本目录下的批次目录；Level组件保留在`qa/campaign_level_state_20260908/`，世界恢复保留在`qa/level3_world_restore_20260909/`，经典保留在`qa/continue_flow_20260909/`各自的新批次。玩法、Level组件与经典使用全新导入；世界专项明确复用上述最终玩法私有工程缓存，最终收据记录1258组素材/导入文件匹配，`fresh_import/full_suite/acceptance_complete`均为false。不能写成默认37用例或九玩法完整验收。

`--cache-from`指向本机保留的完整私有工程目录，不指向已提交的QA报告目录。另一台电脑没有该私有缓存时，省略此参数创建全新独立批次；不能据此改写本轮缓存批的原始标志。

四批原始收据已齐备，根任务使用下列准确路径完成联合核验；无需为文档交接重复运行原生测试：

```powershell
py -3 -X utf8 -B qa/huangnigang_feedback_20260913/verify_evidence.py --gameplay qa/huangnigang_feedback_20260913/20260913_134926_3ee0795d --component qa/campaign_level_state_20260908/20260913_140508_ef6856bd --world qa/level3_world_restore_20260909/20260913_140919_e1abda20 --classic qa/continue_flow_20260909/20260913_141759_58ff5f3a
```

## 第一玩法批：失败，原始证据保留

[20260913_131353_2194d143/receipt.json](20260913_131353_2194d143/receipt.json)为`complete=false`。

- [arrival.log](20260913_131353_2194d143/arrival.log)：真实入场、押队分散停稳、自动落担和S停止/改道路线检查通过。loss/restart后旧HUD离树，延迟`_layout_info_panel`访问空viewport而报错，原生批因此未完整通过。已增加`is_inside_tree()`守卫，须重新验证。
- [huangnigang.log](20260913_131353_2194d143/huangnigang.log)：酒计、强夺实际路线均核心通关；四个边界FAIL分别为已到达夹具未清队列，以及旧送担动作挡住接力新动作所致的交付、三担到齐、提前收队三项连锁失败。短篇loss/restart也触发相同旧HUD布局错误。

两处到达夹具现显式停止原行军订单；生产在携担人失效时取消并移除该担旧送担动作/标记/UI，不伪造完成、不放宽全局最近原点击规则。测试保留原四条断言，另加旧动作退役和新动作真实选中/完成检查。上述修正不改写首批来源、日志或收据，也不将此失败批改称通过。

## 第二玩法批：成功中间版

[20260913_133327_3955a45a/receipt.json](20260913_133327_3955a45a/receipt.json)为`complete=true`，导入、`arrival`及`huangnigang`均退出0。入场105项、短篇66项，共171项通过，包含共享HUD守卫、旧送担退役与两处到达夹具修正。

该批运行时尚未加入多担并行死亡后的旗标重编号及相应测试，因此只保留为该冻结中间版的成功记录。随后发现删掉中间编号后，按`actions.size()+1`新增标记可能与剩余送担标记重号；生产已按剩余动作顺序重新编号，QA改为三担同时携带后删除非末位送担。该差别不改写第二批收据，也不将171项挪算为最终来源通过。

## 第三玩法批：最终同版181项通过

[20260913_134926_3ee0795d/receipt.json](20260913_134926_3ee0795d/receipt.json)为`complete/source_unchanged/lock_released=true`。原生[入场报告105项](20260913_134926_3ee0795d/results/.godot/huangnigang_arrival/all_rendered/report.json)与[短篇报告76项](20260913_134926_3ee0795d/results/.godot/huangnigang_short/all/report.json)均`passed=true`，合计181项，包含最终旗标重编号及多担并行死亡接力验证。

实际正常时钟采样：十五人歇脚后1秒、杨志盘问时其余十四人3秒的最大位移均为0；白胜S接管后的6.5秒采样最大位移为0。应答后48个采样的最小身体余隙为1.2496076像素；这是所取样本的结果，不是全部帧或整关的间距保证。

最终玩法归档包含8张入场PNG。根任务仅目检[03_convoy_resting.png](20260913_134926_3ee0795d/results/.godot/huangnigang_arrival/all_rendered/03_convoy_resting.png)及[07_wine_put_down.png](20260913_134926_3ee0795d/results/.godot/huangnigang_arrival/all_rendered/07_wine_put_down.png)两张对应的私有原图，确认押队停位与落担后画面；不声称其余6张全量目检或性能验收。

## 当前结果与边界

[八关Level组件20260913_140508_ef6856bd收据](../campaign_level_state_20260908/20260913_140508_ef6856bd/receipt.json)已`complete=true`、`fresh_import=true`、207项通过；其中新增自动入场和取消状态两项字段往返是显式组件夹具，不是八关自然通关。

[黄泥冈世界批20260913_140919_e1abda20收据](../level3_world_restore_20260909/20260913_140919_e1abda20/receipt.json)已`complete=true`、309项通过：组件46项，六进程分别20/50/53/77/54/9项。`source_changes=[]`、`protected_player_unchanged=true`、`lock_released=true`；最终缓存匹配1258组，`fresh_import/full_suite/acceptance_complete`均为false，准确范围为七用例专项。根任务另目检本批[原生胜利图](../level3_world_restore_20260909/20260913_140919_e1abda20/level1_cross_finish_report_victory.png)，4/4、0击杀；与玩法03/07合计三张代表图，未扩大为全部世界图目检。

[同版经典默认20260913_141759_58ff5f3a收据](../continue_flow_20260909/20260913_141759_58ff5f3a/receipt.json)已`complete=true`、`checks=296`、`fresh_import=true`、`lock_released=true`。其`screenshots/`下16张截图仅作SHA核验，本轮未人工目检经典画面。

[verify_evidence.py](verify_evidence.py)四参数联合核验已完成，[validation_summary.json](validation_summary.json)为`passed=true`。四批各自来源清单对照当前文件均`changed_sources=[]`，玩法13项、世界90项归档文件及经典16张截图SHA全部匹配，共享锁为空。世界批明确验证玩家目录未变，不为其他收据补造该字段。

本轮25个新增源文本键及繁中、英语、日语75条译文严格构建通过，黄泥冈缺失为0；全局仍有8键缺失，完整性扫描的非零退出不改写成全库补齐。最终通过范围为本轮相关专项，全部图的SHA验证与三张人工目检分别记录。

`.gitignore`的`.godot/`规则也会忽略`results/.godot/`内的真正测试报告和图片。收尾按保留批次逐文件白名单纳入8张具名入场PNG、对应入场`report.json`及短篇`report.json`；不递归强制加入整个`.godot`，不纳入`imported`、shader/editor缓存或图片生成的`.import`旁文件。原始证据字节保护和提交后回读由根任务执行。

旧[9月9日入场记录](../huangnigang_arrival_20260909/README.md)和[黄泥冈世界恢复历史](../huangnigang_world_restore_20260913/README.md)保留原始收据与规则，不能改写为本轮自动入场通过。本轮本地相关验证完成，提交和推送由根任务收尾，实际SHA另按提交及远端回读记录。本轮不改变玩家保存/继续入口，`PLAYER_ENTRY=false`；未打包或发布Steam，不声称真人趣味、性能、九玩法统一或默认37用例整批已验收。
