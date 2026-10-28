# 2026-10-28 Windows发行包验收与Steam交付

用户明确授权“把最后的发行包验收做完，通过后更新到Steam，不用再跑全量测试”。冻结来源为 `47168f003cb860271ce8e09e1d4a1fca5a282d58`，候选 `20261028_095223_2c90e9d7`；未改生产代码，未重跑52／61，未采用完整战役续玩候选。

本地原生整合219、包内1169、来源及包内身份各10项、实际EXE十一场景全部通过。[冻结包交付清单](candidate_delivery.json)与[原件复制清单](evidence_copy_manifest.json)绑定六文件、ZIP和原始日志。ZIP为1,741,403,902字节，SHA-256 `9f465a809761228cfedb61ee6beb8c32c365c4d36175334707c253d816ce4a10`。

实际EXE普通键鼠观察覆盖主菜单、八章菜单、黄泥冈进入／布阵、人物选择、刘唐右键应答与白胜入场卸酒、任务面板查看／选中／滚动、F11和任务提示悬浮时Esc暂停、正常退出。源码、玩家目录、EXE前后不变，子进程退出、锁释放、日志无目标错误。[实操观察](gui_observations.json)明确保留因自动操作等待过久而失败的一次游玩，第二次停在酒计阶段；**未完成普通键鼠整关运输或真人完整通关，不把退出0计作通关**。运输逻辑仍引用[已有生产专项](../huangnigang_production_20261020/README.md)的编译包普通路线1206、九阶段1768项及24张界面图，与本批EXE观察分别记账。

四语补丁说明 `680765564125184330` 已关联Build26260970并公开发布；简中、繁中、英语、日语各9段标题／正文片段与图片加载均通过回读。封面使用已有已批准的通用图片，非英语使用英语封面回退。[公开公告](https://store.steampowered.com/news/app/5088120/view/680765564125184330)、[四语收据](announcement_public_verified.json)。

网页上传两次停在0字节后改用官方签名SteamCMD。用户本机完成登录和手机发布确认，凭据未进入工程或Git。首次SteamPipe预览退出0，但DepotPath误用文件名，实际清单多套一层目录；该Build26260938未激活，旧预览与日志保留，不能计为语义通过。`correct_steampipe_mapping.py`生成新的目录`.`映射，修正预览的六个根文件名称、大小和SHA1与候选完全相同，随后上传Build26260970。[映射修正](steampipe_mapping_correction.json)、[修正预览](steamcmd_preview_corrected.json)、[上传收据](steamcmd_upload.json)。旧准备脚本及其收据只代表首次尝试，不作为后续发布模板。

**正式交付完成：default Build26260970／Manifest7760891311054131368。** 服务器六文件、全新SteamCMD下载、库内六文件的哈希一致；隔离下载版EXE主菜单启动和退出0。Steam客户端自动更新后实际库进程PID66752（父进程Steam PID27168）主菜单目检、正常关闭及Steam日志退出0已验。客户端原有进度不变，云档仅`updated_at`变化，另产生五份着色器缓存；184个原文件私有备份保留。日志有既有GLES3不支持2D MSAA警告，无目标错误。[最终交付](delivery_complete.json)、[下载](server_download_verified.json)、[下载版启动](server_runtime_verified.json)、[客户端](client_acceptance.json)。原候选／准备收据不重写，其uploaded=false仍保留当时语境，以本最终收据为本批发布状态。
