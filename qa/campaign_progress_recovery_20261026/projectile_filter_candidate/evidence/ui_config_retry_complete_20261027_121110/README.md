# B1 设置保存失败后的实际重试与独立读回

固定 b22 源码上的两个实际进程全部完成：PID28560 的设置重试323项、PID41724 的独立读回83项，共406项通过，均退出0。完整源身份、来源pins、子进程终态、自有句柄、lane与锁释放均通过。

第一进程实际操作“更多→设置→方阵/困难→返回保存”。宿主仅在原本不存在的 campaign_cfg_candidates 父路径创建自有 regular-file，真实得到 CFG_STAGE_PARENT；原 RetryCampaignConfig 在同一阻塞下再次失败。两次完整观察逐项相同，保留同一 writer/frozen CFG 引用、原 owner/CAS、原提案及 scope；新观察记录原6键顺序与类型（前5个 String、第6个 StringName）和每个原值的 Codec，而不修改生产 Codec。

解除自有阻塞后，原 RetryCampaignConfig 完成 CAMPAIGN_CFG_READBACK_VERIFIED。同一 transaction 只生成 prepared1→applied2；原失败重试按实际API不另发 operation，因此报告为初次失败和最终成功共2次信号。Settings 文件先合法变更，Campaign CFG 在成功前仍缺失，二者不能混成“所有文件直到成功均未改”。

第二进程正常启动读取同一偏好和磁盘状态，60个正常帧后 typed checkpoint 与业务库存完全相同；无额外动作、operation、恢复或写入，未生成 Continue 槽。最终 candidate 父目录保留空 v1 子目录，不声称整个父目录消失。报告中的有限 typed 设置/transaction 元数据按原字节保留，不是物理存档载荷。

原 receipt、两个 controller/report/native.log、两对 gate/ACK、bindings 与全部文本来源映射保留；重复内容引用固定 d5cc7b34c45d713352b346e27eb1c04cd8f1f220 已逐 blob 实读校验的原件，未提交或不匹配内容直接保存原冻结字节。849项 receipt pins 闭合为840项原字节文本、8项仅沿终态收据保留的 EXE metadata、1项158B自有 nonce blocker 的SHA/长度排除记录。阻塞载荷只哈希不复制；物理profile、CFG/Settings、journal/Slot/LC/owner、EXE/PCK/cache均未打开或复制。

这只授予本来源的 B1 设置失败重试和两进程独立读回切片。B2 prepared-journal 启动恢复、RetryTerminal、完整战役、61阶段、公开入口、原版发行包、Steam SDK、OS键鼠、人工验收与发布仍未授予。此次使用原UI callback，不把内部自动化当作用户OS键鼠实操。
