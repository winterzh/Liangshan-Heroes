# R12私有SDK导出包探针V2

原生产包probe要求ContinueFlow关闭，不能直接用来证明R12恢复候选。此源码候选只针对真实导出的主PCK：原完整scripts清单逐个加载并要求无source_code的编译脚本，验证新默认入口/原菜单child/实际build identity非stub，以及真实Steam与reader扩展存在、生产SteamService无初始化、真实reader返回STEAM_NOT_INITIALIZED。

未来用已封存官方editor --headless --main-pack <实际导出EXE> --script <此固定外部脚本>运行，原拥有者提供三个LSH_SDK_PACKAGE_*原manifest/path/nonce字段和输出目录（实际四字段：OUTPUT、NONCE、SCRIPTS_FILE、SCRIPTS_SHA256），STEAM_DISABLED=1/私有四环境根。实例化入口只作结构检查，随后free，不add_child，不触发真实SDK入口_ready。

未Godot解析/执行，尚无host package完整consumer/runtime/成功all61/精确独立准入。完整编译identity/EXE/PCK/所有DLL来源链、原Popen/命令/环境/日志/报告和清理须由后续host真实证明；本源码自述不授这些资格。FileAccess写报告不是原子exclusive，仍需原拥有者独占新目录。没有fake SDK/native替换，不读真实玩家存档或上传，SDK/account/reward/original19/overall全部仍false。

V1原源和拒绝保持。V2只在首项绝对输出/nonce/manifest基本字段校验成功后设output_validated，_finish在此之前退出2不写任何路径，修复首项失败后仍写相对输出的可能。仍必须由未来host确认原批唯一目录/元数据及Lease；不因Node字段基本有效称所有权成立。
