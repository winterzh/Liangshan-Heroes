# 2026-09-08 Steam 统计读取与异常通知修复 QA

本轮源码 QA 最终 **191 项通过**；冻结候选 **1088 项同包检查**、源码/同包各 10 项身份检查、实际 EXE 600 帧、三个原生 DLL 及 11 例短测通过。完整结果、交付哈希和仍开放的门槛见 [CANDIDATE.md](CANDIDATE.md)。这不表示 Steam 公开版本已生效。

- `source_qa/`：保留两次 fixture 失败和第三次成功的原始 receipt/report/日志；成功六张截图由主任务逐张查看，记录为全部可读。
- `static/`：发布工具静态/纯函数 9 项；未运行 Godot。
- `candidate/`、`smoke/`：实际冻结包与同一 EXE 的验证证据。
- `candidate_delivery.json`：实际 ZIP 与六成员的大小、SHA256、SHA1，供 Steam 服务端逐项核对。

初始归档说明原文保存在 [history/source_archive_README.md](history/source_archive_README.md)。原始 SHA 清单不覆盖，历史路径映射见 `initial_archive_path_map.json`；当前文件字节清单见 `evidence_sha256.json`。未复制玩家文件清单、玩家文件哈希、profile、缓存、登录信息、EXE、DLL 或 ZIP。
