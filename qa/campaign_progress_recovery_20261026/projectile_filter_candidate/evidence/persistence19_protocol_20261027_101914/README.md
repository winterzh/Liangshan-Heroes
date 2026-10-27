# 原 19 案：当前候选的 9/12 原生故障协议证明

两个独立原生进程分别完成 30 项检查，总计 60 项。第 9 案 PID 6324 在真实 retry_write 292→293 行之间遭遇 CREATE_NEW/share0 写拒绝，返回 CFG_STAGE_WRITE/native_error=12/owned_pending。宿主哨兵持有至 save 返回后才关闭、移出，未冒充生产候选。

第 12 案 PID 28424 在真实 candidate 保存及 _stable_cfg:146 读取处设 Windows oplock，记录 armed < kernel break < released、子进程存活、字节 SHA 改变且原生 ConfigFile 语义保持相同，实际返回 CFG_STAGE_READBACK。两案原 CFG 的运行时元数据均保持 84 B 和原 SHA，内存与 cloud 观察不变；归档没有再次打开物理 CFG 或 private profile。

原 receipt 的 complete/protocol_proved=true，component_matrix_qualified=false。此处只证明当前 b22 工具的两项真实故障机制，供同源 19 案宿主准入；不授 19 案整体、自然奖励、公开 Continue、SDK、完整 61、发行或人工验收。

873 个运行时 pins 包括 865 个文本来源及 8 个只核 SHA 的 EXE；41 个命名输入属于该完整绑定。文本均读取 run 的冻结原字节，按 SHA 复用固定提交 9e756b3781dcbc0948a48c60fbc1304745c2e920 的既有证据或源码 blob，并逐个回读该提交核验。source_map 保留每项来源、Git blob、manifest 或新增 raw 路径；所有新增文件由本目录 manifest 固定。

未读取或复制 private profile、物理 CFG/LC/Slot、宿主 CFG 备份或 sentinel 载荷；其必要路径与 SHA 仅保留为原始运行元数据。未复制 EXE/缓存/素材，未重算完整工程。archive_protocol.py 留在原 .godot/persistence19_protocol_20261027 下供受控复用。
