# 原十九案：云写入失败与原对象保留入口

这是 `legacy_real_cloud_apply_failure_boundary` 的本地故障检查入口源码，继承原首次/重复自然路线驱动的正常菜单启动与来源检查，只覆写 `_fresh` 和 `_finish`。它不重播旧版“保存失败后内存已经被改”的行为：R12 必须保留原 Campaign 进度、同一个待写对象与冻结提案。

候选在自己的全新私有 userdata 中创建关闭且 SHA 固定的普通文件，真实阻塞 `campaign_cfg_candidates/v1` 目录；由原 SteamCloud `_apply_profile` 调用 Campaign 的实际 CFG writer。预期真实返回 `CFG_STAGE_PARENT`，错误界面暂停并展示连接生产 `retry_config` 的 `RetryCampaignConfig` 按钮。候选只移除自己的这个已关闭文件并修好目录，再通过实际按钮发起重试。

数字 owner=1 仅为与已审云成功探针相同的 SDK 禁用本地输入。真实 `_shared_scope_ok` 需要可用 Steam 与相同账号，因此这一重试必须返回 `CLOUD_RETRY_SCOPE_CHANGED`，同时保留原对象、作用域、提案和旧进度。**成功的有账号同对象重试、同档案重启、原十九案全案验收、玩家故障界面验收、SDK 或上传资格均尚未实现/取得。** 本入口不能替代这些要求；报告始终将其资格保持 false。

源码准备封存原云用例 recipe 的既有 287 来源，并显式追加新 GD/runtime alias 和 builder。标签合同是源码清单，不是实际通过数。未启动 Godot、未解析新 GD、没有 host phase/consumer/producer 或执行准入。之后必须补真实有账号重试的受控方案、完整宿主原字节证据消费与后继封存/独立准入，并按原 all61 前置执行；不能直接运行这个源码入口或以局部成功替代全案。

独立审查只核对固定 SOURCE、继承 startup、生产 API/字段/暂停后的正常 process_frame、真实文件障碍与释放范围、实际按钮和账号拒绝、源码标签以及原资格边界。禁止启动原生进程、改生产/旧证据或控制其他聊天。新发现必须准确记录；通过源码审查也不授任何 native stage。
