# 真实物品自检与付费复活 QA

准备完成，未运行Godot。只新增本目录文件，复用冻结的`run_item_ids/respawn_cases.gd`，未修改生产或既有53项item-id QA。根任务按共享引擎独占顺序执行。

```powershell
& 'C:\Users\Administrator\AppData\Local\Programs\Python\Python39\python.exe' -X utf8 scratchpad/run_item_respawn_qa/run_smoke.py --godot 'C:\Users\Administrator\Desktop\新建文件夹 (2)\Godot_v4.6.3-stable_win64.exe'
& 'C:\Users\Administrator\AppData\Local\Programs\Python\Python39\python.exe' -X utf8 scratchpad/run_item_respawn_qa/run_smoke.py --godot 'C:\Users\Administrator\Desktop\新建文件夹 (2)\Godot_v4.6.3-stable_win64.exe' --run
```

工作根为`E:\ChatGPT\水浒-art-validation`。首条只核对固定来源/engine SHA，不启动引擎；第二条运行一个真实非console子进程，180秒上限，在本目录新建`runs/<UTC>/`。原始Popen句柄确认退出后才释放共享`.godot/redraw_rejection_source.lock`。不改父进程环境；APPDATA/LOCALAPPDATA/TEMP/TMP只对该子进程设置。真实玩家目录与全工程source用既有guard前后保护，失败保留原始日志和收据。

`driver.gd`使用`RUN_RESTORE_QA_MANIFEST`，suite=`item-respawn`，报告前缀`[item-respawn QA] `。99项运行来源纳入pins/实际manifest，包括全部生产GDScript、scene/tres和content JSON、project.godot以及实际driver和respawn_cases；美术等其他生产字节仍由原全工程source guard保护。所有manifest条目均在Godot端前后检查，host复核报告自身PID/user、stdout与sidecar相等、检查数/关键标签，以及来源未变。

执行顺序：

1. Autoload初始化完成后加载正式`res://scripts/run_item_id_state.gd`与c8c4 codec，在两个空树外真实Battle对象间执行capture→JSON.stringify/parse→restore，验证后继分配。只补正式加载路径，不重复原53项负例。
2. 创建完整标准30波skirmish Battle，禁用托管，暂停战斗。明确直接调用原`Battle._item_selftest()`一次，未启用SMOKE_TEST整套其它自检。`ITEM_TEST_KEEP=1`令原方法保留它的物品/选择夹具；原方法本身没有quit，KEEP的实际作用是提前return、跳过自检末尾的夹具清理。driver核对保留的真实库存。host要求原方法唯一输出`[item] add=true stats=true full=true shared_cd=true snapshot=true swap=true transfer=true combat=true tally=true ALL=true`，缺失、重复或任一false均拒绝，driver不伪造该marker。
3. 完整释放第一场Battle并等待两帧，再创建全新标准Battle。检查counter初始1、无退休库存/测试物品定义，然后调用已冻结的`respawn_cases.run`。它执行真实致死回调、付费下单、坏UID失败/重试、帧末清理、取消退款及正确旧snapshot重练；保留原UID并恢复成长。训练完成仅通过明确设_train_t=0加速，战斗保持暂停，不能当正常训练墙钟时长测试。
4. 完整释放第二场Battle，输出独立报告。两个完整Battle夹具绝不共享物品容器，另有最前面的两个空Battle计数器对象；报告`full_battles_created=2`只计完整场景。

运行器从现有`run_unit_graph/run_smoke.py`作有限适配，继续固定RNG R1 utility SHA `8f9c8210…`、process safety `7983b004…`、source guard `1cecf1c3…`，不新增公共runner框架。实际执行路径必须出现在manifest，pins与runner前后固定。`STEAM_DISABLED=1`及原headless测试策略避免对真实Steam服务记入QA事件，Campaign保存被CAMPAIGN_QA抑制。

通过时只证明正式counter路径、原物品自检及这条真实付费复活生产链。它不证明整个Battle跨进程续玩、完整效果/地图图恢复、菜单/PCK或战役全流程；原53项计数器测试和本次正式路径复验不得累加成新场景数。
