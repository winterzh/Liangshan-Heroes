# 高俅自然败局三进程续玩证据（2026-10-27 05:48）

原批 20261027_054801_b1b7570c complete=true。实际 source941c4786、Steam禁用、私有profile、正常60Hz/1倍速、GL屏幕外；3个原PID 60988 / 74832 / 74456全部exit0、errors=[]、stopped_for=null。原宿主最终完整来源、子进程终态、锁归属与释放通过。各阶段墙钟132.274 / 323.091 / 106.710秒，不作为性能基准。

正式检查数只取三份最终report：50 + 92 + 58 = 200，全部通过，不累加父收据/重复快照。第一进程正常菜单进入Level5，经实际SaveAndExit保存，由AppLifecycle以continue_saved退出。第二进程实际菜单Continue恢复，普通姿态/移动命令后发生真实敌军战斗，原宋江entity3在tick8596阵亡、hp0，原hall1仍存活。第三进程再次实际菜单Continue，得到LOCAL_RUN_TERMINAL；保留菜单、未重建Battle，关闭错误后仍回原菜单。

原移动目标是既有岸军entity42 guan_gong，发令时该波尚未sent。真实最后击杀者为正常生产敌兵entity71 guan_dao，registered=true/faction1；killer_in_original_land_groups=false。不能把此次写成“原42或第一组原驻兵完成击杀”。原采样观察到真实移动和65次HP下降，原生角色死亡未以伤害、传送、阶段或终局注入替代。

LC同token完成gen1 active/none→gen2 terminal/pending→gen3 terminal/applied，gen2/3为同一Intentv2。ACKv2为CAMPAIGN_PROGRESS_NOT_REQUIRED、persisted=false、file_sha256为空、suppressed=false；独立Service回读的无授信proof与token/context/Intent SHA完全一致。terminal_flow的campaign_progress_committed=true表示该失败事务闭合，不代表实际写入战役CFG。

当前完整合同为Level5 contract3：gao_lure/gao_fire/gao_land/gao_capture四项均pending，done_ids=[]、missed_ids=[]、story0/4、corefalse/victoryfalse。未把pending重写成missed或胜利。一次真实stage_metrics以defeat收尾。实际campaign.cfg与CFG事务根均不存在，记录、解锁、奖励均未增长；第三进程完整typed终局状态与第二进程一致。

原槽仍gen1，实际唯一槽record的SHA 0247810b…4786c；LC三份原record SHA分别4d21c5f0…8ab0 / 80844197…b0c7c6 / 3041d8bd…7638e。四个业务文件只流式读取SHA、核目录集合，不复制实际槽或LC载荷；目录无writing/pending。准确完整SHA、大小及来源见verification.json。

raw保留原顶层receipt、3report/3log、4个GD worker与bindings、全部207份运行时runner_inputs。431个来源pin逐项实读匹配；6个EXE只核SHA不复制，来源原字节优先取运行时冻结副本，逐原件映射保留上游来源。报告中typed checkpoint/终局及有限角色/战斗观察是必要私有QA状态，不含完整world/slot原载荷或账号凭据；隔离token无真实账号授信。不存在的controller不补造。

本包只授当前来源的自然败局、真实保存/继续与独立菜单拒旧槽切片。高俅完整胜利、真实SDK、奖励授信、公开续玩、导出EXE、OS键鼠与人工体验、完整19类故障/61阶段、性能和发布均未由此验证；不向其他源码转授。归档没有启动引擎、改原输入或共享锁；之后root可能已运行另一批，其当前占锁不否定本批原终态释放。

manifest.json覆盖除自身外全部文件；source_map.json记录逐原件来源与排除项，summary.json给出限定结论，verification.json包含431pins及四个业务文件的只读核验。全部原件复制后再次比对字节和SHA。
