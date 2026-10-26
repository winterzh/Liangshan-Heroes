# 环境复用 Python dry-check（2026-10-27）

原检查已完成 30/30：两个全新隔离 profile 各调用一次真实 private_environment，producer/reader 复制同一基础环境但使用独立 process nonce；clone 先建立四个环境目录，再用真实 no-overwrite copytree 复制合成文本。四目录、seed 路径与拒绝错误环境的边界均有原收据。AST 和实际 Python --help 退出 0。

execution/stdin_python.py 是从本轮历史工具调用的 here-string 正文逐字提取的实际执行源码；原来通过 PowerShell here-string | python - 的 stdin 执行。original_tool_input.ps1 保存同次工具的命令字符串。源码归档发生在执行之后，本次未重跑检查。没有另行截获 PowerShell 传给 Python 的原始 stdin 字节流，因此不把归档 LF 源码描述为已捕获的管道编码/行尾字节。

raw/receipt.json 为原文件字节，来自 D:/CodexQA/readset_env_probe/b65b84eafb53/receipt.json。inputs 保存收据对应的当前 host、实际 common helper 全源，以及第二批冻结的修复前 host；host_changes.diff 仅由这两份宿主原字节生成。helper 未改，private_environment 在其第 155–172 行。此包不是全部传递依赖或完整工程闭包；不复制 profile、合成载荷、存档、EXE、素材或缓存。

资格仅为宿主环境协议的 30 项 Python 验证。Godot 未启动，未验证 Store 恢复、完整三进程、Flow、SDK、人工操作或发布；合成 content/engine 字段不授真实身份资格。原生完整重跑仍须新 profile。manifest.json 逐文件记录来源、字节数和 SHA-256，manifest 自身的 SHA 由交付消息单独提供。
