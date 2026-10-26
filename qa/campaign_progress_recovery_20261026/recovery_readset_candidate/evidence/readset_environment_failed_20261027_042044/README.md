# Readset 组件第二次工具失败：同 profile 环境重复创建

原批次 `.godot/recovery_readset_20261027/20261027_042044_b52e6b2c` complete=false。producer PID16900 已通过修订后的 gate，命中原 `SnapshotStore.commit_locked:323 / pending_verified`，原栈为 `prepare_fixture → gate` 调用后进入该生产保存方法。宿主记录唯一断点、完整栈与原 Popen PID/nonce，随后计划终止，exit1；producercomplete、进程终态与 helpers_terminal 均为true。

宿主准备同 profile 的 reader 时，再次调用 `private_environment(profile)`，在 `target.mkdir(exist_ok=False)` 创建已有 appdata 目录而抛出 FileExistsError。reader/clone 未启动，恢复与拒绝矩阵尚未执行。prepared 持久报告有102项全部通过；producer按计划被终止，没有最终 report，不臆造 gate 后检查总数，也不把宿主失败算成 Store 恢复失败。

本批冻结 driver SHA `3ce3ab64346277f8330cc9a3f04ae9472e1083ff75810588cef126445282dcf7`；原宿主 SHA `468b3f56806a49e920d5ccf7444b11a177e4a66f60e8b8c12dbdb703238cc2b2`。350个 pins 优先原 runner_inputs 回读，保留原5输入、3worker、环境辅助源码、controller/prepared/gate/stop/native.log、原宿主收据与 traceback。后续环境复用修订未替入本批。

真实 closed pending SHA `7fea5480ce955b0406a3089c549b0a6d75bc573b8bb60b7d9f29fcf1e797fe98`，4238字节，generation3，前驱 SHA `747504e73fc5c0ad7e71afc37ce7cb19675e9e0fe92bffb53d5b95a880d29139`；owner PID16900。原终止前后全部夹具库存相等，归档时只读核对当前目录与该库存一致，pending与原夹具字节一致。原旧4MB业务目录也与宿主原库存一致。没有 helper IPC 目录，与producer原 no-helper 库存对应。

原宿主已记录 source/original保持、children/helpers终态、自有锁确认与 lockreleased=true；此收据原字节保留。source_map 列明未复制的 fixture、seed、profile、EXE 和其余祖先来源，inventory_audit 只保存哈希/目录/信封元数据，不保存业务载荷。所有归档文件写后 SHA 回读一致；未重复全工程哈希、未启动引擎、未动第一批两套归档。

资格仅限此次 QA 生产者到达真实保存断点的证据。公开入口、真实SDK、OS键鼠、原版EXE、人工体验、恢复/ABA矩阵、性能、生产采用及发布均未授予。
