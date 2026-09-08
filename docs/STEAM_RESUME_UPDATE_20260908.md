# 2026-09-08 恢复组件 Windows 测试更新

用户在收尾后要求“更新”，按Windows Steam包更新处理，沿用既有 `steam-integration` 测试分支。已完成当前源码 `d32b0b8` 的全新冻结、构建及验证；尚未上传成功或切换分支。

本地182项原生、65项实际包、源码/PCK身份各10项和11个同EXE短测通过；六张原生界面已逐张观察。[QA和复现](../qa/steam_resume_update_20260908/README.md)、[成品清单](../qa/steam_resume_update_20260908/candidate_delivery.json)。自动验证禁用真实Steam，不能当作玩家客户端或真实账号验收。

ZIP：`.godot/steam_candidates/20260908_113610_180c93c4/LiangshanHeroes_Steam_candidate.zip`，221324671字节，SHA256 `7e98ca00a78992f11d538a2c7dba7d335e9ee07455b7569532a04483403ec995`，仅EXE、两枚release DLL和许可证。安装包和隔离用户目录不提交GitHub。

Edge有效登录已实时回读构建页：default `25164373`，steam-integration `25173165`。上传页面Windows Depot是 `5088121`。文件选择接口未报错但DOM input.files为空，尚未点击上传；浏览器上传故障说明要求扩展开启“允许访问文件URL”，已请求用户处理或手动选择该ZIP。[服务端状态记录](../qa/steam_resume_update_20260908/steam_server_receipt.json)。

下一步：复核ZIP哈希，附加文件并上传Windows Depot，校验服务器四文件大小/SHA1，创建生成版本并更新steam-integration，回读canonical分支及历史。公开default不属于本次测试分支更新范围。玩家继续入口和持续Steam发布器仍未完成，公告不得宣称完整续玩已交付；已有9月8日公告不重复发布。
