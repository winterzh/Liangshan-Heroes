# 外部七 GD 加载：seed 名称冲突失败原件

2026-10-27 的实际 PID 13644 在 29.883 秒后退出 2。前五份大名府 GD 与 persistence19 bootstrap 已通过 load/can_instantiate；persistence19 worker 在 480/484 行把 seed() 解析为 Godot 内建 seed(int) → void，产生四条解析错误和两条加载失败。整批 complete=false，未实例化 worker 或执行业务。

74 个运行时 pins 全部从该 run 的冻结 source_inputs（66 项）或 run 内原件（8 项）逐项校验；日志和 runner 另与 receipt 绑定。长路径使用 Windows 扩展绝对路径。原 receipt 记载 child terminal、来源末审、引擎身份及自有锁释放成功，这些是当次历史状态，不是归档时另一批进程的状态。

raw 保存失败原字节，source_map 逐项映射。correction 独立保存事后修正：仅辅助函数定义和两处调用改为 _seed_private_campaign_fixture，sources 仅更新该 worker 的大小与 SHA；逆替换精确恢复旧文件。修正版只做静态/默认轻量检查，归档时未原生复验，不能代替失败输入或取得 9/12 proof、19 案、大名府八流程资格。

未复制引擎、素材、缓存、profile 或存档载荷；引擎仅核 SHA。manifest 固定全部文件（不含自身），不重算完整工程。raw 按 SHA 去重，同一原件的多个逻辑路径均保留在 source_map。
