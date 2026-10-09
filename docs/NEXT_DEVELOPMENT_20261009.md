# 水浒后续开发顺序（2026-10-09）

当前优先完成战役续玩与终局恢复。正式游戏尚未晋升十四份 R12 恢复候选；已经通过的普通黄泥岗恢复测试和编码基准各有独立范围，完整测试仍未通过。

## 1. 完成完整恢复测试

先取得完整 V12 原生测试通过结果，再以它的真实来源和结果接续后面的验收。V12 来源 SHA 与已审版本一致；四批均因另一项目启动 Godot 而中断，原收据保留，没有沿用它们的 A 档案或通过资格。

完整测试覆盖双角色 A/B/C/D、每角色世界 264 项、组件 362 项及实际对象 24 项等原定矩阵。第三批 run6409dde9 已实际退出 1：冷导入通过，Lu A 启动后遇外部引擎，完整批未通过且锁已释放；不是仍在等待。第四批8fe7b18b/session14695也已实际退出1：冷导入及 Lu A 单保存305项通过，Lu_world被外部引擎中断，不能作为成功前置。当前无活跃水浒批，第五批未启动；后续原生验收须整批共享引擎串行窗口、新私有档案和来源封存。跨聊天协调许可仍未收到回复，期间继续独立源码工作。

## 2. 完成原 19 类故障和玩家重试

完整目标保留六类纯数据、六类真实文件故障、首次/重复两类自然终局、两类QA兼容，以及三个实际回调/云端边界，共原19类。原JSON533、Owned76、普通half-ABC39/351/342基线、完整标签、真实CFG与三代生命周期、同对象重试、账号/来源排除和noReplay回归仍须当前来源的实际证据；历史旧来源通过不能授R12候选资格。

六文件故障GDv6/controllerV5/consumerV2与完整producerV3已通过有限源码预审。V3显式接受成功完整V12的首次原receipt pin，创建新批前复核all61；当前四失败prior均拒绝，没有成功prior绑定seal或运行准入。六纯数据及相关旧后继仍须按当前来源和成功前置重新闭合，不沿用失败完整批资格。

首次/重复自然终局的GD、74/80/21标签、publisher/runtime、完整消费者V3和五进程producer已完成源码接入与有限预审，阶段为空；实际冷导入及first/restart_first/repeat/restart_repeat四流程仍未运行。须成功all61前置后封存精确来源、独立执行准入，再取得完整报告、CFG prepared/applied1/2→3/4及两token各gen1/2/3的实际结果。

单个callback_sees_new_memory自然GD已准备，保留父实际黄泥岗路线；只读observer、严格packet消费者、controllerV3、rawreceiverV3、四export publisher已通过有限源码预审。4096事件/64MiB只为1800秒一Hz参考模型的有界留存容量，当前binary流量和性能未证明。callback phase集成源码已准备，继承已审cold/普通同profile restart，当前完整执行与结果资格仍未取得。

callback phase初版遗漏历史NativeExports依赖已被独立审查拒绝；后继仅封存补齐至73pins/118本地边，执行body不改。此metadata修复已通过独立有限源码复审，阶段为空。80/56/21标签合同、原packet/terminal tail重放及报告/CFG/lifecycle消费者源码已准备，原物理七方法保持。消费者V1被独立审查确认尾流顺序可遗漏原prefix，原拒绝保留；V2只修两处顺序/原字节重构guard，完整consumer仅换import，六项合成反例/正确分段检查通过。有限差异复审已确认这项修复，阶段为空；完整三进程producer源码已接入cold/callback/同profile restart，175pins/343全导入边/29overlays来源准备通过，四失败prior及第四批实际CLI封存均被拒绝且没有创建后继目录。producer有限独立原收据已归档，无确定源码/API阻断、stage=[]；下一步取得成功V12前置封存和新的完整执行准入；完整validate和实际两进程尚未运行。真实cloud-applying驱动V1的链/API闭合，但独立追加拒绝确认ready后无host-arm等待可能漏掉回调，原件保留。V2源增加QA-only observer arm实际dispatcher接收/ack、30秒正常帧有界等待和原状态重核，33/20/23source标签及10生产alias，不授Steam账号/上传或native资格；主机strict arm packets/实际owned controller、原rawreceiver后继、三export publisher和实际cloud phase源码已接入，212pins/406导入边和32/43合成状态检查保持source-only，五库有限独立源码预审已通过、stage=[]；首次report/原arm+packet+tail replay与实际pre-arm/完成后的物理CFG十四字段日志中间consumer已准备，V1独立拒绝确认遗漏generation<=2147483647，原225来源保留；V2仅补代数范围、phase/consumer换import，236pins/531导入边及27项伪造文件检查保持source-only，generation两guard有限复审通过、stage=[]；native全CFG semantics的GDv3/四export/phaseV4/first consumerV3源码已接入whole原/expected/final typed投影与原journal SHA绑定，254pins/589边及25合成projection检查保持source-only，新GD/API有限独立预审无新增阻断、stage=[]，实际Godot解析/完整consumer/native语义验收尚未运行；准备restart发现USER-TEXT-001：合法Godot D:/文本被Windows Path→str重写导致pre-arm/consumer拒绝；后继原生文本精确保留/物理Path独立检查通过有限delta预审，272pins/669边/35合成保持source-only。自然终局回调consumer/replay的同类点已修并有限独立预审通过，producerV2精确新库绑定的190pins/387边recipe-only成功且failed prior拒绝保持，producer有限delta复审无新增阻断、stage=[]（独立logical重算未完成），尚无成功前置/native准入；下一步接同档案cloud restart与其完整producer，整个cloud用例资格仍false，V2有限等待/guard修复独立预审通过、stage=[]；收到arm不证明断点安装，当前binary顺序未证明。另一个真实云文件失败driver与故障集成、两类QA兼容、实际失败UI与重试仍继续；R12正常云失败须证实旧进度/公开CFG保留、真实pending writer/shared profile保留，设置/语言可先写入，不能声称整个profile原子性。本地数字账号夹具只为SDK-disabled输入，不授实际账号、上传或SDK奖励一次性结果。

源码审查、合成流与私有磁盘原件回读均不计原生通过。全部原19和所有原定额外回归都须分别闭合；正式恢复源未晋升。

## 3. 完成玩家入口与平台集成

验证实际失败界面、继续入口、取消与重试，以及 Steam 奖励一次性边界。只有全部必要恢复验收完成，才将恢复候选接入正式游戏。GitHub 同步与 Steam 发布分别处理，发布仍需单独授权。

## 4. 完成内容与体验验收

继续八章自然流程、美术动画、界面多尺寸和九种玩法的原定验收，处理实际路线暴露的问题，再验证 Windows 导出安装包。固定路线截图或组件测试不替代完整游玩和安装验收。

## 5. 完成性能与 Android 真机验收

验证实际连续10分钟运行、帧时间和场景切换内存；性能目标仍为 60 FPS、P95 不高于 16.7 ms、P99 不高于 33.3 ms。Android 手机和平板另做触控、DPI、安全区与持续性能验证，不能用主机模拟代替。

每轮按对应验收结果更新 QA 与交接，并以逐文件白名单提交、推送和回读 GitHub stable 分支。未完成阶段保持未完成，不因某个组件通过而提前宣告全部开发完成。
