# 早上七点收尾 QA

本轮候选冻结运行代码为 stable `56adcacb78356fb9ecc33bc62eb0db252cb35ea6`；另接入独立已测Fog组件、未晋级草稿归档和builder锁读取编码修复。最终结果见 `verification.json`；Steam 观察是对正常网页可见状态的结构化记录，不是原始 HTTP 响应，也不是本轮发布成功收据。

原生合同测试复现：

```powershell
py -3 tools/run_steam_integration_qa.py --run --native
```

本机本轮复用了 `.godot/steam_integration_qa/20260907_034241_c81fc185` 的纹理导入缓存；不将耗时当作冷导入性能。构建入口为 `py -3 tools/build_steam_candidate.py --qa-run <刚通过的私有 QA 路径> --run`。引擎由本机配置解析；两个入口均使用共同引擎锁和私有项目/用户目录，Steam 初始化禁用。

只归档本轮选定的收据、日志、报告、来源指纹与交付清单；不归档 EXE/ZIP/DLL、完整测试项目、Godot 缓存、玩家存档、登录或账号信息。`archive_manifest.json` 记录归档原始字节，Git 属性保持这些字节；复现时同提交在不同 checkout 的文本换行可能不同，不能凭 HEAD 标签替代实际 source_files 的哈希。

这些测试不能代替真实账号成就/统计联调、工坊双账号发布/订阅、完整战役与整局续玩、性能门槛或商业素材验收。Steam default 的既有 Build25154403 与本轮本地候选需分别看待。

## 初始失败与独立补测

初始builder `20260907_070844_beba3054` 原完整结果为false：176项native、导入/导出、65项包验证、EXE启动和10项source身份已通过，收尾任务提前接入Fog文件后，PCK身份启动前的生产源码守护正确拒绝（child_started=false）。这不是PCK身份运行失败，也没有把原false改写为true。

独立probe工具三文件按原字节复制到忽略的`.godot/morning_identity_recovery_20260907/`运行。首次因main-pack相对路径在私有子进程cwd下无法打开，exit1且无report，源码/玩家保护与锁释放通过；后续命令使用绝对路径。恢复工具`recover_frozen_candidate.py`要求独立probe完整通过并退出，原EXE SHA不变、原2611来源及私有项目非import来源不变、唯一新增源码确为已验证Fog、原玩家指纹到补测结束不变；只之后才生成ZIP与独立收据。它不改原失败收据、不运行引擎或上传Steam。

本机Python默认cp936、utf8_mode=0；锁写入UTF-8后旧默认读不匹配，显式UTF-8匹配。`lock_encoding_check.json`保留实际结果；`builder_before_lock_fix.py.txt`保存原工具。失效锁仅在本轮owner token精确匹配、拥有的子进程已退出/未启动且无其他Godot时清理，见`owned_lock_cleanup.json`；首次补测被该锁前置拒绝，未启动子进程。

## 本轮最终结果

176项原生合同、65项包验证及实际发行EXE启动通过；source身份10项、独立补测PCK身份10项通过，拥有的进程均已退出、玩家文件不变、锁已释放。独立补测PID40472、exit0、source_mode=false；原builder仍为false，补测与ZIP验证见`independent_candidate_receipt.json`。

冻结源码56adcac；EXE SHA-256 `afa29af4a899a853abf9b347f1d44c3177f6629eac60d7b20ab47ad3bdafea02`。ZIP为219,887,525字节，SHA-256 `cb2608362f4456a14253a6a6d960eddfc30cc2b4442ed8fcfa84e15532baa227`，仅包含EXE、两个必需Steam DLL和许可证。位于`.godot/steam_candidates/20260907_070844_beba3054/independent_recovery/LiangshanHeroes_Steam_candidate.zip`，不收入Git。源码15组件中的Fog另有独立276行验证，未包含在此56adcac包内。

Steam仍未上传或切换本轮新包；default已回读25154403。一次性安排已暂停，家里所有开发子任务已确认停止，待公司接续。
