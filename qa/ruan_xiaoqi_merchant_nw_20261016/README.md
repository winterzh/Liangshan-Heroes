# 阮小七商人NW修正与旧长线美术兼容 QA

全新冻结完整PCK 2306项检查/396图通过，5728份来源在主工程与隔离工程零变化。`adoption_receipt.json`分别记录新NW相反接触步与旧长线美术测试入口资格，正常菜单/完整通关/恢复/平衡/全美术仍未接受，Steam未更新。

- `final_native/`：新批原始输入、39纹理原生参考、实际日志/收据/396图报告，以及相关短/长线NW帧、HUD和长线实际动作图。全原件留外部目录；`raw_evidence_manifest.json`逐项验证所有原始SHA并标明仓库复制范围，不称仓库保存全部截图。
- `generation_provenance.json`：内置生成/完整请求/两份参考SHA，新PNG按原字节采用。
- `source_scope_review.json`：相对11b81dbc，仅walk_contact_b_nw记录不同，其他55pose相同，游戏属性/技能/章节脚本不变；生产脚本只改walk路由。
- `runtime_scopes.json`：current_short、legacy_long、ordinary分别四方向真实移动4帧及命中/受击/倒地，明确上下文而非普通模板标签。
- `legacy_helper_path_preflight/`、`legacy_mission_service_preflight/`、`shared_slot_race/`、`preflights.json`：失败/未启动批保留，不移转为通过资格。
- `visual_review.json`：只记录直接看过的最终实际PCK画面；全部396图不称逐张人工审核。

旧长线QA子类从外部冻结路径加载，实际生产map/defs/deploy/start执行；正常政策仍custom，由QA显式添加真实任务服务后才能开场。未修改官方注册表、未恢复正常入口、未授予正式战役资格。Battle/其他演员冻结、普通技能待结算显式推进，临时同定义演员不是原剧情演员；其死不会触发虚假的剧情伤亡。不是完整关卡/存档恢复、性能、Steam或全美术完成。[原著/实现/复现](../../docs/RUAN_XIAOQI_MERCHANT_NW_20261016.md)。

最终直接目检12张：短/长线各4张NW完整相位，长线HUD、真实劈砍/受击恢复/终态各1张。全部396图不称逐张人工审过。
