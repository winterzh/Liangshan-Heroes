# v24s 新未执行 sibling

原 r2 `1b486f16c955d5a54b7e7e15e570fc66e3573cc9f02581d6027e5a73be725fb4`、原 v24o GD/scene 和 r2 failed run/profile 全部保持不变。实际 r2 A 完成 32 检查和首次真实 save；B 重复 _hold 时留下的 capture_rejected CONNECT_ONE_SHOT 被再次 connect，原 native ERROR 导致终止；B无终态报告、C未运行，完整 A/B/C 未资格通过。

仅 _hold 信号生命周期改动：开始连接前精确清理 this QA 的 _on_held/_on_rejected 两个 unbound callable；connect 后核验 Error=OK、每信号确有1连接、flags=CONNECT_ONE_SHOT(4)、目标this QA、method/绑定/unbound均正确。完成、超时/拒绝信号、同步request拒绝和connect guard失败均清理两 own listeners。每次cleanup同步比较其他 callable+flags 原样，绝不disconnect其他目标/method/bind。原 request/15秒180frames/HELD health/labels 全保留；所有其他 GD方法、完整 World/Packet/Session/Clock/mount/ticks/action effects 都是原字节。

新增producer使用 v24s GD/scene copy与入口，negative profile guard仍期望exit2；r2原始资格、continuous60s自然空闲、source5041/5037、runtime5102、q1 boundary、原 OwnedSlot、完整 A/B/C以及原canonical/hash/独立PIDnonce/evidence guards 全保留。增加 real connection audits 精确校验：A1/B2/C2次hold各before/installed/after三阶段，安装count/flags/callable及成功后ready已消费/rejected确实残留并被清掉；后续链接others均未变。所有原mandatory labels未删。

新GD SHA `76ed6f114de755b398112778ddabf5af820a30237b75070a5a2aaaea188b87db`；scene SHA `d7e1475d5e2b5add7cf008ac163b1eb909b6a6889641eff6ddb5821500851dee`；producer SHA `049dcdc74fab7936d4812f71a9806cee46569163ece4c524043ac7cfdedd8626`。CLI与r2完全相同，仅替换producer脚本路径为 run_daming_admit_v24s.py；fresh run前缀/schema均v24s，旧user-slot路径只存在新profile内。固定新GDscene、原r2/v24o provenance，并保持源candidate4路径原qualification不变。

Python仅AST parse/compile(AST)通过；没有启动producer或Godot，没有native GDparse，通过必须新import/原所有regression/完整ABC与整份零ERROR日志才能证明。source/public/r2旧文件未改。
