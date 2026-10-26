# 连环马自然败局三进程原始证据（2026-10-27 02:08:34 批次）

原批次：.godot/lianhuanma_natural_loss_20261026/20261027_020834_fe953cf1。

三个实际进程 PID 67156、23132、72108 均原生退出 0，55 + 92 + 58 = 205 项断言全部通过。原收据 complete、初末来源核对、子进程终态、自有锁确认和释放均为 true。本目录只做完成批次的独立核验归档，没有运行引擎。

来源为 source-v1:d7f2258b8be6f77e3577ff9c3b018427c805c84385e86f1daa54aaa49cc30dac，continue_binding_integrated_manifest_v1 含 23 脚本和一个 helper。manifest SHA-256 为 06f2aa5b50e30b4c711a0ea22e1d01253b3fed4d06db47b706abeb74bac771f0。归档重新读取了 132 个运行 pin，全部匹配；3 份报告和 3 份日志绑定、23 脚本、引擎及 helper 哈希一致。完整素材树初末核验采用原宿主记录，归档不再重读 2.4 GB 素材树。

实际完成的路线：

- 正式菜单进入 Level4，普通付费训练后，在训练尚未完成时真实暂停、保存退出。AppLifecycle 以 continue_saved 结束首进程。
- 第二进程点击实际 Continue，精确保留队列、人口、资源、物理 tick、原 token 和暂停状态。继续后通过普通命令卡切到被动态，仅下达一次移动到现有敌军区域的命令；没有移动位置赋值、注入伤害、修改敌军、跳过教场或直接结束战斗。
- 原宋江从 280 HP 发生 8 次观察到的下降，真实移动约 1153.78 像素，tick 1592 被仍在注册表中的敌方呼延灼（entity 48）击杀。原聚义厅存活，生产 died 回调自然进入败局，异步事务和可见终局 HUD 完成。
- 第三进程真实菜单 Continue 返回 LOCAL_RUN_TERMINAL，显示错误面板并关闭返回原菜单，没有重建 Battle；原槽、LC、CFG 状态、proof 和奖励均保持。

完整 contract 2 目标快照是 done 0、missed 0、pending 4：教场、十二骑下钩、韩滔、呼延灼四项都保持实际 pending，未擅自改写为 missed。LCv3 同 token 完成 gen1 active → gen2 terminal/pending → gen3 terminal/applied；Intent v2 victory=false。严格 ACK v2 为 CAMPAIGN_PROGRESS_NOT_REQUIRED，persisted=false、file_sha256 为空，proof 是实际 Service 独立回读的 uncredited handoff。

新鲜私有档案的 campaign.cfg 原本不存在，败局及独立拒槽后仍不存在；records 为空、unlocked 1，奖励计数和记录无增长。该用例证明缺失 CFG 保持缺失，没有覆盖已有非空 CFG 的败局保持。通用 Flow 返回字段 campaign_progress_committed=true 只表示终局协调阶段成功，不表示败局写入 CFG。原始报告中的真实 stage_metrics 仅一条 defeat；游戏时间约 26.3167 秒，墙钟记录不作为性能结论。

原保存槽 SHA 为 7fc94b04df5cbdca39bb48b9a8d1f1f44851ca29f733d5cfc46f7784d31ef6b7。第二与第三进程 terminal_checkpoint、typed exact_terminal 相等；归档时再次只读核验一代原槽、三代 LC 哈希及 CFG 缺失，未复制私有记录载荷。

raw/run 保存原收据、三组报告/日志与实际 worker/bindings；raw/inputs 保存宿主、公共绑定、4 个 GDScript、运行时 README/provenance、候选来源和导入等原字节。相同 SHA 的来源去重，全部原路径见 source_map.json；4 个 EXE 只核哈希并排除。manifest.json 覆盖除自身外的全部归档文件。没有复制 profile、完整槽/LC/CFG 记录载荷、assets、缓存或二进制。

本批仅授予私有入口源码工程屏幕外 OpenGL 的自然败局与独立拒槽自动回归资格。胜利资格属于另一批；公开 Continue、发行 EXE、真实 Steam SDK、人工键鼠与视觉体验、性能、19 类故障全矩阵、61 阶段完整验收及发布均未授资格。
