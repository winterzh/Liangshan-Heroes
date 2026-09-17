# Steam 统计修复候选验证：2026-09-08

候选 `20260908_184221_465b304a` 已完成本机冻结包验证：**1088 项同包检查、源码与同包各 10 项身份检查、实际 EXE 600 帧及三个原生 DLL 路径/哈希检查均通过**。同一 EXE 的 `smoke_20260908_184529` 串行 11 例短测通过。该结论不表示 Steam 已上传、default 已生效或客户端已更新；服务器状态应另存收据。

## 实际进入候选的变化

- Steam 初次统计读取使用保留 getter 成功标志的只读桥接；读取失败不能被当作零值，且不再用 SetStat 探测读取成功。
- 无请求编号的 stored 成功通知不能确认任意本地 revision，也不能解除新请求的 busy 状态。普通流程保留限频绝对值重试；校正时停止本进程继续写入。
- 成品包含 `steam_stats_reader.dll`，首次导入前登记扩展，内容身份校验覆盖固定 native 布局；ZIP 包含 Godot C++ MIT 许可。
- 构建首尾严格比较允许运行路径集合与源码 QA 快照，防止 QA 后新增文件被静默漏打。

## 本机验证结果

`candidate/receipt.json` 与 `candidate/verification_report.json` 是原始受测收据。包内 **126 份生产 GDScript** 均逐个加载检查；包括 reader 类注册、真实原生组件在未初始化 Steam 时拒绝读取、隔离 fixture 的有效 0/false、getter 失败及负数拒绝、四语词库/字体/生平及资源排除检查。

两个身份探针目录分别保留 manifest、process_receipt、report 和原始日志；实际发行 EXE 的 600 帧运行及三个 DLL 的加载路径与 SHA256 另在 verification_report 中。未归档 `identity_players_*`；没有上传玩家文件清单或玩家文件哈希。

`smoke/receipt.json` 为同一 EXE 的 11 例短测：八关启动、据守、末波清理、主菜单。各子进程退出 0、错误 0；据守 9 项和末波清理 12 项内嵌合同均 `ALL=true`。源码、真实玩家目录及 EXE 未变化，所有进程退出且锁已释放。此处只公开玩家目录未变化的布尔结果。

`helpers/smoke_verified_package.py.txt` 保留运行后读取到的当前 helper 原始字节，SHA256 `b54a3a2678f79f5eb88706f5ec9254e54143e728207ae9c4d689fa956ae918a9`。原 runner 没有在启动前把自身哈希写入原始 receipt，该限制记录于 `smoke/runner_provenance.json`；不得将归档时的哈希描述为启动前自校验。复现时将 helper 恢复到工程 `.godot/<新目录>/smoke_verified_package.py`，以候选目录为参数，使用新的独占私有 profile。

## 交付哈希与发布边界

[候选交付清单](candidate_delivery.json) 记录 ZIP 与六成员的 SHA256、SHA1、大小，逐项从实际 ZIP 流式回读并与候选原始收据一致。ZIP 为 **238,222,829 字节**，SHA256 `b160a06f066f9b4c087d5ee1ef5ebd2265954ba8c91a2c73ec4bf191b317bd96`。

EXE 为 **305,703,456 字节**，SHA256 `69453868c2a1c28a3b84171a3e0331d77405618c684cfcbd715de3f7c0862e0a`。交付清单中的上传/服务端/default 标记是本地候选阶段快照，后续应以独立 Steam 服务器收据为准。

本轮禁用真实 Steam 的源码/成品 QA 没有写入真实账号。此前真实只读验证不能证明服务器写入确认。普通路径尚无跨进程持久队列；经典 30 波和八关保存/继续入口仍关闭。完整续玩、全程通关、1800 秒、双机、第二受控账号、首次玩家和最终性能门槛仍未关闭。

## 归档完整性

`candidate_source_archive_sha256.json` 与 `smoke_source_archive_sha256.json` 保留逐字节复制来源链；`candidate_phase_sha256.json` 覆盖本阶段新增证据。初始阶段的 README 原文另存 `history/source_archive_README.md`，与原 `initial_archive_sha256.json` 中的 README 哈希一致；`initial_archive_path_map.json` 说明这一展示文档的历史位置，旧 manifest 没有覆盖或重算。当前全目录清单见 `evidence_sha256.json`。

未复制 EXE、DLL、ZIP、导入缓存、私有 profile、真实 Steam 原始日志或凭据。
