# 聚义厅可招募集合修复

2026-08-31。跨模式美术验证实际发现竞技场菜单列出卢俊义、石秀等角色，但正常`queue_train`按聚义厅原`produces`拒绝，返回`unsupported`。原菜单额外遍历全局Defs，且没有限制聚义厅，普通兵营也会显示英雄分类。主任务明确授权本轮公共修复，不绕过招募入口完成美术测试。

## 改动

仅修改`scripts/battle.gd`生产菜单相关代码。新增`_full_roster_hall`与`_trainable_keys`，供`train_menu`、`_train_block_reason`和`_selected_producers_for`共用。

基础名单仍为该建筑的`setup_def.produces`副本。只有`uses_full_roster()==true`且建筑键为`hall`时，追加当前本局`_defs`中有`hero_trainable`标记的角色，去重且不写回定义；分类菜单也只用于该聚义厅。兵营、其他建筑与普通模式不会得到全名册。时代、资源、人口、队列、唯一英雄、英雄总数、施工与研究中的拒绝顺序均保持。

晁盖默认没有`hero_trainable`，保持不可招募；不能为了测试通过为他增加永久或局部例外。竞技场阮小二的既有键是`ruan_brother`，黄泥冈的`ruan_xiaoer`是关卡局部定义，不据此给自由模式增添别名或造型。

修改前文件和SHA256在`qa/web_chatgpt_art_20260831/before/battle.gd`及`battle_sha256.json`，差异在同批目录`battle_roster.diff`。未覆盖既有备份，未修改Defs、技能、数值或Steam文件。

## 实际回归

新增`tools/campaign_roster_training_test.gd`。Godot4.6.3，headless、`--fixed-fps 60`，脚本4倍时间，`CAMPAIGN_QA=1`。最终77/77断言通过、退出0，没有SCRIPT ERROR或退出WARNING。

证据：`qa/web_chatgpt_art_20260831/roster_training_verified.log`和`roster_training/report.json`。

- 真实聚义厅分类分页列出卢俊义、石秀、吴用、刘唐、阮小二、白胜；六人通过正常`queue_train`/`queue_train_multi`扣费排队并实际出生，没有直接spawn测试英雄。双厅选择时把卢俊义派到较短队列，另一厅已有同名英雄排队或出生时拒绝重复。
- 竞技场兵营仍只有原四种兵，没有英雄分类；英雄请求拒绝且不扣资源、不入队。晁盖同样拒绝。
- 当前本局临时取消卢俊义`hero_trainable`的明确边界夹具会同步影响菜单、校验和多选分配；恢复后不污染`_defs`或全局Defs。测试额外建筑只用于双厅/兵营路由，不代表玩家建设过程。
- 无效建筑、未完工、研究中、时代不足、资源不足、人口不足、八格满队列、跨厅重复英雄以及自定义据守英雄上限仍正常阻断，失败不扣资源或入队。排队夹具用正常撤单退费，正常招募费用不变。
- 据守、1v1、自定义据守分别重建场景，厅菜单与可招募集合仍是原`produces`，卢俊义不获扩展资格，原可招募宋江仍可办理。自定义据守用当前会话配置`hero_cap=1`验证上限后还原配置。
- 跨四模式后全局`Defs.UNITS`、本局定义、建筑`produces`及`campaign.cfg`存在状态和字节均未被生产过程改变。

首轮`roster_training_attempt1.log`与`roster_training/report_attempt1.json`保留。该轮测试误用了不存在于竞技场的`ruan_xiaoer`键，出现脚本错误与执行不完整，不能计为通过；已改为已有`ruan_brother`并补缺定义防护，没有修改生产数据掩盖错误。

这是生产功能与边界回归，不是完整经济平衡、真人试玩或渲染性能验收。同日大名府图形验证已实际通过正常聚义厅招募卢俊义/石秀，再返回战役检查造型复位；最终头像同步轮129项与12张原生截图单列于`CAMPAIGN_DAMING_PRISONER_ART_QA.md`，旧105项证据保留，不把本次headless结果充作图形证据。
