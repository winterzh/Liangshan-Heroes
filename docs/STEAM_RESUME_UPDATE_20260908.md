# 2026-09-08 恢复组件 Windows 测试更新

当前源码 `d32b0b86cbf82c88ec11e1a3433a7291f65e038d`（运行代码9529a8b）已上传为 Steam Build **25179481**，并在 **steam-integration** 测试分支上线。Depot `5088121` / Manifest `5125271626255480862`。canonical构建页的分支行与上线历史均已回读确认。公开default仍为 **25164373**。

服务器恰好四个文件，逐项大小与SHA1均匹配本地成品。Steam预览显示从旧测试Build25173165更新约5.2MB。这是服务端交付确认，未替代本地Steam客户端下载或真实账号验收。[服务端收据](../qa/steam_resume_update_20260908/steam_server_receipt.json)。

本批全新182项原生、65项实际包、源码/PCK身份各10项和11个同EXE短测通过；六张原生界面已逐张观察。[QA和复现](../qa/steam_resume_update_20260908/README.md)、[成品清单](../qa/steam_resume_update_20260908/candidate_delivery.json)。本轮接续复核同一ZIP哈希并完成上传，没有重建或重跑既有原生检查。

ZIP：`.godot/steam_candidates/20260908_113610_180c93c4/LiangshanHeroes_Steam_candidate.zip`，221324671字节，SHA256 `7e98ca00a78992f11d538a2c7dba7d335e9ee07455b7569532a04483403ec995`，仅EXE、两枚release DLL和许可证。安装包和隔离用户目录不提交GitHub。

更正此前上传判断：用户确认扩展文件URL权限已允许，实际截图显示ZIP已选中；DOM input.files读取为空不能证明未附加文件。首轮实际上传在可见进度220200960字节后报“Upload failed!”；重新附加同一ZIP并以标准模式重试后成功，首次故障保留在收据历史。未为此更改浏览器权限。

当前包包含内部完整世界恢复组件和持久局收据联调，玩家保存/继续按钮、正常启动持久模式和持续Steam发布器尚未接通。自动验证禁用真实Steam；真实/双账号、完整八关及30波、1800秒、双机、性能和真人验收继续保留。已有9月8日公告不重复发布，本批没有公开default切换或main合并。
