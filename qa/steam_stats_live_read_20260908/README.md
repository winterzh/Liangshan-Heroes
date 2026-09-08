# 真实账号只读探针与 ABI 修复

- `build/receipt.json`：构建 a3ac131a2e53，源码与依赖摘要、工具链和全部命令；86 项隔离检查通过。
- `build/*_report.json`、`build/*.log`：实际 DLL 的两类 Godot 测试及编译日志。合成 Steam DLL 和测试 EXE 不归档为发行依赖。
- `diagnostic_identity_mismatch.json`：旧 DLL 的真实读取失败收据，保留失败事实，不作为验收通过。
- `live_read.json`：修复后最终 80fa232c74e5，真实账号初始缓存成功及连续两次 4 统计/30 成就读取；二进制/源码前后匹配、两进程退出 0/错误 0。
- `evidence_sha256.json`：本目录证据摘要，不含自身。

当前 vendor DLL 已替换为受测修正版，来源指向本目录。前一批 QA 的二进制说明属于当时版本，应以当前 provenance 为准。

所有真实探针的 `write_calls=0`、`write_acknowledgement_proven=false`。没有运行正常玩法、修改累计统计或解锁/清除成就，也没有验证 StoreStats、断网重连、多设备和写入确认。原始真实账号日志保留在本机临时目录，不上传 Git；本目录只有脱敏结构化结果。完整范围见 [开发说明](../../docs/STEAM_LIVE_READ_20260908.md)。
