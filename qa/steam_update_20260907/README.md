# Windows Steam 更新证据：2026-09-07

已上传并切换 Steam default：BuildID 25154403，Manifest 596698599141519420。

源码为 `443e75e887afd76f9569cae17b0527a72408aedc`，来自已同步 stable 分支。Git 对象冻结 2,463 个运行文件、275,501,909 字节；描述树 `d58bd55c0ae3ebe210ab396a06e173b23f845fe9a8aeecd285970e5ab8a57937`。独立复核确认所有路径/Git对象一致，并复核8个运行变更的实际冻结字节。全量来源校验、导出后生产字节及导入侧车均无差异；只新增9个已知脚本UID。

## 成品与验收

- EXE：286,992,544 字节，SHA256 `dcccc29d6ce880370f43a2d58048e974de7fb65544c2149d84b9abcb7c52b8ae`，SHA1 `1c960be3e06fec943692a65f829f5c5526f5de08`。Godot4.6.3官方Windows x86_64 release，嵌入PCK；既有版本字段仍为1.8.0.0。
- ZIP：217,939,560 字节，SHA256 `faad436642fe5e621a68ee983ab06bb683772de4a2813694f365fda1a4e93014`；根目录仅LiangshanHeroes.exe，CRC与内部EXE哈希一致。
- 全新导入169.605秒、导出122.061秒，均退出0，无错误警告。包内437项覆盖36TRES、100排帧、22生产图片和开发文件排除。
- 实际EXE11次短测覆盖八关、驻守、末波清理、主菜单；驻守9项与末波清理12项通过。菜单、驻守的2张同包Vulkan画面已打开目检；27份日志严格复查无错误警告。
- 新包设置双进程33+28=61项通过：实际精简按钮输入、返回保存、独立进程恢复、配置字节、模态关闭和基础codec可加载；第三张1280×720设置图已目检。首轮QA误判引擎启动参数的失败及修正原文保留，见settings_qa_revision.json。

不能把这些检查称为完整八关通关、完整30波、30分钟稳定性、真人试玩、性能或商业美术来源验收。当前没有保存退出/继续本局功能。新设置的暂停检查是菜单夹具，未覆盖全部战斗暂停调用链。没有另做Steam客户端完整下载；上传后以服务端清单文件名、大小、SHA1和default行核对。

## 范围与复现

运行源码仅8个脚本变化，没有新增关卡/美术；本次更新包含精简特效、野猪林/祝家庄提示与飞斧失效目标修复。压力帧率门槛仍未通过，续局/追击诊断/RNG草稿未晋级。

原始成品在被忽略的 `.godot/steam_update_20260907/windows/`。EXE、ZIP、source/project副本、private_profile、玩家文件和缓存不进入Git。

从本归档恢复freeze_snapshot.py、build_windows.py、verify_package.py、package_contract.gd、prepare_upload_zip.py、finalize_archive_manifest.py到同一checkout下全新的 `.godot/<新名字>/`，Godot由GODOT_PATH指定。verify_package.py还依赖同checkout已跟踪的qa/steam_test_build_20260905/run_package_smoke.py和package_visual_capture.gd（均存在于443e75e）。依次运行freeze_snapshot.py freeze、build_windows.py、verify_package.py；重新目检新图并写与新包和图片SHA绑定的visual_review.json后运行prepare_upload_zip.py。助手拒绝覆盖原成品；不要直接从qa归档运行或套用历史passed收据。旧finalize_archive_manifest.py仅覆盖基础包范围，不可覆盖本批完整清单。

设置复现：恢复settings_qa下两个当前源文件到scratchpad/steam_update_extra_20260907；frozen_helpers中的三份文本按相对路径恢复原名，禁止覆盖已有不匹配版本。要求兼容的443e75e运行源码和已验证新build_receipt。入口默认只读预检，--run申请共用锁，在--out指定的新目录顺序执行两进程。原44项静态准备收据对应修正前版本，不混称当前验证。所有实际测试输出重新生成，不复制profile或玩家数据。

浏览器最初自动选择文件被扩展拒绝；用户手动选择本ZIP后继续。Steam操作详情见PUBLISH_STATUS.json。商店宣传素材由另一任务处理，本目录不记录其未完成状态。
