# 大名府三文件组合准备器（941c底座，2026-10-27）

此目录仅提供下一份独立完整冻结的准备代码。默认命令只读指定元数据与小来源文件，不遍历/哈希完整项目，不复制项目，不启动 Godot。当前没有执行 --full-preflight、--prepare、--check-run，也没有新冻结、导入或大名府原生资格。

## 精确组合

固定父批：.godot/campaign_progress_recovery_20261026/20261027_050851_9bd328cf；源身份 source-v1:941c4786569d5886efbd3537238df853026cc50d0c98d0a1cdb1516c8a8f7964；父 candidate_manifest SHA c5c1052c4797d760a52d15176c0d79bbc7ea7aaa23003ba429108be507ca753b。

已逐项读父清单：23条中有Session，没有Core/UnitContract；后二者在7062份完整原资源中已存在。因此组合清单为25条：23中替换Session追踪，再添加Core和UnitContract两个既有资源的追踪条目。完整工程文件集合不增加，只有这三件原资源的字节替换。其余22条旧追踪记录、Store、原生helper与全部资源保持原样。

固定三份候选来自上一级 scripts/，不修改其已封存8文件。精确path/原件SHA和大小/候选SHA和大小列在source_manifest.json；旧Core整件不覆盖、黄泥冈Mission参数保持的说明见上一级README。生产脚本、旧941c工程、旧v25及Gao输入均不修改。

## 调用契约

- python prepare_daming.py：lightweight()。只验证本目录固定来源、父清单、命名generation/preimport元数据及3份实际原脚本，形成25+1组合；validation_level=metadata_and_named_sources_only，full_source_verified=false。父import文件在来源中只是pin，不据此授予完整资格。
- python prepare_daming.py --full-preflight：preflight()调用既有Gao准备器的prepared_state(固定941c父批)，完成父批完整源、生成文件、完整来源链和独立import的真实验证，再合并本次精确3件overlay。此为昂贵只读验证，不复制、不引擎。返回base必须指941c，不误用上一层继承的768 base。
- python prepare_daming.py --prepare：先完整preflight，再独占创建新的UUID目录，逐原文件核SHA复制、仅替3件，安装现有native依赖、标准identity.seed、复制cache seed，然后再次核完整基线和新工程实际快照。必须完整files/dirs等值且差异集合恰为3目标；新文件集合为空。失败保留新目录和complete=false的preparation.json，不清理失败来源、不修改旧收据或共享锁。
- 后续由根任务独立运行新批正常editor --import并完成其宿主后验。准备器本身没有Godot进程启动入口，也不借父import结果代替新import。
- python prepare_daming.py --check-run NEW_RUN：prepared_state(NEW_RUN)验证本准备器的完整新manifest、准备收据、runner来源、全部准备pins、项目实际当前身份和生成文件、preimport==generation、固定root_source，以及新run自己的成功import。import需独立正PID、原engine/--path/--editor/--import/--quit、exit0/errors[]/stopped_for=None、日志SHA与锁released。没有这些实际结果会拒绝。

模块继续暴露h/p；preflight()/prepared_state()返回的full state包含pins/engine/engine_sha256等原链字段，h/p不是state字典键。preflight的base与run_base为941c；prepared_state的run_base/project/generation/content_version指新的受验工程，而base保留941c父来源含义。消费者须使用run_base/project，不从base猜当前运行目录。新schema分别为daming_941_integrated_manifest_v1和daming_941_preparation_v1；执行器必须显式适配新schema及25条追踪，不能把旧23分支放宽。

native helper的源/构建收据/EXE SHA由完整父链验证，新完整身份继续包含addons下EXE。preparation_inputs只封存非EXE来源；helper作为实际游戏原资源保留在新project。cache_seed.qualification_reused=false，导入缓存不会授予编译或原生资格。准备器不获取或释放Godot共享引擎锁、不终止任何进程；独立import/玩法runner继续按已有自有锁和PID约定串行。

## 当前边界

本次只允许Python AST、--help、默认lightweight及指定小来源校验，结果应单独报告为准备代码静态检查。新组合仍为LCv3/Intentv2/ACKv2、一个Daming context的lu/shi两路线。旧61=1冷导入+8角色ABCD+52负例；原19故障另有门槛，旧3/61不代表今天运行或完整成功。任何来源组合都需自己的导入、真实Flow与角色路线验证，最终统一源回归不能跨源转授。公开入口/SDK/导出EXE/人工/性能/发布资格均未授予。
