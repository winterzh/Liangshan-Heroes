# Campaign 保存回读收据 v27（外部未执行提案）

本提案只补保存结果的可观察性，不修改公共工程。原/proposed各两文件为 Campaign 与 Battle；原best单局/no union算法1032字节保持，Campaign其它20个方法原字节保持，Battle只新增8行结果传播，原victory/SteamService.settle不改。

有效结果的accepted与本地persisted分开。真实保存或完整新ConfigFile回读失败时，records/unlocked保持原内存，memory_applied/new_story_seal/durable_new_story_seal为false。磁盘若已save成功，可能已经是candidate；disk_state_unconfirmed=true，不能声称磁盘回滚、可安全重试、事务或crash恢复完成。

CAMPAIGN_QA保持既有内存演义结果和_save bool=true；persisted=false、suppressed=true、durable_new_story_seal=false，未读写cfg且不请求Cloud dirty。正常保存须cfg.save实际OK、全新ConfigFile.load实际OK、完整section/key及每值ConfigFile序列化语义一致、读期间文件SHA稳定，才persisted=true。unknown section/key保留；已有cfg无法load时拒绝，只有真实新文件允许ERR_FILE_NOT_FOUND。Object/RID/Callable/Signal、脚本/对象typed容器、循环或深度>128写前拒绝，原文件不由此尝试覆盖。

全量值比较使用固定安全section/key的ConfigFile规范文本与typeof，覆盖可回读data Variant，包括built-in Typed/Packed/math/StringName/NaN。不使用JSON、整cfg文本相等或IEEE逐位比较；-0/NaN遵循引擎序列化语义。Cloud callback在新Campaign内存安装之后请求，以免同步mirror读取旧值；callback requested/invoked不等于dirty已观察或上传已验证。

旧bool callers保持签名和QA成功。save_prefs仍忽略返回，未新增玩家失败提示/重试UI；apply_cloud_progress原方法仍先替换云端内存再调用_save，真实失败bool=false，既有云内存替换不由本提案rollback。Battle只传播receipt/accepted/memory/persisted/suppressed/durable字段；当前HUD未处理新失败receipt，玩家完整可见性未完成。

FAULT_MATRIX_V27.json的19条均未执行，故障watcher与native harness尚未实现；静态审查不能替代真实ConfigFile写读、解析、自然胜利、gen2→cfg→ack、独立重启、Cloud或平台发布资格。来源与官方引擎API证据见SOURCE_PINS.json和CONFIGFILE_OFFICIAL_ENGINE_SOURCE_EVIDENCE_FX.json。新候选须独立peer及后续隔离native测试后才可考虑应用。
