# 高俅终局工具加载检查：失败环境与加载成功

此归档同时保存两次不同原生检查的原收据、日志、各自五 worker、各自 runner 与所需命名来源。原始 bytes 未改写；`manifest.json` 为归档载荷清单，`source_map.json` 记录原路径、receipt pins 和排除范围。两份 runner 不互相替换。

- **061454_d12c6ada：失败。** 原 PID 36612，2.686 秒，exit0 但有编译错误，`complete=false`。`--check-only` 未提供本项目实际 autoload 注册环境，出现 SteamService/Campaign/Localize/Sfx 等 Identifier not found 级联；不能将 exit0 当通过。只检查 driver 时已失败，bootstrap 第二项没有运行；此模式本来没有独立 loader。失败 runner 使用 root 随后逐字保留到该原目录的副本，SHA 与原 receipt 相符。
- **061546_f78744d7：加载成功。** 原 PID 16356，40.398 秒，exit0、errors=[]、`complete=true`。正常 autoload 后，由 SceneTree deferred loader 对 driver 与 bootstrap 执行 load/can_instantiate，**没有 new worker 或添加 Battle，也没有执行玩法 driver.run**。这是5个外部依赖脚本可在该环境加载的证据，不是四进程路线、完整来源、玩法或胜利通过。

两份原收据的 owner_confirmed、lane_idle、lock_released 均为 true；本归档只核收据及原文件，不重新查询正在运行的其他引擎进程。各命名 source pin 逐项核SHA，原来源收据及日志复制后逐字回读。原工程选择是941c冻结项目，加载检查未重新完整验证全工程，所以 full_source_qualified=false 原样保留。

成功日志的标记只作辅助；结论同时依据原实际 PID、exit0、空 errors、原 loader 不实例化代码及 receipt pins。未复制 EXE、private profile、业务存档、project资源或cache。归档不授公开入口、真人键鼠、Steam SDK、EXE或完整高俅胜利资格；之后的长路线必须保留独立收据。
