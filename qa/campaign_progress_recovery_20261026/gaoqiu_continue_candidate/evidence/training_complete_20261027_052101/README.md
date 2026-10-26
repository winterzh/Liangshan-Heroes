# 高俅造船三进程续玩切片（2026-10-27 05:21）

原批 20261027_052101_555727ef 整体 complete=true。源身份 source-v1:941c4786569d5886efbd3537238df853026cc50d0c98d0a1cdb1516c8a8f7964；实际 GL 屏幕外运行，三个原 PID 14364 / 28644 / 39468 均退出 0，errors=[]、stopped_for=null。宿主最终源码身份、子进程终态、锁归属、引擎通道空闲和释放均通过。各阶段 wall time 为 176.885 / 213.472 / 115.693 秒，不作为性能基准。

正式计数只取三份最终 report：65 + 80 + 45 = 190，全部通过。第一个进程经实际 Level5 菜单、普通付费建造船坞 70，仅下达一次造船订单；真实 SaveAndExit 保存未完成队列并由生产 continue_saved 退出。第二进程实际 Continue 恢复并完成战船 71，观察 29 秒没有重复生产，然后真实再次 SaveAndExit、覆盖同槽。第三进程实际 Continue 回读完成状态；它仅验证活动期状态后由 QA 退出，exit_reason 为空是原始事实，不冒称第三次生产保存退出。

战船实际扣费 90 金/65 木、预占人口 3；人口从 active36/queued3 变成 active39/queued0，cap44。order tick2369 到 birth4050 共1681个60Hz tick，即28.0166667秒，较定义28秒多一帧；随后4050到5790共1740 tick，即29秒无重放。唯一下单次数分布1/0/0，原生队列没有单独 job ID，报告按原 producer/key/index/order_tick 绑定，不制造 job ID。

槽 gen1→gen2，第三次恢复仍 gen2；LC 始终同 token、gen1、active/progress none，无终局 intent/ack。当前两个实际槽 record 和 LC record 的 SHA 均与报告吻合，槽目录无 writing/pending，LC 仅 gen1；campaign.cfg 和 campaign_cfg_transactions/v1 均不存在。业务文件只流式 SHA 核验，完整载荷不复制。

raw 保留全部实际运行输入、三个 worker、原三份报告及日志、顶层 receipt。不存在的 controller 文件未人为补造，原始进程收据在 receipt.steps。426 个来源 pins 已实读核 SHA，零差异；运行前冻结 runner_inputs 为原字节，source_map 记录其上游原来源。报告中的 typed checkpoint/training 是必要的私有 QA 有界观察（资源、人口、实体70/71、队列、位置、活跃LC绑定）；保留原字节，不含完整世界或槽 envelope/raw、账号凭据。测试 token 只属此隔离 profile。

资格仅为本候选、Steam禁用、私有无授信活动期造船及真实 SaveAndExit/Continue。未验证完整高俅胜负终局、奖励、终局旧槽拒绝、公开入口、SDK、导出EXE、OS键鼠或人工体验；不转授完整19类/61阶段或发布。人物/关卡完整流程仍需后续独立证据。此包不含业务槽/LC文件、profile、EXE、素材或Godot缓存；归档期间不启动引擎、不修改原输入或共享文档。

manifest.json 覆盖除自身外全部文件；verification.json 包含逐pin、实际槽/LC SHA与边界，source_map.json 给出逐原件来源及排除项。
