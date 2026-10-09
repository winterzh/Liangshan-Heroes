# 真实 Steam 正常导出启动观察入口 V2

此候选是后续真实账号云档案成功重试和一次性奖励验收的启动基础。它运行原 SteamService/SteamCloud/普通菜单，不替换 native、available、account，不绕过 SteamRunPolicy。它不执行云故障、奖励或重启，也不授这些资格。

暂未 Godot 解析、导出或执行。完整 V12 成功前置、精确独立源码审查和具体导出/运行准入尚缺，不能运行此候选。

未来在原冻结私有导出工程中，将 gd/tscn 安装到 res://tools/，仅该私有导出的 main_scene 指向此 tscn；保持全部生产 autoload 和原菜单。使用真实 steam-feature 编译导出程序与完整原生十五字段身份，不使用 editor、headless、--script/-s，不设置任何 SteamRunPolicy 标准测试 flag。宿主须在进程启动前证明目录自有/空白且四个 Windows 用户目录环境变量隔离，绑定实际 EXE/全部包与依赖、正常退出时的原 Popen 和原始关闭日志/报告。

宿主为 LSH_REAL_SDK_DESCRIPTOR 提供一个原字节 SHA 绑定、最多 1MiB 的外部 JSON。字段包括 schema=campaign_real_sdk_bootstrap_descriptor_v1、case=bootstrap_only、32字节十六进制 nonce、精确 private_user_directory、executable/executable_sha256、原十五字段 installed_identity、expected_account 及 normal_startup_account_side_effects_acknowledged=true。描述符与报告只留外部私有批，不上传真实账号/存档/Steam 日志到 Git。

正常 SteamService 初始化和退出可能同步真实统计，SteamCloud 可能读取/写入真实账号远程档案。私有 Windows profile 不隔离 Steam Remote Storage；不能把它称为无账号副作用。在任何执行之前必须完成真实账号/既有远程与本地档案保护及实际调用范围的具体审查。本入口本身不主动调用云写入或奖励，但这不取消原 autoload 的行为。

正常 SDK 初始化、AppID/getSteamID/ensure_account、原 native stats reader、普通180帧后的同账号/同 singleton/完整安装身份才组成启动观察。未来仍需原实际故障/UI同writer与冻结提案成功重试、同档案重启，以及真实奖励前后及重复完成的独立证据。

V1源和审查保持。V2报告用nonce独立路径，开始及写入前拒绝已有文件/目录；写入flush后检查get_error，close后重读原字节、长度及SHA，再输出完成标记。Godot FileAccess.WRITE不是原子独占创建，宿主仍必须持有唯一空私有目录，不能把这两次存在性检查当租约。

WorkshopService正常_ready→refresh还可能downloadItem下载订阅内容；Presence可能清除/更新好友状态。宿主必须清除SCREENSHOT_DIR及所有自动进入/测试flag，并约束菜单交互，不能只清SteamRunPolicy列表。autoload的初始化在Node核验前已经发生，所以先完成实际宿主侧账号/云/本地保护审查才允许创建真实进程。
