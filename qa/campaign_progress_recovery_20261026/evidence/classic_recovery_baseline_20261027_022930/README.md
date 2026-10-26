# 经典续玩旧分支问题复现（2026-10-27 02:29:30 批次）

原批次：.godot/classic_recovery_branch_20261027/20261027_022930_07257df1。
实际来源 source-v1:e97a07b9ff04b677fbc1934a40976cc6e1f82479855cf39f305147ae4f6d1eea；expected=baseline，complete=true 表示成功复现旧预读阻断，不表示游戏已经恢复或修复通过。

两组各两个独立原生进程，合计四个 PID 终态：pending writer 52624、reader 38908；record writer 61544、reader 74420。两个 writer 在匹配的生产断点被宿主计划终止，exit 1 属于预期；两个 reader 正常 exit 0。每组 writer 准备 23 项、reader 18 项，合计 82 项断言通过，宿主未计数的断言不另加总。211 个运行 pins 按冻结副本或未变原件核对一致，最终源码身份、自有共享锁确认与释放均通过。

实际两组证据：

- pending：原 Flow → Session → Slot 写入栈在 run_snapshot_store.gd:313 的 pending_verified 停住。原 receipt.pending SHA 为 27d6cab9f367325a72ea87162de84e5f963992507184419a9567e10beadc4fca；绑定的 active LC gen1 SHA 为 fa9358741fe4abb124e17f1a526df3ece8807366db9fcfcf1c2e47edda4625dd。
- record：原写入栈在 run_slot_store.gd:175 释放 writing 前停住。原 record_0000000001.json SHA 为 9878e90467a28efc1d7b59a53e1f631b1f8e7af4b64d043e4db1d243a3ec6c98；active LC gen1 SHA 为 497f513e256f2e386d6a46a9aeb264b1a798a0905affd2c2d257fc1dddf04c5c。

两份均为真实 classic_continue_slot_v3、defense/空 level_id/30 波、generation 1、uncredited 同 token。宿主验证完整 envelope/载荷 SHA、原 writing owner PID、实际生产栈及中断前后业务目录字节相等。独立 reader 实际返回 RECOVERY_REQUIRED，保留菜单、没有安装世界，槽及 active local_continue_lifecycle_v1 原件未变；归档时再次只读核对现存原档与 terminated_continue_copy 哈希。两组原 reader 报告、原始槽与 LC 哈希在 summary.json 分列。

新观察器保留发射前真实 observer/Flow 连接身份、注册次序、ONE_SHOT flags 及同栈时序；HELD 时 calls=1、Session 尚未建立、非物理帧、类型快照正常。flow_callback_connected=false 如实记录，不能再当作失败。原 writer 断点栈仍独立证明正式 Flow、Session、Slot 调用链。

入口边界：先使用隔离 QA gate 进入经典玩法并保存；reader 点击实际 Continue 后，在没有 await 或事件泵的同栈内清除 QA gate，使下一帧走原恢复分支。初始私有 gate、此单分支诊断均被明示保留。因此 public_entry、发行 EXE、SDK、OS 键鼠、人工体验及发布资格全部为 false。当前只证明旧预读阻断可复现；修复后的恢复必须看另一批。

raw 保存运行时冻结 runner_inputs、workers、原 receipt/log/prepared/request/ack 和两个 reader 报告。原目录 119 文件中 111 份纯文本保留；6 份 terminated_continue_copy 业务载荷及 2 个冻结 EXE 仅核哈希、全部排除。source_map.json 解析全部 211 个 pins，manifest.json 校验除自身外每份归档原字节。没有复制 profile、独立存档/LC 业务文件、缓存、素材或二进制；没有修改来源、运行引擎或操作 Git。
