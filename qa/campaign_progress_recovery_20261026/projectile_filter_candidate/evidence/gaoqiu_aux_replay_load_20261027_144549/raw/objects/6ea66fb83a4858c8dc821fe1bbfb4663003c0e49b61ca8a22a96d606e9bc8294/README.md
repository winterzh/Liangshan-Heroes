# b22高俅训练与自然败局同源复跑

只适配外部Python宿主到当前b22完整26脚本＋1 native工程及自己的首次cold；原造船三GD和自然败局四GD不改，原sources／derived_from／dependencies均按当前原字节绑定。旧941的190项训练／200项败局不转授。

默认仅核命名小型来源和Python AST，不启动引擎、创建profile或完整散列工程。显式--run --base-run <b22自身cold批> --timeout 1320 --wait-lane 0才从全新profile运行各自三进程；两个入口分别是projectile_filter_candidate/run_gaoqiu_training.py和run_gaoqiu_loss.py，必须串行。

训练仍为普通建船厂、实际付费队列、未完成保存退出、独立恢复后按正常时钟完成原队列、再次保存并第三进程读回唯一新船；仅授活动期训练接续，不能授胜败或奖励。败局仍以普通命令导致原主将自然阵亡、实际终局提交、独立重启拒原LOCAL_RUN_TERMINAL；仅授源码败局链。所有生产Flow、typed检查点、实体ID、资源／人口、LC／Slot／token和不注入断言保留。

外部worker冻结原字节，新宿主／本README另有独立sources.json；运行同时pin两层来源，不把新宿主冒充旧worker来源。完整来源前后、实际子进程终态、自有共享通道锁闭合方有各自资格。SDK、发行程序、公开入口、OS键鼠、真人、全战役、云端奖励及61阶段不转授。当前执行状态单独维护于VALIDATION.md。
