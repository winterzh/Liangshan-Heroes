# 私有完整包范围（准备中）

为避免再借用/覆盖旧冻结工程，后继改为新建开发根 `.godot/huangnigang_full_package/<stamp>/project`：逐文件复制实际规范输入（包含`.gdignore`原稿），精确覆盖9文件候选，校验vendor原生来源，再由现有private_staging/seed/import/generate生成实际身份。旧冻结工程与原身份保持原处，旧三目标真实存档另以其实际旧版本产生；不能伪装新档作为旧档。

prepare_export_source.py只做私有复制与身份种子，读取全部Root规范来源两次要求一致；不启动Godot。run_export_identity.py只有已排队骑乘比较真正成功、共享通道空闲时才运行。它导出单个新完整PCK、复制原字节Windows release模板，验证实际编译Provider/清单/EXE/原生DLL。每阶段四个环境根独占、STEAM_DISABLED=1、CAMPAIGN_QA=1，外部QA源码逐文件SHA绑定。不借旧12包链或旧55/258/26充作新包通过。

此身份入口即使完成，也只说明新包身份成立；还须新包真实酒计/七车玩家路径、三阶段世界保存/安装、携车检查点新进程继续并实际交出第7车、真实旧三目标档拒绝且原字节不变。8份外部GD worker与3份串行原生入口已准备；只有Python语法检查，GDScript尚未由引擎解析或执行，禁止把总接入门槛记为完成。图像仍须直接查看，头像诊断和骑乘体量不以自动项数替代美术接受。

当前不改生产入口、不合并main、不上传或激活Steam。原始PCK/EXE/私有档案/缓存留工程外或被忽略的私有目录。骑乘现有句柄72882结束前不得启动第二个自有Godot。全库人物/场景/战船/特效/UI/其他6车轮转与性能继续，全部内容核对适用章回。


实际私有复制已完成：prepared_source_current.json指向20261018_153917_4c10b0cd，复制6967个Root规范文件、2383771999字节，前后Root规范快照完全相同；候选9份和vendor来源SHA逐项核对。这个已成功的复制入口不应重复运行。生成的派生身份仍只是种子，未启动Godot导入/导出。

串行顺序：先回读已有骑乘72882并直看其对照PNG；再按需要执行头像实景诊断。之后真实旧三目标fixture（run_legacy_fixture.py）、新完整导出与release身份（run_export_identity.py）、同包玩家路径/世界保存/携车重启/旧档拒绝（run_package_phases.py）。每入口重新检查真正空闲及独占锁，不另建竞争watcher。已完成的收据不可覆盖或重复计数，失败保留后先修来源再继续。


准入修正：旧观察72882已结束且未启动子引擎，不再以queue complete作后继门槛。空闲后运行原骑乘比较，后继检查实际latest成功native收据；所有旧观察/未运行状态保留，不因超时重新启动watcher。
