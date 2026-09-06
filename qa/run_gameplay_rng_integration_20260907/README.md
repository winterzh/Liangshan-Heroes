# 玩法RNG实际接入QA

本批已实际接入独立gameplay RNG及安装身份provider，最终R2源码、PCK与发行候选检查通过。正式档已由根执行并冻结，历史失败不覆盖。

| 真实运行 | 结果 |
| --- | --- |
| 原native 20260907_052224_8929b774 | 176项通过，provider aae43a… |
| 原callsite 20260906T212733214636Z | 五阶段342/213/215/211/214通过 |
| 首builder 20260907_053155_29e025d2 | 包65/EXE加载通过（PID40004）；source PID8796 exit1、9true/1false，PCK未启动，整轮false |
| JSON诊断 20260906T214125997167Z | PID34248 exit0，bytes int→float导致深层比较差异 |
| R1 builder 20260907_054309_1ccc4379 | 包65/EXE加载（PID32308）和source身份10（PID27508）通过；PCK PID32540 exit1 SOURCE_PROVIDER_UNREADABLE，整轮false |
| 模式诊断 20260906T215605938295Z | source38952/PCK29312均exit0，Script backing不同而args/editor相同，source/player/pack不变 |
| R2 native 20260907_055815_2e6a535d | 176项通过，provider a78dc5…；复用旧纹理导入缓存，不作冷导入性能声明 |
| R2 callsite 20260906T220055422528Z | 五阶段1195通过，PID17672/35844/39236/34020/8456，source/player/lock true |
| 最终R2 builder 20260907_060601_f70626d8 | complete=true；source10 PID34776、PCK10 PID19328均exit0，包65及EXE/DLL加载PID38660通过；outer220553697867Z完整/源码/玩家保护true |

两套callsite各1195=1020来源前后核对+175功能/宿主检查，复验同矩阵不增加独立场景。迁移盘点的31处调用不等于31个分支均实跑；_eco_traps两个各3次draw的分支仅静态核对次序/短路，未单独动态覆盖。 测试覆盖的具体功能以原contract/report为准。原draw顺序、视觉随机隔离和耗尽后停止后继动作经过真实消费者验证；故障前已发生的伤害不回滚。startup运行原完整新Battle入口；writer/reader只恢复RNG、其余受控对象重新建立，不是整局恢复。

第一失败的JSON诊断证明optional_content.bytes从int变float，Dictionary深层比较false而单值比较true，规范化int后true，仅转换typed Array不足。probe R1改为明确字段/类型/顺序比较。第二失败中旧provider将PCK误判为source；模式诊断证明--main-pack已被engine消费，源码和PCK可见args均只含--script且editor均true，但源码Script.has_source_code/物理源码存在true、PCKfalse。provider R2据实际Script backing选择独立严格的源码或编译校验，无fallback、不接受存档提供身份。

实际安装身份为fababc4025d35561fcc5c7380f20eb9b79fd4650cc1b7ff53f59c8754f95fb5d，2646文件/285273844 bytes；provider为a78dc5…。这证明源码/PCK的独立provider合同及普通发行EXE启动，没有在发行EXE内部观察Battle RNG/provider绑定，也不是完整Battle恢复。

最终source报告SHA138406086c153f7364547753759337f6f46828a361fed8da15a74dbf633adfbd；PCK报告SHA75d7303cc0694b00b4aa8c345670f47f84d77b2573038766bc10198afc244a46。原始检查及stdout/PID/退出须随archive_verification回读。EXE仅记录SHA e05b482254cff2c201c5c055c43e95cbc79127106e108ad735145d74c3b2b3ed和287667024 bytes，不收入包原文。

source_index schema2的archive均相对仓库根。两轮102来源联合103个唯一SHA、101共有；93个可复用旧QA精确字节。旧provider从APP/candidate保持aae43a…，R2 a78dc5…另列；driver同字节可以映射两个原入口。原APP14/before、probe R1和provider R2补丁链、两native/两callsite/三build/两diagnostic全部分开留原文。原failed0没有PCK probe，两个失败没有内部after时不补造；外层保护true不能冒充缺失文件，report.complete也不等于passed。生成时fix_receipt中的false不回写。

复现按所选source_set和原command/environment恢复路径、使用既有helper及收据指定引擎/native/template、新私有user和新run；原R2 README仍保留旧命令示例，以实际r2 runner与report_process入口为准。排除profile、玩家清单、二进制、图片及缓存；只保留明确原始收据/日志/源码及生成的文本身份常量。本批没有Steam上传或正式发布。

完整Battle/Map/Unit/旧视觉/全部事件事务、RunSession、退出重启、发行EXE内Battle RNG/provider绑定、正常帧率和真人画面未验收；物品施法/bolts仍是未试跑候选。归档回读：295份原始产物16,493,620 bytes（不含生成sidecar与后补README）；1272条来源映射、258个唯一源码blob，其中103个复用既有档案。manifest SHA597e75dd6802c82a622725a34e7c1b2bb988c87050ca3fed9d2fdeb1b3235a1a；source_index SHA4863b1b68db2d459c0a2a88b2fc10d4d140e50e6c65b84dae957db278f92ff7c。
