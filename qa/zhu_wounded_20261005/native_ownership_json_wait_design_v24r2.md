# v24r2 未执行候选

本候选从已经执行的 v24r1 精确派生；只加强自然空闲等待，保留相同源码资格与完整 5102 文件安装身份。原脚本、失败批次、日志和报告保持原处。

- 原 v24r1 SHA-256：`f968a250b95091b0b917b9fa3ee43c60ef01ad0b1180dc39a739c2619972f2d0`
- 候选 v24r2 SHA-256：`1b486f16c955d5a54b7e7e15e570fc66e3573cc9f02581d6027e5a73be725fb4`
- 等待 `engine_rows()` 空且 source lock 不存在连续至少 60 秒，使用 monotonic 时间；任何采样发现引擎或锁占用都将累计时间清零。空闲采样间隔 1 秒，占用时保留原 5 秒轮询。
- deadline、KeyboardInterrupt、exclusive acquire、acquire 后及启动前的引擎检查、运行时 foreign_engine_resumed 中止和 only-owned-child 清理保留原逻辑。等待仅避免短空隙启动；无法保证未来不会恢复占用。
- batch schema 和新目录前缀为 v24r2；r2 加入 source pin list，并继续 pin 原 r1/r/v24o4。
- frozen 5041 raw / 5037 unique、baseline 5039 raw / 5035 unique、安装 5100→5102 逐路径校验、q1 boundary pins/检查、原 OwnedSlot writer fault suite 和完整 native A/B/C 资格均未改。
- 顺序仍为 import → profile_guard → pure boundary q1 → 原 OwnedSlot retry → A/B/C；所有其余 Runner 方法 AST 精确一致，反向还原允许变更后与 r1 原字节精确一致。

仅完成 Python AST parse 与 compile(AST)，没有 import/执行 producer，没有运行 Godot，没有新的 native 通过声明。CLI 与 r1 参数一致，只将脚本路径换为本文件；原 deadline 不延长。
