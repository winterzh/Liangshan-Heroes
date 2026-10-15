# 张团练普通武官美术 QA

最终批`20261015_212852_20410266`：真实完整资源PCK604项检查、152张图通过，5472份冻结来源在主工程与隔离工程均零变化。导入、解析、原生纹理参考、完整PCK导出、真实OpenGL窗口五步均退出0、错误0。16张身体/头像纹理完整像素与mipmap匹配原生导入参考。PCK944757368字节，SHA-256 `d677c3341446694b77851e2766c62f8e2b05ae5f5b38001cda383afc447b27ec`。

`final_native/`保留原始输入、收据、日志、纹理参考、report与152图，161份文件逐份匹配工程外原件；所有截图与report SHA一致。`raw_evidence_manifest.json`逐项列出。`adoption_receipt.json`的60份生产/执行器来源匹配实际冻结；作者阶段清单候选标记保留语境，当前资格以此独立采用收据为准。几何构建器用于冻结前写资源并独立只读验证，不冒称在原生步骤执行。

实际敌军张团练四向命中、保留2.8/0.45长兵器时序、0.18秒受击与恢复、四阶段倒地/正常消失通过；实际位移四向、显式56姿势/三尺寸矩阵、图鉴三尺寸四向、四语言小传与29–31回来源、三尺寸敌军查看面板/共用对白头像fixture通过。原Level7施恩继续攻击0、非战斗、空技能且头像没有串用；图鉴同时对照施恩与蒋门神的独立身份。直接目检12张最终代表图，含SE/NW相反接触步、实际命中/倒地、960面板及英日小传，见`visual_review.json`。

原著与保守设计边界见[身份卡](../../docs/ZHANG_TUANLIAN_IDENTITY_20261015.md)及`identity_card_authoring.md`，事实/四语言文字来源见`lore_source_review.json`。`generation_provenance.json`记录23张内置imagegen原始输出、引用SHA及采用/未采用角色；完整请求位于`assets/characters/zhang_tuanlian_officer_sources_20261015/prompt_set.json`。没有脚本补画、镜像、拉伸或重编码PNG。

原参与者/Battle冻结，普通fixture关闭迷雾；敌军单位受控`order_attack`只是测试命令，不代表玩家可指挥敌军或AI验收。部分矩阵为显式采样；常规选择圈、命中闪点、飘字、血迹及此前fixture英雄头像状态保留。对白头像只是共用UI fixture，不是张团练实装剧情。普通持枪/倒地不是鸳鸯楼交椅抵抗或原著死亡的还原。骑兵分类已取消，克制关系因此改变，未宣称平衡验收。没有完整鼠标通关、正常性能、完整续玩、正式EXE、live SDK、Steam或全库美术结论。

复现与设计见[实现说明](../../docs/ZHANG_TUANLIAN_OFFICER_20261015.md)。启动方式不变，包/DLL/缓存/私有档案不进Git。
