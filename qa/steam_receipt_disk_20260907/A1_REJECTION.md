# A1 未运行失效记录

首包 freeze `3b05bcb88b058c92e5db4d9689429d679b7e547e7dae9b6a3e008da5a7c4099e` 只通过 grammar/结构检查，尚未占用 Godot。

独立 QA 发现正常迟到序列：同一 Host/session 发送 A、收到成功清 A、再发 B 后，重复 A 成功仅带 app/owner/session，会被错误绑定当前 B。原测试仅在 inflight 为空时重复 callback，不能证明跨批次安全。

A1 文件与原冻结清单保持不变。`attempt_a2` 改用不可由同进程换 Host/session 绕过的进程级单次发送 lease，并加入第二批尝试、旧成功和新 Host 的完整反例；生产 SDK 不具备可假定存在的 batch token，真实权威新读仍独立验证。
