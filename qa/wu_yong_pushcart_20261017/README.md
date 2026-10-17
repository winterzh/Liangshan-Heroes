# 吴用携货推车原生验收

`receipt.json`对应`20261017_161234_8ddce18f`：完整PCK1001项/118图通过，75张原生纹理保持，6693当前输入/6602旧owner输入零漂移，包内identity与实际内容冻结一致。`report.json`保存逐项原生报告。日志`packed_chao_pushcart_visuals.log`沿用旧工具的case文件名，其收据命令实际执行`tools/wu_yong_pushcart_20261017.gd`，不是借用晁盖结果。

`direct_review.json`列实际直接打开的64张原图及观察；`screenshot_inventory.json`列完整118图的路径/尺寸/SHA。四张原字节代表图在`visual/`，其余原图受控保存在收据所列C盘证据目录，避免D盘低空间时复制全部截图/生成大Git临时包。外置原图应保留，跨机回看须按索引取回校验，不能把索引本身当作重新目检。

39张近景/实际状态含四向20姿势、实际物理行走、受击停车/挥刀、pickup/delivery/drop及四语言空手肖像；另25张默认/1.6倍图检查所有20姿势、四向过渡B及真实交货后空手。自身标签避开头部/车轮廓，未见明显选格串色或方底。罩布/绳结逐稿差异、连续轮转、敌方/拥挤区域标签及旧文字仍为欠项。

`private_restore_archive.json`记录旧晁盖854内容的完整恢复清单/ZIP位置和SHA，6680输入=6321 Git文件+359非Git文件。旧PCK不改；不可变owner保持，内层编译工程已成为本批，复查晁盖须另建私有目录按清单恢复。完整ZIP/SDK/profile/PCK不进Git，本批不是新冷导入。

`protected_preflight.json`、`unrelated_before.json`为8保护文件/81无关未跟踪文件基线，收尾再核对于`closeout.json`。关卡/定义/存档codec/地面车/identity helper/旧推车来源未改。

测试预设CARRY/drug前提、采样位置、冻结其他演员并关闭迷雾；实际取货、物理移动四相位、伤害/命中、交付及战败掉货用原回调。战斗/战败是游戏分支，不是原著这一段的吴用死亡。不当作完整酒计/七车十一担迁移/全UI/战役/续玩/性能/Steam或全美术通过。实现与复现见[说明](../../docs/WU_YONG_PUSHCART_20261017.md)。
