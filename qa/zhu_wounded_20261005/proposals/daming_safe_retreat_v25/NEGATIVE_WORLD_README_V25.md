# V25 完整世界固定 DTO 负例候选

仅外部新 QA 文件；没有修改公共源码，没有解析或运行 Godot。接口和精确必需用例集合以 `NEGATIVE_WORLD_INTERFACE_V25.json` 为准。本批是完整世界 DTO 拒绝测试，实际对象 capture 负例和独立 Unit/Pair 组件负例尚未实现，整体 V25 资格仍为 false。

输入必须来自同批真实、成功关闭的 A single-safe 原生进程，分别为 lu / shi 单人获救撤离案例。不得用人工拼装、旧版本或失败 A 代替。`NEGATIVE_WORLD_INPUT_TEMPLATE_V25.json` 只是空模板，不是可运行的合格输入。

每个输入 manifest 使用 schema `daming_safe_retreat_negative_inputs_v25`，指定 first_role、content_version、engine_sha256，并为 a_report、a_handoff、a_packet、a_world、a_slot 提供绝对 path 和原文件 sha256。a_slot 必须是对应 generation 1 的真实闭合存档原字节；packet/world SHA 必须已存在于 A report.evidence，handoff 的 PID、nonce、身份、slot SHA、完整 packet 必须一致。支持 producer 所有的只读副本路径，SHA 不变。

运行前把 GD 和同名 scene 复制到新私有工程 tools 并正常导入。使用独立 profile，设置 APPDATA、LOCALAPPDATA、TEMP、TMP 为 profile 下同名小写子目录，STEAM_DISABLED=1、CAMPAIGN_QA=1。其余明确提供：

- DAMING_NEGATIVE_PROFILE：绝对私有 profile 根目录。
- DAMING_NEGATIVE_REPORT：未使用的外部完整 report.json 路径，父目录已创建。
- DAMING_NEGATIVE_MANIFEST / DAMING_NEGATIVE_MANIFEST_SHA256：当前冻结输入清单及其 SHA。
- DAMING_NEGATIVE_NONCE：新进程 nonce。
- DAMING_NEGATIVE_EXPECT_CONTENT / DAMING_NEGATIVE_EXPECT_ENGINE：与真实 A、已安装工程和实际引擎一致的完整身份。

加载的 V25 Core 必须实际包含 `_validate_daming_safe_pair`。source route 使用实际 Slot._validate_document；JSON route 使用真实原 envelope 身份/链及重新计算的模型 payload 哈希，经实际 Store._decode 和 JSON document hook。两条 route 都先验证未修改真实 A 的完整 Core.prepare 正例，再对每个命名负例使用独立 Core。负例在 dispose 前观察 Battle、identity、unit_plan 均为空，并核对原 packet、opened typed document、base 全部类型和 IEEE 浮点字节未变。Root grids、identities、blockers 保留。

固定负例包括 queue、五项停止字段、另一角色存活/成员/事件、Root 选择和两个 caster、五个 cast 数组、rescue 事件配对，以及五个 record 固定 String identity/context 叶的六类错误原始类型。原完整 Unit/Level/Graph 先拒绝的用例明确标记 guard layer，不声称它们直接执行了后续 pair 分支。

Producer 应核对 exact case × {source,json} 集合、每行预期/实际错误码、所有 checks、两个正例、预 dispose 零世界、完整不变证据、实际 PID/nonce/profile/身份、输入和源码 SHA、原生退出码与日志零 SCRIPT ERROR/ERROR。禁止用检查数下限放宽覆盖。纯矩阵 passed 不等于整体 V25 qualified；不得把未实现组件或 live capture 测试当作通过。

现有 V25 real runner 复用了实际 r2 B 发现的重复 capture_rejected one-shot 连接问题。旧 runner 和已交 static review 保留；未来真实 A/B/C/D runner 必须从新的 v24s 后继修正创建新 sibling，并重新审查。本 DTO 工具完全不调用 _hold、capture、barrier、save、factory deployment 或 gameplay tick。

实际来源尚未提供时，工具输出受控 preflight 失败；报告 planned_cases / executed_rows 仅对应实际到达的阶段，不产生虚构测试数。首次原生失败必须保留整批证据，任何修复应新建 sibling。
