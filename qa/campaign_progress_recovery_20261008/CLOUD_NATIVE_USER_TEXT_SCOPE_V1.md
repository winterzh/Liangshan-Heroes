# CLOUD-NATIVE-USER-TEXT-001 原生目录文本修复

真实保留Lu A原报告里的actual_user_data_dir用D:/...，Windows Path构造后str变成D:\...。旧semantics binder用controller.user(Path)、firstconsumer先Path化再把str传到ready/packet/projection，最早pre-arm就会拒绝同一合法native目录；旧pure fixtures用Pathstr生成所有字段而未覆盖真实表示。

新semantics_v2要求原始str字段，binder用已审原packets.user保留ready文本；packet replay_v2同样仅接受raw str；firstconsumer_v4保留report.user_directory为native_user，用它逐字节比较原ready/apply-ready、传replay/projection，另建Path仅做noLinks/private boundary/physical读写。runtime_v5只更换binder import。目录界限、PID/nonce/full15 identity、原四export/40labels、arm/source/byte/CFG/journal/semantics门槛不放宽；旧源/收据/254pin原件保持。

35项synthetic文件/消息检查含原27及8项真实Windows representation反例与新边界：旧Path重建拒绝、raw文本通过、新API拒绝Path和改变native文本等。初始host fixture误读旧33-label GD合同导致正确constructor拒绝，原script/exit1观察保留，切换真实GDv3/40合同后通过，四生产后继不变。实际Popen/Godot/完整consumer未运行；原Lu A报告仅作斜杠表示证据，第四完整批仍failed，不授成功V12 prior。

请有限复核已确认这个路径文本差异、原物理边界保持及传参；不大模拟/Native，approved_stages=[]，完成后直接写原独立收据返回SHA。普通cloud restart/完整producer/成功前置/原19及全部原目标未完成。
