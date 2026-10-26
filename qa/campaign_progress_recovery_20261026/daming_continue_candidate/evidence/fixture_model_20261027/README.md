# Daming A 夹具冻结 hook：Python 文件模型证据

本目录仅归档 A 冻结 hook 的隔离文件模型，53 项通过、0 项失败。所有报告、PID 和 slot/LC 内容均由模型合成；没有运行 Godot，不代表真实 A 正常退出、原生 Slot 解码、八进程 Flow 或后续 52/61、19 故障已通过。

原运行：`D:/CodexQA/daming_fixture_model/69a3ca286750484eaf3b03cd18bffcff`。
原收据 SHA：`6d1d0afbdaa48f58db13501845b87d5254cafb447e0273428ce8c1e94b6e5b8b`。

- `raw/receipt.json` 与 `raw/source_manifest.json` 是执行时原件。
- `executed_sources/` 保留原运行预先冻结的四份 Python 原字节：host、fixture helper、模型脚本及其 prepare_continue 依赖；逐份与原收据 SHA 和当时副本大小核对。归档时当前对应 Python 仍与原件相同。
- `handoff_metadata/README.md`、`sources.json` 是模型结束后更新的交接说明，不冒充模型执行输入。两者引用的模型收据及三份执行脚本 SHA 已核对。
- `manifest.json` 给出每个归档原件的实际来源、SHA、大小和角色；业务载荷不在白名单。

验证覆盖原字节复制、目录闭合、错误进程/报告/nonce/source、代际和 token 绑定、越界、输出碰撞、复制期间变化、后续冻结库存变化及活 profile 合法推进不误伤。symlink 创建因 Windows 权限不足明确跳过；另一个用例实际创建私有 junction（mklink exit0），随后由实际路径守卫拒绝 reparse。不能把 junction 结果写成 symlink 创建用例通过。

原执行没有单独 stdout 日志文件，本归档不重构日志。实际 mklink stdout/stderr 原字节以 hex 保留在原收据里。没有复制任何模型 slot/LC、模型 profile、真实存档、EXE 或缓存；只复制工具证据。归档行为没有启动引擎或修改既有来源。
